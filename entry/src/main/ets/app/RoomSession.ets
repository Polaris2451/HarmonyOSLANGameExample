import { hilog } from '@kit.PerformanceAnalysisKit';
import { RoomServer, StartResult } from '../net/RoomServer';
import { RoomClient } from '../net/RoomClient';
import { ConnStatus, EmptyBody, MsgType, RosterBody, RosterEntry, WelcomeBody } from '../core/Protocol';
import { RoomRoute } from '../core/RoomRoute';

const DOMAIN: number = 0x0000;
const TAG: string = 'RoomSession';

/**
 * 房间会话：把「房主服务器」和「客户端」合成一个对象交给页面。
 * 房主 = 先起 server，再让自己的 client 连 127.0.0.1，两边代码路径完全一致。
 * 进程级单例，因为创建房间页要先起服务器、再由房间页接管。
 */
export class RoomSession {
  private static inst: RoomSession | undefined = undefined;

  static get(): RoomSession {
    if (RoomSession.inst === undefined) {
      RoomSession.inst = new RoomSession();
    }
    return RoomSession.inst;
  }

  server: RoomServer | undefined = undefined;
  client: RoomClient | undefined = undefined;
  route: RoomRoute = new RoomRoute();
  selfId: string = '';
  status: string = ConnStatus.CLOSED;
  errorCode: string = '';
  started: boolean = false;

  onRoster: (players: RosterEntry[], maxPlayers: number) => void = () => {};
  onStatus: (status: string) => void = () => {};
  onError: (code: string) => void = () => {};
  onStarted: () => void = () => {};

  /** 房主：起服务器（失败会返回错误码，由调用方提示）。 */
  async startServer(port: number, game: string, nickname: string): Promise<StartResult> {
    await this.teardownServer();
    const srv: RoomServer = new RoomServer();
    const result: StartResult = await srv.start(port, game, nickname);
    if (!result.ok) {
      return result;
    }
    srv.onRoster = (players: RosterEntry[], maxPlayers: number) => {
      this.onRoster(players, maxPlayers);
    };
    srv.onStart = () => {
      this.started = true;
      this.onStarted();
    };
    this.server = srv;
    this.route.isHost = true;
    this.route.game = game;
    this.route.port = port;
    this.route.nickname = nickname;
    return result;
  }

  /** 房主自己的客户端连本机回环，和加入方走同一条路径。 */
  connectLocal(): void {
    const srv: RoomServer | undefined = this.server;
    if (srv === undefined) {
      return;
    }
    this.connect('ws://127.0.0.1:' + this.route.port.toString(), this.route.nickname,
      srv.hostToken());
  }

  /** 加入方连接房主。 */
  connectRemote(hostIp: string, port: number, nickname: string): void {
    this.route.isHost = false;
    this.route.hostIp = hostIp;
    this.route.port = port;
    this.route.nickname = nickname;
    this.connect('ws://' + hostIp + ':' + port.toString(), nickname, '');
  }

  private connect(url: string, nickname: string, hostToken: string): void {
    this.teardownClient();
    const client: RoomClient = new RoomClient();
    client.onStatus = (status: string) => {
      this.status = status;
      this.onStatus(status);
    };
    client.onError = (code: string) => {
      this.errorCode = code;
      this.onError(code);
    };
    client.onMessage = (type: string, body: string) => {
      this.dispatch(type, body);
    };
    this.client = client;
    client.connect(url, nickname, hostToken);
  }

  private dispatch(type: string, body: string): void {
    if (type === MsgType.WELCOME) {
      try {
        const w: WelcomeBody = JSON.parse(body) as WelcomeBody;
        this.selfId = w.playerId;
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'bad welcome');
      }
      return;
    }
    if (type === MsgType.ROSTER) {
      try {
        const r: RosterBody = JSON.parse(body) as RosterBody;
        this.onRoster(r.players, r.maxPlayers);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'bad roster');
      }
      return;
    }
    if (type === MsgType.START) {
      this.started = true;
      this.onStarted();
      return;
    }
  }

  /** 房主点开始：发一条 START，由服务器校验人数后广播。 */
  requestStart(): void {
    const client: RoomClient | undefined = this.client;
    if (client === undefined) {
      return;
    }
    client.send(MsgType.START, new EmptyBody());
  }

  private teardownClient(): void {
    const c: RoomClient | undefined = this.client;
    this.client = undefined;
    if (c !== undefined) {
      c.close();
    }
  }

  private async teardownServer(): Promise<void> {
    const s: RoomServer | undefined = this.server;
    this.server = undefined;
    if (s !== undefined) {
      await s.stop();
    }
  }

  /** 离开房间：客户端断开，房主还要关掉服务器。 */
  async leave(): Promise<void> {
    this.teardownClient();
    await this.teardownServer();
    this.selfId = '';
    this.status = ConnStatus.CLOSED;
    this.started = false;
  }
}
