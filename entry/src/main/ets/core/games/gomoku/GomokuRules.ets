/** 五子棋的纯规则，不依赖 ArkUI 与网络，可以脱离设备推演。 */

export const GOMOKU_SIZE: number = 15;
export const GOMOKU_CELLS: number = GOMOKU_SIZE * GOMOKU_SIZE;

export const STONE_EMPTY: number = 0;
export const STONE_BLACK: number = 1;
export const STONE_WHITE: number = 2;

export class GomokuRules {
  static emptyBoard(): number[] {
    const cells: number[] = [];
    for (let i = 0; i < GOMOKU_CELLS; i++) {
      cells.push(STONE_EMPTY);
    }
    return cells;
  }

  static inBounds(x: number, y: number): boolean {
    return x >= 0 && x < GOMOKU_SIZE && y >= 0 && y < GOMOKU_SIZE;
  }

  static indexOf(x: number, y: number): number {
    return y * GOMOKU_SIZE + x;
  }

  static opponent(color: number): number {
    return color === STONE_BLACK ? STONE_WHITE : STONE_BLACK;
  }

  /** 以 (x, y) 为中心统计四个方向的同色连子，任意方向 >= 5 即胜。 */
  static isWinningMove(cells: number[], x: number, y: number, color: number): boolean {
    const dxs: number[] = [1, 0, 1, 1];
    const dys: number[] = [0, 1, 1, -1];
    for (let i = 0; i < dxs.length; i++) {
      let count: number = 1;
      count += GomokuRules.countDir(cells, x, y, dxs[i], dys[i], color);
      count += GomokuRules.countDir(cells, x, y, -dxs[i], -dys[i], color);
      if (count >= 5) {
        return true;
      }
    }
    return false;
  }

  private static countDir(cells: number[], x: number, y: number,
    dx: number, dy: number, color: number): number {
    let found: number = 0;
    let cx: number = x + dx;
    let cy: number = y + dy;
    while (GomokuRules.inBounds(cx, cy) && cells[GomokuRules.indexOf(cx, cy)] === color) {
      found++;
      cx += dx;
      cy += dy;
    }
    return found;
  }

  static isFull(cells: number[]): boolean {
    for (const c of cells) {
      if (c === STONE_EMPTY) {
        return false;
      }
    }
    return true;
  }
}
