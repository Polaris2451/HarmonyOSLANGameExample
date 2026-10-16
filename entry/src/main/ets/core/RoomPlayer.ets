/** 房间页里的玩家条目，只用于展示。 */
export class RoomPlayer {
  nickname: string;
  isHost: boolean;
  isSelf: boolean;

  constructor(nickname: string, isHost: boolean, isSelf: boolean) {
    this.nickname = nickname;
    this.isHost = isHost;
    this.isSelf = isSelf;
  }
}
