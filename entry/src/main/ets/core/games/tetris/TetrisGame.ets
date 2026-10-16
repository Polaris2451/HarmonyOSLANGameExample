import { RosterEntry } from '../../Protocol';
import { GameSession, InputResult } from '../../GameSession';
import { PIECE_KINDS, colorIndex, rotationsOf, spawnX } from './TetrisPieces';
import { COLS, ROWS, TetrisBoard, garbageFor, scoreFor } from './TetrisBoard';

export class TetrisEvent {
  static readonly ENDED: string = 'ended';
}

/** 落下的基础间隔，随等级加快。 */
const BASE_DROP_MS: number = 800;
const MIN_DROP_MS: number = 120;
const LEVEL_STEP_LINES: number = 10;

export class TetrisPlayerView {
  id: string = '';
  nickname: string = '';
  /** 200 个字符：'0' 空，'1'..'7' 方块，'8' 垃圾行 */
  board: string = '';
  active: boolean = true;
  score: number = 0;
  lines: number = 0;
  level: number = 1;
  /** 待落下的垃圾行数 */
  incoming: number = 0;
  isSelf: boolean = false;
}

export class TetrisState {
  /** 自己排第一，对手第二，界面不用再找。 */
  players: TetrisPlayerView[] = [];
  /** 自己的活动方块；对手的不发，省流量也防作弊 */
  kind: string = '';
  rot: number = 0;
  x: number = 0;
  y: number = 0;
  nextKind: string = '';
  finished: boolean = false;
  winnerId: string = '';
  winnerName: string = '';
  /** 自己是否已经出局 */
  selfOut: boolean = false;
  message: string = '';
}

/** 单个玩家的运行状态。 */
class Runner {
  id: string = '';
  nickname: string = '';
  board: TetrisBoard = new TetrisBoard();
  bag: string[] = [];
  kind: string = '';
  nextKind: string = '';
  rot: number = 0;
  x: number = 0;
  y: number = 0;
  score: number = 0;
  lines: number = 0;
  level: number = 1;
  active: boolean = true;
  incoming: number = 0;
  /** 距离下一次自动下落还差多少毫秒 */
  dropAccum: number = 0;
}

/**
 * 双人俄罗斯方块对战。
 *
 * 规则要点：
 * 1. 房主这一侧是唯一权威，双方棋盘、出块顺序、消行判定全在这里；
 * 2. 消行会给对方累积垃圾行，对局结束时一次性落到对方底部；
 * 3. 谁的新方块出生位置被占住谁就出局，另一人获胜；
 * 4. 活动方块只发给自己，对手只看到棋盘快照和待落垃圾数。
 */
export class TetrisGame implements GameSession {
  private runners: Runner[] = [];
  private finished: boolean = false;
  private winnerId: string = '';
  private lastTickAt: number = 0;

  start(players: RosterEntry[]): void {
    this.runners = [];
    for (const p of players) {
      const r: Runner = new Runner();
      r.id = p.id;
      r.nickname = p.nickname;
      r.bag = [];
      this.refillBag(r);
      r.kind = this.takeFromBag(r);
      r.nextKind = this.takeFromBag(r);
      r.x = spawnX(r.kind);
      r.y = 0;
      r.rot = 0;
      this.runners.push(r);
    }
    this.finished = false;
    this.winnerId = '';
    this.lastTickAt = Date.now();
  }

  /** 7-bag：每一轮把 7 种各放一次再洗牌，避免长时间不出某个方块。 */
  private refillBag(r: Runner): void {
    const bag: string[] = [];
    for (const k of PIECE_KINDS) {
      bag.push(k);
    }
    for (let i = bag.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: string = bag[i];
      bag[i] = bag[j];
      bag[j] = tmp;
    }
    r.bag = bag;
  }

  private takeFromBag(r: Runner): string {
    if (r.bag.length === 0) {
      this.refillBag(r);
    }
    return r.bag.pop() ?? 'T';
  }

  private runnerOf(playerId: string): Runner | undefined {
    for (const r of this.runners) {
      if (r.id === playerId) {
        return r;
      }
    }
    return undefined;
  }

  private opponentOf(playerId: string): Runner | undefined {
    for (const r of this.runners) {
      if (r.id !== playerId) {
        return r;
      }
    }
    return undefined;
  }

  private dropInterval(r: Runner): number {
    const ms: number = BASE_DROP_MS - (r.level - 1) * 60;
    return ms < MIN_DROP_MS ? MIN_DROP_MS : ms;
  }

  /** 旋转：撞墙时左右各试几格，够用且不会卡死。 */
  private tryRotate(r: Runner, dir: number): boolean {
    const next: number = (r.rot + (dir > 0 ? 1 : 3)) % 4;
    const kicks: number[] = [0, -1, 1, -2, 2];
    for (const k of kicks) {
      if (!r.board.collides(r.kind, next, r.x + k, r.y)) {
        r.rot = next;
        r.x = r.x + k;
        return true;
      }
    }
    return false;
  }

  private tryMove(r: Runner, dx: number): boolean {
    if (r.board.collides(r.kind, r.rot, r.x + dx, r.y)) {
      return false;
    }
    r.x = r.x + dx;
    return true;
  }

