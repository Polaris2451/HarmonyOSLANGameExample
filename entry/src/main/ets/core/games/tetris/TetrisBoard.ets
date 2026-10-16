import { colorIndex, rotationsOf } from './TetrisPieces';

export const COLS: number = 10;
export const ROWS: number = 20;

/**
 * 一块 10×20 的棋盘。
 * 格子存成一维数组（索引 = y * COLS + x），值 0 表示空，1..7 表示颜色编号。
 */
export class TetrisBoard {
  cells: number[] = [];

  constructor() {
    for (let i = 0; i < COLS * ROWS; i++) {
      this.cells.push(0);
    }
  }

  at(x: number, y: number): number {
    if (x < 0 || x >= COLS || y < 0 || y >= ROWS) {
      return -1;
    }
    return this.cells[y * COLS + x];
  }

  private set(x: number, y: number, v: number): void {
    if (x < 0 || x >= COLS || y < 0 || y >= ROWS) {
      return;
    }
    this.cells[y * COLS + x] = v;
  }

  /** 该方块放在 (px, py) 时是否越界或与已有格子重叠。 */
  collides(kind: string, rot: number, px: number, py: number): boolean {
    const states: number[][][] = rotationsOf(kind);
    const cells: number[][] = states[rot % 4];
    for (const c of cells) {
      const x: number = px + c[0];
      const y: number = py + c[1];
      if (x < 0 || x >= COLS || y >= ROWS) {
        return true;
      }
      // y < 0 是出生时露在顶部外面，允许
      if (y >= 0 && this.cells[y * COLS + x] !== 0) {
        return true;
      }
    }
    return false;
  }

  /** 把方块固化到棋盘上。 */
  lock(kind: string, rot: number, px: number, py: number): void {
    const states: number[][][] = rotationsOf(kind);
    const cells: number[][] = states[rot % 4];
    const color: number = colorIndex(kind);
    for (const c of cells) {
      this.set(px + c[0], py + c[1], color);
    }
  }

  /** 消掉填满的行，返回消掉的行数。 */
  clearLines(): number {
    let cleared: number = 0;
    for (let y = ROWS - 1; y >= 0; y--) {
      let full: boolean = true;
      for (let x = 0; x < COLS; x++) {
        if (this.cells[y * COLS + x] === 0) {
          full = false;
          break;
        }
      }
      if (!full) {
        continue;
      }
      cleared++;
      // 把这一行以上的整体下移
      for (let yy = y; yy > 0; yy--) {
        for (let x = 0; x < COLS; x++) {
          this.cells[yy * COLS + x] = this.cells[(yy - 1) * COLS + x];
        }
      }
      for (let x = 0; x < COLS; x++) {
        this.cells[x] = 0;
      }
      y++; // 同一行要重新检查（上面的内容已经移下来）
    }
    return cleared;
  }

  /**
   * 从底部塞进 n 行垃圾，中间留一个随机缺口。
   * 返回 false 表示顶到天花板了（对方赢）。
   */
  addGarbage(n: number): boolean {
    if (n <= 0) {
      return true;
    }
    for (let i = 0; i < n; i++) {
      // 整体上移一行，最顶行若被占满说明出局
      for (let x = 0; x < COLS; x++) {
        if (this.cells[x] !== 0) {
          return false;
        }
      }
      for (let y = 0; y < ROWS - 1; y++) {
        for (let x = 0; x < COLS; x++) {
          this.cells[y * COLS + x] = this.cells[(y + 1) * COLS + x];
        }
      }
      const gap: number = Math.floor(Math.random() * COLS);
      for (let x = 0; x < COLS; x++) {
        this.cells[(ROWS - 1) * COLS + x] = x === gap ? 0 : 8;
      }
    }
    return true;
  }

  /** 打包成 200 个字符，网络传输用。 */
  toCompact(): string {
    let s: string = '';
    for (let i = 0; i < this.cells.length; i++) {
      s += String.fromCharCode(48 + this.cells[i]);
    }
    return s;
  }
}

/** 消行数对应的送给对方的垃圾行数。 */
export function garbageFor(cleared: number): number {
  if (cleared >= 4) {
    return 4;
  }
  if (cleared === 3) {
    return 2;
  }
  if (cleared === 2) {
    return 1;
  }
  return 0;
}

/** 消行得分，乘当前等级。 */
export function scoreFor(cleared: number, level: number): number {
  const table: number[] = [0, 100, 300, 500, 800];
  const idx: number = cleared > 4 ? 4 : cleared;
  return table[idx] * level;
}
