import { GameKind } from './GameKind';
import { DEFAULT_PORT } from './Routes';

/** 从主入口跳到房间页时携带的参数。 */
export class RoomRoute {
  game: string = GameKind.GOMOKU;
  nickname: string = '';
  port: number = DEFAULT_PORT;
  isHost: boolean = true;
  hostIp: string = '';
}
