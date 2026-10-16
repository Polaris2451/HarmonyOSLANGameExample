import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameKind, gameMaxPlayers } from '../core/GameKind';
import {
  DecodeResult, EmptyBody, ErrCode, ErrorBody, EventBody, HelloBody, InputBody, MsgType,
  RosterBody, RosterEntry, StateBody, WelcomeBody, decode, encode
} from '../core/Protocol';
import { PROTOCOL_VERSION } from '../core/Routes';
import { EventKind } from '../core/games/gomoku/GomokuGame';
import { GameSession, InputResult } from '../core/GameSession';
import { GomokuGame } from '../core/games/gomoku/GomokuGame';
import { DrawGuessGame } from '../core/games/drawguess/DrawGuessGame';

const DOMAIN: number = 0x0000;
const TAG: string = 'RoomServer';
const SWEEP_INTERVAL_MS: number = 3000;
const CLIENT_TIMEOUT_MS: number = 12000;

/** 服务器侧记住的一个连接。 */
class ServerClient {
  id: string;
  nickname: string;
  isHost: boolean;
  conn: webSocket.WebSocketConnection;
  lastSeen: number;
  helloDone: boolean;

  constructor(id: string, conn: webSocket.WebSocketConnection) {
    this.id = id;
    this.nickname = '';
    this.isHost = false;
    this.conn = conn;
    this.lastSeen = Date.now();
    this.helloDone = false;
  }
}

/** start() 的结果，用错误码而不是异常来表达失败。 */
export class StartResult {
  ok: boolean = false;
  /** busy = 端口被占用 / nic = 地址不可用 / permission = 缺权限 / unknown */
  errorCode: string = '';
  detail: string = '';
}

/**
 * 房主侧的服务器，包住 webSocket.createWebSocketServer()。
 * 只负责连接管理、握手、成员广播和心跳；具体游戏规则在后续步骤加。
 */
export class RoomServer {
  private server: webSocket.WebSocketServer | undefined = undefined;
  private clients: Map<string, ServerClient> = new Map();
  private timerId: number = -1;
  private tickId: number = -1;
  private nextId: number = 1;
  private token: string = '';
  /** 当前对局。房间只有一个对局，结束后再开局会整局重建。 */
  private gameSession: GameSession | undefined = undefined;

  port: number = 0;
  game: string = '';
  running: boolean = false;

  onRoster: (players: RosterEntry[], maxPlayers: number) => void = () => {};

  hostToken(): string {
    return this.token;
  }

  private maxPlayers(): number {
    return gameMaxPlayers(this.game);
  }

  private keyOf(conn: webSocket.WebSocketConnection): string {
    return conn.clientIP + ':' + conn.clientPort.toString();
  }

  private readyCount(): number {
    let n: number = 0;
    this.clients.forEach((c: ServerClient) => {
      if (c.helloDone) {
        n++;
      }
    });
    return n;
  }

  async start(port: number, game: string, hostNickname: string): Promise<StartResult> {
    const result: StartResult = new StartResult();
    if (this.running) {
      await this.stop();
    }
    this.port = port;
    this.game = game;
    this.nextId = 1;
    this.gameSession = undefined;
    this.token = 'ht' + Date.now().toString(36) + Math.floor(Math.random() * 100000).toString(36);

    const srv: webSocket.WebSocketServer = webSocket.createWebSocketServer();
    // 注意两个上限的语义差别：
    // maxConcurrentClientsNumber 是总连接数；
    // maxConnectionsForOneClient 是「同一个来源 IP」的连接数 —— 模拟器经宿主机端口映射时
    // 所有客户端看起来都来自 127.0.0.1，取太小会导致第 3 个连接直接在 WebSocket 层被拒（错误码 200）。
    // 显式写 serverIP 会触发 2302999，所以这里不写。
    // 两个上限都不能超过官方文档的默认值 10，超过会直接 2302999 起不来；
    // 但 maxConnectionsForOneClient 也不能取太小，模拟器经端口映射时所有客户端都来自 127.0.0.1。
    const cfg: webSocket.WebSocketServerConfig = {
      serverPort: port,
      maxConcurrentClientsNumber: 8,
      maxConnectionsForOneClient: 8
    };
    try {
      const started: boolean = await srv.start(cfg);
      if (!started) {
        result.errorCode = 'unknown';
        return result;
      }
    } catch (err) {
      const be = err as BusinessError;
      result.errorCode = this.classify(be.code);
      result.detail = be.message;
      hilog.error(DOMAIN, TAG, 'start failed: %{public}d %{public}s', be.code, be.message);
      return result;
    }

    this.server = srv;
    this.attach(srv, hostNickname);
    this.running = true;
    this.timerId = setInterval(() => {
      this.sweep();
    }, SWEEP_INTERVAL_MS);
    // 1 秒一次驱动对局计时（你画我猜的选词/作画/揭晓靠它推进）
    this.tickId = setInterval(() => {
      this.onTick();
    }, 1000);
    result.ok = true;
    hilog.info(DOMAIN, TAG, 'server listening on %{public}d', port);
    return result;
  }

