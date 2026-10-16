import { PROTOCOL_VERSION } from './Routes';

/** 一条消息的信封。所有字段都是原始类型，方便直接 JSON 序列化。 */
export class Envelope {
  v: number = PROTOCOL_VERSION;
  t: string = '';
  seq: number = 0;
  body: string = '';
}

/** 消息类型。 */
export class MsgType {
  static readonly HELLO: string = 'hello';
  static readonly WELCOME: string = 'welcome';
  static readonly ROSTER: string = 'roster';
  static readonly ERROR: string = 'error';
  static readonly PING: string = 'ping';
  static readonly PONG: string = 'pong';
  static readonly START: string = 'start';
  static readonly BYE: string = 'bye';
  /** 客户端 -> 房主：一步操作。 */
  static readonly INPUT: string = 'input';
  /** 房主 -> 全体：完整状态快照。 */
  static readonly STATE: string = 'state';
  /** 房主 -> 全体/单人：一次性事件（非法操作、胜负）。 */
  static readonly EVENT: string = 'event';
}

/** 错误码，界面按码给文案，不直接显示服务器原文。 */
export class ErrCode {
  static readonly ROOM_FULL: string = 'room_full';
  static readonly BAD_VERSION: string = 'bad_version';
  static readonly BAD_PROTOCOL: string = 'bad_protocol';
  static readonly ALREADY_STARTED: string = 'already_started';
}

/** 连接状态，客户端与界面共用一套取值。 */
export class ConnStatus {
  static readonly CONNECTING: string = 'connecting';
  static readonly OPEN: string = 'open';
  static readonly RECONNECTING: string = 'reconnecting';
  static readonly CLOSED: string = 'closed';
  static readonly FAILED: string = 'failed';
}

export class HelloBody {
  nickname: string = '';
  protocolVersion: number = PROTOCOL_VERSION;
  /** 房主自己的客户端会带上这个令牌，服务器据此认出房主。 */
  hostToken: string = '';
}

export class WelcomeBody {
  playerId: string = '';
  game: string = '';
  maxPlayers: number = 2;
  protocolVersion: number = PROTOCOL_VERSION;
}

export class RosterEntry {
  id: string = '';
  nickname: string = '';
  isHost: boolean = false;
}

export class RosterBody {
  game: string = '';
  maxPlayers: number = 2;
  players: RosterEntry[] = [];
}

/** 没有内容的负载。 */
export class EmptyBody {
}

/** 客户端发来的一步操作。x/y 只对需要坐标的游戏有意义。 */
export class InputBody {
  action: string = '';
  x: number = -1;
  y: number = -1;
  /** 需要文本的操作（猜词、选词、笔画批次）放在这里。 */
  text: string = '';
}

/** 状态快照。payload 是具体游戏自己的 JSON，协议层不关心内容。 */
export class StateBody {
  game: string = '';
  payload: string = '';
}

/** 一次性事件。 */
export class EventBody {
  kind: string = '';
  message: string = '';
}

export class ErrorBody {
  code: string = '';
  message: string = '';
}

/** 解码结果，避免用异常表达「这是一条坏消息」。 */
export class DecodeResult {
  ok: boolean = false;
  reason: string = '';
  env: Envelope | undefined = undefined;
}

/** 打包一条消息。 */
export function encode(type: string, seq: number, body: Object): string {
  const env: Envelope = new Envelope();
  env.v = PROTOCOL_VERSION;
  env.t = type;
  env.seq = seq;
  env.body = JSON.stringify(body);
  return JSON.stringify(env);
}

/** 解析并校验一条消息，任何异常都折叠成 ok=false。 */
export function decode(text: string): DecodeResult {
  const result: DecodeResult = new DecodeResult();
  let env: Envelope;
  try {
    env = JSON.parse(text) as Envelope;
  } catch (err) {
    result.reason = ErrCode.BAD_PROTOCOL;
    return result;
  }
  if (env === undefined || env === null || env.t === undefined || env.t.length === 0) {
    result.reason = ErrCode.BAD_PROTOCOL;
    return result;
  }
  if (env.v !== PROTOCOL_VERSION) {
    result.reason = ErrCode.BAD_VERSION;
    return result;
  }
  result.ok = true;
  result.env = env;
  return result;
}
