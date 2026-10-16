import { RosterEntry } from '../../Protocol';
import { GameSession, InputResult } from '../../GameSession';
import { DRAW_WORDS, FALLBACK_WORD } from './WordBank';

export class DrawPhase {
  static readonly CHOOSING: string = 'choosing';
  static readonly DRAWING: string = 'drawing';
  static readonly REVEAL: string = 'reveal';
  static readonly ENDED: string = 'ended';
}

export class DrawEvent {
  static readonly ROUND_START: string = 'round_start';
  static readonly REVEAL: string = 'reveal';
  static readonly ENDED: string = 'ended';
}

const CHOOSE_SECONDS: number = 15;
const DRAW_SECONDS: number = 75;
const REVEAL_SECONDS: number = 5;
const TOTAL_ROUNDS: number = 3;
const CANDIDATE_COUNT: number = 3;
const MAX_STROKES: number = 800;
const GUESS_BASE: number = 100;
const GUESS_MIN: number = 30;
const DRAWER_BONUS: number = 50;

/** 每个玩家看到的自己那一份。 */
export class DrawPlayerView {
  id: string = '';
  nickname: string = '';
  score: number = 0;
  guessed: boolean = false;
  isDrawer: boolean = false;
}

export class DrawState {
  phase: string = DrawPhase.CHOOSING;
  round: number = 1;
  totalRounds: number = TOTAL_ROUNDS;
  drawerId: string = '';
  drawerName: string = '';
  /** 只有画手能拿到真实答案；其他人是空串。 */
  word: string = '';
  /** 猜词方的提示：用 ● 表示词长。 */
  wordMask: string = '';
  /** 词的字数，用于「共 N 个字」提示；还没选词时为 0。 */
  wordLength: number = 0;
  /** 只有画手在选择阶段能拿到候选词。 */
  candidates: string[] = [];
  /** 归一化坐标的笔画，按顺序重放。 */
  strokes: string[] = [];
  secondsLeft: number = 0;
  players: DrawPlayerView[] = [];
  finished: boolean = false;
  message: string = '';
}

/**
 * 你画我猜：回合制 + 实时笔画广播。
 * 关键点是**信息分层**：答案只发给画手，其他人只看到词长占位；
 * 猜词判定完全在房主这一侧做，客户端拿不到答案就没有作弊空间。
 */
export class DrawGuessGame implements GameSession {
  private players: RosterEntry[] = [];
  private scores: Map<string, number> = new Map();
  private drawerIndex: number = 0;
  private phase: string = DrawPhase.CHOOSING;
  private round: number = 0;
  private word: string = '';
  private candidates: string[] = [];
  private strokes: string[] = [];
  private phaseEndAt: number = 0;
  private guessed: Set<string> = new Set();
  private usedWords: Set<string> = new Set();
  private finished: boolean = false;
  private message: string = '';

  start(players: RosterEntry[]): void {
    this.players = players;
    this.scores = new Map();
    for (const p of players) {
      this.scores.set(p.id, 0);
    }
    this.drawerIndex = 0;
    this.round = 0;
    this.finished = false;
    this.beginRound(Date.now());
  }

  private drawer(): RosterEntry | undefined {
    if (this.players.length === 0) {
      return undefined;
    }
    return this.players[this.drawerIndex % this.players.length];
  }

  /**
   * 一轮 = 每个玩家各当一次画手。
   * 轮次由 drawerIndex 推导，不能简单地 ++，否则界面上的「第 N 轮」会把「每人各一次」
   * 算成 N 次，玩家会看到 6/3 这种数字并且以为永远不结束。
   */
  private beginRound(now: number): void {
    const n: number = this.players.length > 0 ? this.players.length : 1;
    this.round = Math.floor(this.drawerIndex / n) + 1;
    if (this.round > TOTAL_ROUNDS) {
      this.phase = DrawPhase.ENDED;
      this.finished = true;
      this.message = '';
      this.candidates = [];
      return;
    }
    this.phase = DrawPhase.CHOOSING;
    this.strokes = [];
    this.guessed = new Set();
    this.message = '';
    this.word = '';
    this.candidates = this.pickCandidates();
    this.phaseEndAt = now + CHOOSE_SECONDS * 1000;
  }