  private classify(code: number): string {
    if (code === 2302005 || code === 2302007) {
      return 'busy';
    }
    if (code === 2302004) {
      return 'nic';
    }
    if (code === 201) {
      return 'permission';
    }
    return 'unknown';
  }

  private attach(srv: webSocket.WebSocketServer, hostNickname: string): void {
    srv.on('connect', (conn: webSocket.WebSocketConnection) => {
      const key: string = this.keyOf(conn);
      this.clients.set(key, new ServerClient('p' + (this.nextId++).toString(), conn));
      hilog.info(DOMAIN, TAG, 'connected %{public}s', key);
    });

    srv.on('messageReceive', (msg: webSocket.WebSocketMessage) => {
      const key: string = this.keyOf(msg.clientConnection);
      const client: ServerClient | undefined = this.clients.get(key);
      if (client === undefined) {
        return;
      }
      client.lastSeen = Date.now();
      const text: string = typeof msg.data === 'string' ? msg.data : '';
      this.handle(client, key, text, hostNickname);
    });

    srv.on('close', (conn: webSocket.WebSocketConnection) => {
      const key: string = this.keyOf(conn);
      this.clients.delete(key);
      hilog.info(DOMAIN, TAG, 'disconnected %{public}s', key);
      this.broadcastRoster();
    });

    srv.on('error', (err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'server error: %{public}d %{public}s', err.code, err.message);
    });
  }

  private handle(client: ServerClient, key: string, text: string, hostNickname: string): void {
    const dr: DecodeResult = decode(text);
    if (!dr.ok || dr.env === undefined) {
      const code: string = dr.reason.length > 0 ? dr.reason : ErrCode.BAD_PROTOCOL;
      if (code === ErrCode.BAD_VERSION) {
        this.reject(client, key, code);
      } else {
        this.sendError(client, code);
      }
      return;
    }
    const type: string = dr.env.t;
    const body: string = dr.env.body;

    if (type === MsgType.HELLO) {
      this.onHello(client, key, body, hostNickname);
      return;
    }
    if (!client.helloDone) {
      this.reject(client, key, ErrCode.BAD_PROTOCOL);
      return;
    }
    if (type === MsgType.PING) {
      this.sendTo(client, MsgType.PONG, new EmptyBody());
      return;
    }
    if (type === MsgType.START) {
      if (client.isHost && this.readyCount() >= 2) {
        this.beginGame();
      } else {
        this.sendError(client, ErrCode.ALREADY_STARTED);
      }
      return;
    }
    if (type === MsgType.INPUT) {
      this.onInput(client, body);
      return;
    }
  }

  /** 按「房主在前」的顺序取出已握手的连接。 */
  private orderedReady(): ServerClient[] {
    const list: ServerClient[] = [];
    this.clients.forEach((c: ServerClient) => {
      if (c.helloDone) {
        list.push(c);
      }
    });
    list.sort((a: ServerClient, b: ServerClient): number => {
      if (a.isHost === b.isHost) {
        return 0;
      }
      return a.isHost ? -1 : 1;
    });
    return list;
  }

  /** 开局：建立新对局，先发状态再发开始，保证客户端跳过去时棋盘已就绪。 */
  private beginGame(): void {
    const players: RosterEntry[] = [];
    for (const c of this.orderedReady()) {
      const entry: RosterEntry = new RosterEntry();
      entry.id = c.id;
      entry.nickname = c.nickname;
      entry.isHost = c.isHost;
      players.push(entry);
    }
    const session: GameSession = this.game === GameKind.DRAW_GUESS
      ? new DrawGuessGame() : new GomokuGame();
    session.start(players);
    this.gameSession = session;
    hilog.info(DOMAIN, TAG, 'game started with %{public}d players', players.length);

    this.broadcastState();
    this.clients.forEach((c: ServerClient) => {
      if (c.helloDone) {
        this.sendTo(c, MsgType.START, new EmptyBody());
      }
    });
  }

  private onTick(): void {
    const session: GameSession | undefined = this.gameSession;
    if (session === undefined) {
      return;
    }
    if (session.tick(Date.now())) {
      this.broadcastState();
    }
  }

  private onInput(client: ServerClient, body: string): void {
    const session: GameSession | undefined = this.gameSession;
    if (session === undefined) {
      return;
    }
    let input: InputBody;
    try {
      input = JSON.parse(body) as InputBody;
    } catch (err) {
      this.sendError(client, ErrCode.BAD_PROTOCOL);
      return;
    }
    const result: InputResult = session.applyInput(client.id, input.action, input.x, input.y, input.text);
    if (!result.ok) {
      // 非法操作只回给发起者，不打扰对手
      const ev: EventBody = new EventBody();
      ev.kind = EventKind.ILLEGAL;
      ev.message = result.reason;
      this.sendTo(client, MsgType.EVENT, ev);
      return;
    }
    this.broadcastState();
    if (result.event.length > 0) {
      const ev: EventBody = new EventBody();
      ev.kind = result.event;
      ev.message = '';
      this.clients.forEach((c: ServerClient) => {
        if (c.helloDone) {
          this.sendTo(c, MsgType.EVENT, ev);
        }
      });
    }
  }

  /** 每个客户端拿到的是「自己那一份」快照：你画我猜里只有画手能看到答案。 */
  private broadcastState(): void {
    const session: GameSession | undefined = this.gameSession;
    if (session === undefined) {
      return;
    }
    this.clients.forEach((c: ServerClient) => {
      if (!c.helloDone) {
        return;
      }
      const body: StateBody = new StateBody();
      body.game = this.game;
      body.payload = session.stateJsonFor(c.id);
      this.sendTo(c, MsgType.STATE, body);
    });
  }

  private onHello(client: ServerClient, key: string, body: string, hostNickname: string): void {
    let hello: HelloBody;
    try {
      hello = JSON.parse(body) as HelloBody;
    } catch (err) {
      this.reject(client, key, ErrCode.BAD_PROTOCOL);
      return;
    }
    if (hello.protocolVersion !== PROTOCOL_VERSION) {
      this.reject(client, key, ErrCode.BAD_VERSION);
      return;
    }
    const isHost: boolean = hello.hostToken.length > 0 && hello.hostToken === this.token;

    // 房主自己的客户端允许补位重连；其他人在满员时被拒绝
    if (!isHost && this.readyCount() >= this.maxPlayers()) {
      this.reject(client, key, ErrCode.ROOM_FULL);
      return;
    }

    client.nickname = this.uniqueNickname(isHost ? hostNickname : hello.nickname);
    client.isHost = isHost;
    client.helloDone = true;

    const welcome: WelcomeBody = new WelcomeBody();
    welcome.playerId = client.id;
    welcome.game = this.game;
    welcome.maxPlayers = this.maxPlayers();
    welcome.protocolVersion = PROTOCOL_VERSION;
    this.sendTo(client, MsgType.WELCOME, welcome);
    this.broadcastRoster();
  }

  private uniqueNickname(wanted: string): string {
    const base: string = wanted.length > 0 ? wanted : '玩家';
    let name: string = base;
    let suffix: number = 2;
    while (this.nicknameTaken(name)) {
      name = base + '#' + suffix.toString();
      suffix++;
    }
    return name;
  }

  private nicknameTaken(name: string): boolean {
    let taken: boolean = false;
    this.clients.forEach((c: ServerClient) => {
      if (c.helloDone && c.nickname === name) {
        taken = true;
      }
    });
    return taken;
  }

  private broadcastRoster(): void {
    const entries: RosterEntry[] = [];
    this.clients.forEach((c: ServerClient) => {
      if (c.helloDone) {
        const entry: RosterEntry = new RosterEntry();
        entry.id = c.id;
        entry.nickname = c.nickname;
        entry.isHost = c.isHost;
        entries.push(entry);
      }
    });
    entries.sort((a: RosterEntry, b: RosterEntry): number => {
      if (a.isHost === b.isHost) {
        return 0;
      }
      return a.isHost ? -1 : 1;
    });

    const body: RosterBody = new RosterBody();
    body.game = this.game;
    body.maxPlayers = this.maxPlayers();
    body.players = entries;

    this.clients.forEach((c: ServerClient) => {
      if (c.helloDone) {
        this.sendTo(c, MsgType.ROSTER, body);
      }
    });
    this.onRoster(entries, this.maxPlayers());
  }

  private sendTo(client: ServerClient, type: string, body: Object): void {
    const srv: webSocket.WebSocketServer | undefined = this.server;
    if (srv === undefined) {
      return;
    }
    srv.send(encode(type, 0, body), client.conn).then((ok: boolean) => {
      if (!ok) {
        hilog.warn(DOMAIN, TAG, 'send returned false');
      }
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'send failed: %{public}s', err.message);
    });
  }

  private sendError(client: ServerClient, code: string): void {
    const body: ErrorBody = new ErrorBody();
    body.code = code;
    body.message = code;
    this.sendTo(client, MsgType.ERROR, body);
  }

  /**
   * 先发错误帧、等发送完成再断开。
   * 直接 send 后立刻 close 会丢掉这一帧，客户端只会看到「连接被关闭」而拿不到原因。
   */
  private reject(client: ServerClient, key: string, code: string): void {
    const srv: webSocket.WebSocketServer | undefined = this.server;
    hilog.info(DOMAIN, TAG, 'reject %{public}s code=%{public}s', key, code);
    this.clients.delete(key);
    if (srv === undefined) {
      this.broadcastRoster();
      return;
    }
    const body: ErrorBody = new ErrorBody();
    body.code = code;
    body.message = code;
    const text: string = encode(MsgType.ERROR, 0, body);
    // 发送 Promise 落定只代表「已交给底层」，立刻 close 仍可能截断这一帧。
    // 留一点时间让它真正写出去，客户端才能拿到拒绝原因。
    const CLOSE_DELAY_MS: number = 500;
    srv.send(text, client.conn).then((ok: boolean) => {
      hilog.info(DOMAIN, TAG, 'reject sent ok=%{public}s', String(ok));
      setTimeout(() => {
        this.closeConn(srv, client);
      }, CLOSE_DELAY_MS);
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'reject send failed: %{public}s', err.message);
      setTimeout(() => {
        this.closeConn(srv, client);
      }, CLOSE_DELAY_MS);
    });
    this.broadcastRoster();
  }

  private closeConn(srv: webSocket.WebSocketServer, client: ServerClient): void {
    try {
      srv.close(client.conn).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'close failed: %{public}s', err.message);
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'close threw');
    }
  }

  private drop(client: ServerClient, key: string): void {
    const srv: webSocket.WebSocketServer | undefined = this.server;
    this.clients.delete(key);
    if (srv !== undefined) {
      try {
        srv.close(client.conn).catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'close failed: %{public}s', err.message);
        });
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'close threw');
      }
    }
    this.broadcastRoster();
  }

  private sweep(): void {
    const now: number = Date.now();
    const stale: string[] = [];
    this.clients.forEach((c: ServerClient, key: string) => {
      if (now - c.lastSeen > CLIENT_TIMEOUT_MS) {
        stale.push(key);
      }
    });
    for (const key of stale) {
      const c: ServerClient | undefined = this.clients.get(key);
      if (c !== undefined) {
        hilog.info(DOMAIN, TAG, 'timeout %{public}s', key);
        this.drop(c, key);
      }
    }
  }

  async stop(): Promise<void> {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.tickId !== -1) {
      clearInterval(this.tickId);
      this.tickId = -1;
    }
    const srv: webSocket.WebSocketServer | undefined = this.server;
    this.server = undefined;
    this.clients.clear();
    this.running = false;
    if (srv !== undefined) {
      try {
        await srv.stop();
        hilog.info(DOMAIN, TAG, 'server stopped');
      } catch (err) {
        const be = err as BusinessError;
        hilog.warn(DOMAIN, TAG, 'stop failed: %{public}s', be.message);
      }
    }
  }
}
