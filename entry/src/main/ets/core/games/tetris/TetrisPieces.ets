/**
 * 七种方块的基础形状与旋转。
 * 做法是给出 N×N 的基础矩阵，然后对矩阵做 90° 旋转得到 4 个旋转态，
 * 比手写 28 组坐标更不容易出错。
 */

export const PIECE_KINDS: string[] = ['I', 'O', 'T', 'S', 'Z', 'J', 'L'];

function baseShape(kind: string): number[][] {
  if (kind === 'I') {
    return [[0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0]];
  }
  if (kind === 'O') {
    return [[1, 1], [1, 1]];
  }
  if (kind === 'T') {
    return [[0, 1, 0], [1, 1, 1], [0, 0, 0]];
  }
  if (kind === 'S') {
    return [[0, 1, 1], [1, 1, 0], [0, 0, 0]];
  }
  if (kind === 'Z') {
    return [[1, 1, 0], [0, 1, 1], [0, 0, 0]];
  }
  if (kind === 'J') {
    return [[1, 0, 0], [1, 1, 1], [0, 0, 0]];
  }
  // L
  return [[0, 0, 1], [1, 1, 1], [0, 0, 0]];
}

/** 顺时针旋转 90°。 */
function rotateCW(m: number[][]): number[][] {
  const n: number = m.length;
  const out: number[][] = [];
  for (let y = 0; y < n; y++) {
    const row: number[] = [];
    for (let x = 0; x < n; x++) {
      row.push(m[n - 1 - x][y]);
    }
    out.push(row);
  }
  return out;
}

const CACHE: Map<string, number[][][]> = new Map();

/** 返回 4 个旋转态，每个旋转态是一组被占用格子的 [x, y] 偏移。 */
export function rotationsOf(kind: string): number[][][] {
  const hit: number[][][] | undefined = CACHE.get(kind);
  if (hit !== undefined) {
    return hit;
  }
  let m: number[][] = baseShape(kind);
  const all: number[][][] = [];
  for (let r = 0; r < 4; r++) {
    const cells: number[][] = [];
    for (let y = 0; y < m.length; y++) {
      for (let x = 0; x < m.length; x++) {
        if (m[y][x] === 1) {
          cells.push([x, y]);
        }
      }
    }
    all.push(cells);
    m = rotateCW(m);
  }
  CACHE.set(kind, all);
  return all;
}

/** 1..7 对应七种颜色，写进棋盘后就是颜色编号。 */
export function colorIndex(kind: string): number {
  const i: number = PIECE_KINDS.indexOf(kind);
  return i < 0 ? 1 : i + 1;
}

/** 出生位置：I 和 3×3 的方块放在第 3 列，O 放在第 4 列，视觉上都居中。 */
export function spawnX(kind: string): number {
  return kind === 'O' ? 4 : 3;
}
