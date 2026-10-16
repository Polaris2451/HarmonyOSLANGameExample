import { RosterEntry } from './Protocol';

/** 一次操作的结果。 */
export class InputResult {
  ok: boolean = false;
  /** 非空表示要广播的一次性事件（win / reveal / ...）。 */
  event: string = '';
  /** 不合法时的原因码。 */
  reason: string = '';
}

/**
 * 房主侧对局会话的统一接口。
 * RoomServer 只依赖这个接口，因此新增游戏不用改网络层。
 * 三个要点：
 * 1. stateJsonFor 是按玩家生成的 —— 你画我猜里只有画手能看到词；
 * 2. tick 由房主定时驱动，负责推进计时；
 * 3. 所有规则判定都在这里，客户端只发意图。
 */
export interface GameSession {
  start(players: RosterEntry[]): void;

  applyInput(playerId: string, action: string, x: number, y: number, text: string): InputResult;

  /** 该玩家应该看到的快照。 */
  stateJsonFor(playerId: string): string;

  /** 定时推进；返回 true 表示状态有变化、需要广播。 */
  tick(now: number): boolean;

  isFinished(): boolean;
}