  /** 固化当前方块，处理消行与垃圾行，然后出下一个。 */
  private lockAndNext(r: Runner): void {
    r.board.lock(r.kind, r.rot, r.x, r.y);
    const cleared: number = r.board.clearLines();
    if (cleared > 0) {
      r.lines = r.lines + cleared;
      r.score = r.score + scoreFor(cleared, r.level);
      r.level = Math.floor(r.lines / LEVEL_STEP_LINES) + 1;
      const garbage: number = garbageFor(cleared);
      if (garbage > 0) {
        const foe: Runner | undefined = this.opponentOf(r.id);
        if (foe !== undefined && foe.active) {
          foe.incoming = foe.incoming + garbage;
        }
      }
    }
    // 结算这一步收到的垃圾
    if (r.incoming > 0) {
      if (!r.board.addGarbage(r.incoming)) {
        this.eliminate(r);
        return;
      }
      r.incoming = 0;
    }
    if (!r.active) {
      return;
    }
    r.kind = r.nextKind;
    r.nextKind = this.takeFromBag(r);
    r.rot = 0;
    r.x = spawnX(r.kind);
    r.y = 0;
    r.dropAccum = 0;
    if (r.board.collides(r.kind, r.rot, r.x, r.y)) {
      this.eliminate(r);
    }
  }

  private eliminate(r: Runner): void {
    r.active = false;
    const alive: Runner[] = [];
    for (const other of this.runners) {
      if (other.active) {
        alive.push(other);
      }
    }
    if (alive.length <= 1) {
      this.finished = true;
      this.winnerId = alive.length === 1 ? alive[0].id : '';
    }
  }

  applyInput(playerId: string, action: string, x: number, y: number, text: string): InputResult {
    const result: InputResult = new InputResult();
    const r: Runner | undefined = this.runnerOf(playerId);
    if (r === undefined || this.finished) {
      result.reason = 'not_playing';
      return result;
    }
    if (!r.active) {
      result.reason = 'out';
      return result;
    }

    if (action === 'move') {
      if (this.tryMove(r, x < 0 ? -1 : 1)) {
        result.ok = true;
      } else {
        result.reason = 'blocked';
      }
      return result;
    }
    if (action === 'rotate') {
      if (this.tryRotate(r, x < 0 ? -1 : 1)) {
        result.ok = true;
      } else {
        result.reason = 'blocked';
      }
      return result;
    }
    // 只有一个「直接落下」：一路落到底并立即固定。
    // 自动下落由 tick 的重力负责，所以不需要再单独提供软降。
    if (action === 'harddrop') {
      let steps: number = 0;
      while (!r.board.collides(r.kind, r.rot, r.x, r.y + 1)) {
        r.y = r.y + 1;
        steps++;
      }
      r.score = r.score + steps * 2;
      this.lockAndNext(r);
      result.ok = true;
      return result;
    }

    result.reason = 'unknown_action';
    return result;
  }

  tick(now: number): boolean {
    if (this.finished || this.runners.length === 0) {
      return false;
    }
    if (this.lastTickAt === 0) {
      this.lastTickAt = now;
      return false;
    }
    const delta: number = now - this.lastTickAt;
    this.lastTickAt = now;
    let changed: boolean = false;

    for (const r of this.runners) {
      if (!r.active) {
        continue;
      }
      r.dropAccum = r.dropAccum + delta;
      const interval: number = this.dropInterval(r);
      while (r.dropAccum >= interval) {
        r.dropAccum = r.dropAccum - interval;
        if (!r.board.collides(r.kind, r.rot, r.x, r.y + 1)) {
          r.y = r.y + 1;
          changed = true;
        } else {
          this.lockAndNext(r);
          changed = true;
        }
        if (this.finished || !r.active) {
          break;
        }
      }
    }
    return changed;
  }

  isFinished(): boolean {
    return this.finished;
  }

  stateJsonFor(playerId: string): string {
    const me: Runner | undefined = this.runnerOf(playerId);
    const foe: Runner | undefined = this.opponentOf(playerId);

    const state: TetrisState = new TetrisState();
    const views: TetrisPlayerView[] = [];

    if (me !== undefined) {
      const v: TetrisPlayerView = new TetrisPlayerView();
      v.id = me.id;
      v.nickname = me.nickname;
      v.board = me.board.toCompact();
      v.active = me.active;
      v.score = me.score;
      v.lines = me.lines;
      v.level = me.level;
      v.incoming = me.incoming;
      v.isSelf = true;
      views.push(v);
      state.kind = me.kind;
      state.rot = me.rot;
      state.x = me.x;
      state.y = me.y;
      state.nextKind = me.nextKind;
      state.selfOut = !me.active;
    }
    if (foe !== undefined) {
      const v: TetrisPlayerView = new TetrisPlayerView();
      v.id = foe.id;
      v.nickname = foe.nickname;
      v.board = foe.board.toCompact();
      v.active = foe.active;
      v.score = foe.score;
      v.lines = foe.lines;
      v.level = foe.level;
      v.incoming = foe.incoming;
      v.isSelf = false;
      views.push(v);
    }

    state.players = views;
    state.finished = this.finished;
    state.winnerId = this.winnerId;
    if (this.finished) {
      const winner: Runner | undefined = this.runnerOf(this.winnerId);
      state.winnerName = winner !== undefined ? winner.nickname : '';
      state.message = me !== undefined && me.id === this.winnerId ? 'win' : 'lose';
    }
    return JSON.stringify(state);
  }
}
