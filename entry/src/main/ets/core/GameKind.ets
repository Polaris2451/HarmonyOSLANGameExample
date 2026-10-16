/**
 * 三种游戏的标识与元信息。
 * 只放纯数据与取资源的函数，不依赖任何网络或 UI 组件。
 */

export class GameKind {
  static readonly GOMOKU: string = 'gomoku';
  static readonly DRAW_GUESS: string = 'drawguess';
  static readonly TETRIS: string = 'tetris';
}

/** 一种游戏的人数约束。 */
export class GameInfo {
  kind: string;
  minPlayers: number;
  maxPlayers: number;

  constructor(kind: string, minPlayers: number, maxPlayers: number) {
    this.kind = kind;
    this.minPlayers = minPlayers;
    this.maxPlayers = maxPlayers;
  }
}

/** 主入口与创建房间页用到的游戏清单。 */
export function allGames(): GameInfo[] {
  return [
    new GameInfo(GameKind.GOMOKU, 2, 2),
    new GameInfo(GameKind.DRAW_GUESS, 2, 8),
    new GameInfo(GameKind.TETRIS, 2, 2)
  ];
}

export function gameInfoOf(kind: string): GameInfo {
  const list: GameInfo[] = allGames();
  for (const g of list) {
    if (g.kind === kind) {
      return g;
    }
  }
  return new GameInfo(GameKind.GOMOKU, 2, 2);
}

export function gameMaxPlayers(kind: string): number {
  return gameInfoOf(kind).maxPlayers;
}

export function gameNameRes(kind: string): Resource {
  if (kind === GameKind.DRAW_GUESS) {
    return $r('app.string.game_drawguess');
  }
  if (kind === GameKind.TETRIS) {
    return $r('app.string.game_tetris');
  }
  return $r('app.string.game_gomoku');
}

export function gamePlayersRes(kind: string): Resource {
  if (kind === GameKind.DRAW_GUESS) {
    return $r('app.string.game_drawguess_players');
  }
  if (kind === GameKind.TETRIS) {
    return $r('app.string.game_tetris_players');
  }
  return $r('app.string.game_gomoku_players');
}

/** 每种游戏一个主色，用于房间页与后续游戏界面的视觉锚点。 */
export function gameAccentRes(kind: string): Resource {
  if (kind === GameKind.DRAW_GUESS) {
    return $r('app.color.accent_drawguess');
  }
  if (kind === GameKind.TETRIS) {
    return $r('app.color.accent_tetris');
  }
  return $r('app.color.accent_gomoku');
}

export function gameAccentSoftRes(kind: string): Resource {
  if (kind === GameKind.DRAW_GUESS) {
    return $r('app.color.accent_drawguess_soft');
  }
  if (kind === GameKind.TETRIS) {
    return $r('app.color.accent_tetris_soft');
  }
  return $r('app.color.accent_gomoku_soft');
}

/** 卡片上的简单图形符号，先用字符实现，后续可换矢量图。 */
export function gameGlyph(kind: string): string {
  if (kind === GameKind.DRAW_GUESS) {
    return '✎';
  }
  if (kind === GameKind.TETRIS) {
    return '▤';
  }
  return '⚫';
}
