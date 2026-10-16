import { RosterEntry } from '../../Protocol';
import { GameSession, InputResult } from '../../GameSession';
import { GomokuRules, GOMOKU_SIZE, STONE_BLACK, STONE_EMPTY, STONE_WHITE } from './GomokuRules';

/** 下发给客户端的完整快照。 */
export class GomokuState {
  cells: number[] = [];
  turn: number = STONE_BLACK;
  /** 0 表示无胜者（未结束或和棋）。 */
  winner: number = STONE_EMPTY;
  lastX: number = -1;
  lastY: number = -1;
  finished: boolean = false;
  blackId: string = '';
  whiteId: string = '';
  blackName: string = '';
  whiteName: string = '';
}

export class EventKind {
  static readonly WIN: string = 'win';
  static readonly DRAW: string = 'draw';
  static readonly RESIGN: string = 'resign';
  static readonly ILLEGAL: string = 'illegal';
}

/** 一次操作的结果。 */
/**
 * 五子棋对局，跑在房主进程里。
 * 只接受「落子」和「认输」两种操作，其余一律挡回，保证规则不依赖客户端。
 */
export class GomokuGame implements GameSession {
  private cells: number[] = GomokuRules.emptyBoard();
  private turn: number = STONE_BLACK;
  private winner: number = STONE_EMPTY;
  private lastX: number = -1;
  private lastY: number = -1;
  private finished: boolean = false;
  private blackId: string = '';
  private whiteId: string = '';
  private blackName: string = '';
  private whiteName: string = '';

  /** 开局：先加入的执黑。 */
  start(players: RosterEntry[]): void {
    this.cells = GomokuRules.emptyBoard();
    this.turn = STONE_BLACK;
    this.winner = STONE_EMPTY;
    this.lastX = -1;
    this.lastY = -1;
    this.finished = false;
    this.blackId = '';
    this.whiteId = '';
    this.blackName = '';
    this.whiteName = '';
    if (players.length > 0) {
      this.blackId = players[0].id;
      this.blackName = players[0].nickname;
    }
    if (players.length > 1) {
      this.whiteId = players[1].id;
      this.whiteName = players[1].nickname;
    }
  }

  colorOf(playerId: string): number {
    if (playerId.length > 0 && playerId === this.blackId) {
      return STONE_BLACK;
    }
    if (playerId.length > 0 && playerId === this.whiteId) {
      return STONE_WHITE;
    }
    return STONE_EMPTY;
  }

  applyInput(playerId: string, action: string, x: number, y: number, text: string): InputResult {
    const result: InputResult = new InputResult();
    if (this.finished) {
      result.reason = 'finished';
      return result;
    }
    const color: number = this.colorOf(playerId);
    if (color === STONE_EMPTY) {
      result.reason = 'not_playing';
      return result;
    }
    if (action === 'resign') {
      this.finished = true;
      this.winner = GomokuRules.opponent(color);
      result.ok = true;
      result.event = EventKind.RESIGN;
      return result;
    }
    if (action !== 'place') {
      result.reason = 'unknown_action';
      return result;
    }
    if (color !== this.turn) {
      result.reason = 'not_your_turn';
      return result;
    }
    if (!GomokuRules.inBounds(x, y)) {
      result.reason = 'out_of_bounds';
      return result;
    }
    const index: number = GomokuRules.indexOf(x, y);
    if (this.cells[index] !== STONE_EMPTY) {
      result.reason = 'occupied';
      return result;
    }

    this.cells[index] = color;
    this.lastX = x;
    this.lastY = y;

    if (GomokuRules.isWinningMove(this.cells, x, y, color)) {
      this.winner = color;
      this.finished = true;
      result.ok = true;
      result.event = EventKind.WIN;
      return result;
    }
    if (GomokuRules.isFull(this.cells)) {
      this.winner = STONE_EMPTY;
      this.finished = true;
      result.ok = true;
      result.event = EventKind.DRAW;
      return result;
    }
    this.turn = GomokuRules.opponent(color);
    result.ok = true;
    return result;
  }

  /** 五子棋没有隐藏信息，所有人看同一份。 */
  stateJsonFor(playerId: string): string {
    return this.stateJson();
  }

  /** 五子棋没有计时器。 */
  tick(now: number): boolean {
    return false;
  }

  isFinished(): boolean {
    return this.finished;
  }

  stateJson(): string {
    const state: GomokuState = new GomokuState();
    state.cells = this.cells;
    state.turn = this.turn;
    state.winner = this.winner;
    state.lastX = this.lastX;
    state.lastY = this.lastY;
    state.finished = this.finished;
    state.blackId = this.blackId;
    state.whiteId = this.whiteId;
    state.blackName = this.blackName;
    state.whiteName = this.whiteName;
    return JSON.stringify(state);
  }

  size(): number {
    return GOMOKU_SIZE;
  }
}