  private pickCandidates(): string[] {
    const pool: string[] = [];
    for (const w of DRAW_WORDS) {
      if (!this.usedWords.has(w)) {
        pool.push(w);
      }
    }
    if (pool.length < CANDIDATE_COUNT) {
      this.usedWords.clear();
      for (const w of DRAW_WORDS) {
        pool.push(w);
      }
    }
    const picked: string[] = [];
    for (let i = 0; i < CANDIDATE_COUNT && pool.length > 0; i++) {
      const idx: number = Math.floor(Math.random() * pool.length);
      picked.push(pool[idx]);
      pool.splice(idx, 1);
    }
    if (picked.length === 0) {
      picked.push(FALLBACK_WORD);
    }
    return picked;
  }

  private chooseWord(text: string, now: number): void {
    let picked: string = text;
    if (this.candidates.indexOf(picked) < 0) {
      picked = this.candidates.length > 0 ? this.candidates[0] : FALLBACK_WORD;
    }
    this.word = picked;
    this.usedWords.add(picked);
    this.candidates = [];
    this.phase = DrawPhase.DRAWING;
    this.strokes = [];
    this.guessed = new Set();
    this.phaseEndAt = now + DRAW_SECONDS * 1000;
  }

  applyInput(playerId: string, action: string, x: number, y: number, text: string): InputResult {
    const result: InputResult = new InputResult();
    const painter: RosterEntry | undefined = this.drawer();
    if (painter === undefined || this.finished) {
      result.reason = 'not_playing';
      return result;
    }
    const isDrawer: boolean = playerId === painter.id;

    if (action === 'choose') {
      if (!isDrawer || this.phase !== DrawPhase.CHOOSING) {
        result.reason = 'not_your_action';
        return result;
      }
      this.chooseWord(text, Date.now());
      result.ok = true;
      result.event = DrawEvent.ROUND_START;
      return result;
    }

    if (action === 'stroke') {
      if (!isDrawer || this.phase !== DrawPhase.DRAWING) {
        result.reason = 'not_your_action';
        return result;
      }
      if (this.strokes.length >= MAX_STROKES) {
        result.reason = 'too_many_strokes';
        return result;
      }
      // 笔画原样转发（已归一化），服务端不做几何处理
      this.strokes.push(text);
      result.ok = true;
      return result;
    }

    if (action === 'clear') {
      if (!isDrawer || this.phase !== DrawPhase.DRAWING) {
        result.reason = 'not_your_action';
        return result;
      }
      this.strokes = [];
      result.ok = true;
      return result;
    }

    if (action === 'guess') {
      if (isDrawer) {
        result.reason = 'drawer_cannot_guess';
        return result;
      }
      if (this.phase !== DrawPhase.DRAWING) {
        result.reason = 'not_drawing';
        return result;
      }
      if (this.guessed.has(playerId)) {
        result.reason = 'already_guessed';
        return result;
      }
      const guess: string = DrawGuessGame.normalize(text);
      if (guess.length === 0) {
        result.reason = 'empty';
        return result;
      }
      if (guess === DrawGuessGame.normalize(this.word)) {
        this.guessed.add(playerId);
        this.awardGuesser(playerId);
        this.message = '有人猜对了！';
        result.ok = true;
        result.event = DrawEvent.REVEAL;
        if (this.allGuessersDone()) {
          this.enterReveal(Date.now());
        }
        return result;
      }
      result.reason = 'wrong';
      return result;
    }

    result.reason = 'unknown_action';
    return result;
  }

