import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ConnStatus, DecodeResult, EmptyBody, ErrCode, ErrorBody, HelloBody, MsgType, decode, encode
} from '../core/Protocol';
import { PROTOCOL_VERSION } from '../core/Routes';

const DOMAIN: number = 0x0000;
const TAG: string = 'RoomClient';
const HEARTBEAT_MS: number = 3000;
const RECONNECT_BASE_MS: number = 500;
const RECONNECT_MAX_MS: number = 5000;
const RECONNECT_LIMIT: number = 6;

/**
 * 客户端连接。
 * 房主自己的客户端也走这里，连到 127.0.0.1，保证房主与加入方只有一条代码路径。
 * 负责：握手、心跳、序号、断线重连。
 */
export class RoomClient {
  private ws: webSocket.WebSocket | undefined = undefined;
  private seq: number = 0;
  private url: string = '';
  private nickname: string = '';
  private hostToken: string = '';
  private manualClose: boolean = false;
  private retries: number = 0;
  private connecting: boolean = false;
  private heartbeatId: number = -1;
  private reconnectId: number = -1;

  onMessage: (type: string, body: string) => void = () => {};
  onStatus: (status: string) => void = () => {};
  onError: (code: string, message: string) => void = () => {};

  isOpen(): boolean {
    return this.ws !== undefined && !this.connecting && !this.manualClose;
  }

  connect(url: string, nickname: string, hostToken: string): void {
    this.url = url;
    this.nickname = nickname;
    this.hostToken = hostToken;
    this.manualClose = false;
    this.retries = 0;
    this.open(false);
  }

  private open(isRetry: boolean): void {
    if (this.connecting) {
      return;
    }
    this.connecting = true;
    this.onStatus(isRetry ? ConnStatus.RECONNECTING : ConnStatus.CONNECTING);

    const ws: webSocket.WebSocket = webSocket.createWebSocket();
    this.ws = ws;

    ws.on('open', (err: BusinessError) => {
      if (err !== undefined && err !== null && err.code !== 0) {
        hilog.warn(DOMAIN, TAG, 'open callback error %{public}d', err.code);
        return;
      }
      this.connecting = false;
      this.retries = 0;
      this.onStatus(ConnStatus.OPEN);
      this.sendHello();
      this.startHeartbeat();
    });

    ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
      if (err !== undefined && err !== null && err.code !== 0) {
        return;
      }
      const text: string = typeof data === 'string' ? data : '';
      if (text.length === 0) {
        return;
      }
      this.handle(text);
    });

    ws.on('close', (err: BusinessError) => {
      hilog.info(DOMAIN, TAG, 'socket closed');
      this.connecting = false;
      this.stopHeartbeat();
      this.scheduleReconnect();
    });

    ws.on('error', (err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'socket error %{public}s', err.message);
      this.connecting = false;
    });

    ws.connect(this.url).then((ok: boolean) => {
      if (!ok) {
        this.connecting = false;
        this.scheduleReconnect();
      }
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'connect failed %{public}d %{public}s', err.code, err.message);
      this.connecting = false;
      this.scheduleReconnect();
    });
  }

  private sendHello(): void {
    const hello: HelloBody = new HelloBody();
    hello.nickname = this.nickname;
    hello.protocolVersion = PROTOCOL_VERSION;
    hello.hostToken = this.hostToken;
    this.send(MsgType.HELLO, hello);
  }

  private handle(text: string): void {
    const dr: DecodeResult = decode(text);
    if (!dr.ok || dr.env === undefined) {
      return;
    }
    const type: string = dr.env.t;
    const body: string = dr.env.body;
    if (type === MsgType.PONG) {
      return;
    }
    if (type === MsgType.ERROR) {
      let e: ErrorBody;
      try {
        e = JSON.parse(body) as ErrorBody;
      } catch (err) {
        this.onError(ErrCode.BAD_PROTOCOL, '');
        return;
      }
      // 版本不符或房间已满时没有重连的意义
      if (e.code === ErrCode.BAD_VERSION || e.code === ErrCode.ROOM_FULL) {
        this.manualClose = true;
      }
      this.onError(e.code, e.message);
      return;
    }
    this.onMessage(type, body);
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatId = setInterval(() => {
      this.send(MsgType.PING, new EmptyBody());
    }, HEARTBEAT_MS);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatId !== -1) {
      clearInterval(this.heartbeatId);
      this.heartbeatId = -1;
    }
  }

  private scheduleReconnect(): void {
    if (this.manualClose) {
      this.onStatus(ConnStatus.CLOSED);
      return;
    }
    if (this.retries >= RECONNECT_LIMIT) {
      this.onStatus(ConnStatus.FAILED);
      return;
    }
    const delay: number = Math.min(RECONNECT_BASE_MS * (1 << this.retries), RECONNECT_MAX_MS);
    const jitter: number = Math.floor(Math.random() * 200);
    this.retries++;
    this.onStatus(ConnStatus.RECONNECTING);
    this.reconnectId = setTimeout(() => {
      this.reconnectId = -1;
      this.open(true);
    }, delay + jitter);
  }

  send(type: string, body: Object): void {
    const ws: webSocket.WebSocket | undefined = this.ws;
    if (ws === undefined) {
      return;
    }
    const text: string = encode(type, this.seq++, body);
    ws.send(text).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'send failed %{public}s', err.message);
    });
  }

  close(): void {
    this.manualClose = true;
    this.stopHeartbeat();
    if (this.reconnectId !== -1) {
      clearTimeout(this.reconnectId);
      this.reconnectId = -1;
    }
    const ws: webSocket.WebSocket | undefined = this.ws;
    this.ws = undefined;
    this.onStatus(ConnStatus.CLOSED);
    if (ws !== undefined) {
      try {
        ws.close().catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'close failed %{public}s', err.message);
        });
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'close threw');
      }
    }
  }
}