  /** 猜得越快分越高；画手每被猜中一次拿固定奖励。 */
  private awardGuesser(playerId: string): void {
    const remainingMs: number = Math.max(0, this.phaseEndAt - Date.now());
    const elapsedSec: number = DRAW_SECONDS - Math.floor(remainingMs / 1000);
    const gain: number = Math.max(GUESS_MIN, GUESS_BASE - elapsedSec);
    const current: number = this.scores.get(playerId) ?? 0;
    this.scores.set(playerId, current + gain);

    const painter: RosterEntry | undefined = this.drawer();
    if (painter !== undefined) {
      const painterScore: number = this.scores.get(painter.id) ?? 0;
      this.scores.set(painter.id, painterScore + DRAWER_BONUS);
    }
  }

  private guesserCount(): number {
    const total: number = this.players.length;
    return total > 1 ? total - 1 : 1;
  }

  private allGuessersDone(): boolean {
    return this.guessed.size >= this.guesserCount();
  }

  private enterReveal(now: number): void {
    this.phase = DrawPhase.REVEAL;
    this.phaseEndAt = now + REVEAL_SECONDS * 1000;
  }

  private advanceDrawer(now: number): void {
    this.drawerIndex++;
    this.beginRound(now);
  }

  tick(now: number): boolean {
    if (this.finished) {
      return false;
    }
    if (now < this.phaseEndAt) {
      return false;
    }
    if (this.phase === DrawPhase.CHOOSING) {
      // 画手没选就替他选第一个，避免卡住
      const fallback: string = this.candidates.length > 0 ? this.candidates[0] : FALLBACK_WORD;
      this.chooseWord(fallback, now);
      return true;
    }
    if (this.phase === DrawPhase.DRAWING) {
      this.enterReveal(now);
      return true;
    }
    if (this.phase === DrawPhase.REVEAL) {
      this.advanceDrawer(now);
      return true;
    }
    return false;
  }

  isFinished(): boolean {
    return this.finished;
  }

  static normalize(text: string): string {
    let s: string = text;
    s = s.replace(/\s+/g, '');
    return s.toLowerCase();
  }

  private maskOf(word: string): string {
    let mask: string = '';
    for (let i = 0; i < word.length; i++) {
      mask += '●';
    }
    return mask;
  }

  stateJsonFor(playerId: string): string {
    const painter: RosterEntry | undefined = this.drawer();
    const isDrawer: boolean = painter !== undefined && playerId === painter.id;

    const state: DrawState = new DrawState();
    state.phase = this.phase;
    state.round = this.finished ? TOTAL_ROUNDS : (this.round > 0 ? this.round : 1);
    state.totalRounds = TOTAL_ROUNDS;
    state.drawerId = painter !== undefined ? painter.id : '';
    state.drawerName = painter !== undefined ? painter.nickname : '';
    state.strokes = this.strokes;
    state.finished = this.finished;
    state.message = this.message;
    state.secondsLeft = Math.max(0, Math.ceil((this.phaseEndAt - Date.now()) / 1000));
    state.wordLength = this.word.length;

    // 信息分层：只有画手拿到答案；其他人只看到词长
    if (isDrawer) {
      state.word = this.word;
      state.wordMask = '';
    } else {
      state.word = '';
      state.wordMask = this.word.length > 0 ? this.maskOf(this.word)
        : (this.phase === DrawPhase.REVEAL || this.phase === DrawPhase.ENDED
          ? this.maskOf(this.word) : '');
    }
    // 候选词同样只给画手
    state.candidates = (isDrawer && this.phase === DrawPhase.CHOOSING) ? this.candidates : [];

    // 进入 reveal / ended 后公开答案，否则无人知道对错
    if (this.phase === DrawPhase.REVEAL || this.phase === DrawPhase.ENDED) {
      state.word = this.word;
      state.wordMask = '';
    }

    const views: DrawPlayerView[] = [];
    for (const p of this.players) {
      const v: DrawPlayerView = new DrawPlayerView();
      v.id = p.id;
      v.nickname = p.nickname;
      v.score = this.scores.get(p.id) ?? 0;
      v.guessed = this.guessed.has(p.id);
      v.isDrawer = painter !== undefined && p.id === painter.id;
      views.push(v);
    }
    views.sort((a: DrawPlayerView, b: DrawPlayerView): number => b.score - a.score);
    state.players = views;
    return JSON.stringify(state);
  }
}
