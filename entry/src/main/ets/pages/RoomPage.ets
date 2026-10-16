import { Toast } from '../utils/Toast';
import { Confirm } from '../utils/Confirm';
import { TopBar } from '../components/TopBar';
import { AppButton } from '../components/AppButton';
import { RoomPlayer } from '../core/RoomPlayer';
import { RoomRoute } from '../core/RoomRoute';
import { ROUTE_GAME } from '../core/Routes';
import { gameAccentRes, gameAccentSoftRes, gameMaxPlayers, gameNameRes } from '../core/GameKind';
import { Clipboard } from '../utils/Clipboard';
import { NetInfo } from '../utils/NetInfo';
import { RoomSession } from '../app/RoomSession';
import { ConnStatus, ErrCode, RosterEntry } from '../core/Protocol';

/**
 * 房间页外壳，三种游戏共用。
 * 布局：左侧是游戏区（空间大，放标题与地址信息），右侧窄栏只放状态、玩家列表和按钮。
 * 这样在 vp 高度很小的横屏设备上，玩家列表也能保证显示完整。
 */
@Component
export struct RoomPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State route: RoomRoute = new RoomRoute();
  @State players: RoomPlayer[] = [];
  @State maxPlayers: number = 2;
  @State status: string = ConnStatus.CONNECTING;
  @State hasError: boolean = false;
  @State errorText: ResourceStr = $r('app.string.err_connect_failed');
  @State selfId: string = '';
  @State canStart: boolean = false;
  @State game: string = '';
  private navigatedToGame: boolean = false;

  aboutToAppear(): void {
    const session: RoomSession = RoomSession.get();
    this.route = session.route;
    this.selfId = session.selfId;
    session.onRoster = (entries: RosterEntry[], maxPlayers: number) => {
      this.applyRoster(entries, maxPlayers);
    };
    session.onStatus = (status: string) => {
      this.status = status;
      if (status === ConnStatus.OPEN) {
        this.hasError = false;
      }
      this.refreshCanStart();
    };
    session.onError = (code: string) => {
      this.hasError = true;
      this.errorText = this.errorFor(code);
    };
    session.onStarted = () => {
      // 房主和加入方都会收到 START，收到就跳到对局页；守卫避免重复入栈
      if (this.navigatedToGame) {
        return;
      }
      this.navigatedToGame = true;
      this.pathStack.pushPathByName(ROUTE_GAME, this.route);
    };
    // 关键：加入方可能在收到 roster 之后才创建本页，这里必须补齐已有状态
    this.syncFromSession();
    if (this.route.isHost) {
      session.connectLocal();
    }
  }

  /** 把会话里已经发生过的状态搬进本页的 @State。 */
  private syncFromSession(): void {
    const s: RoomSession = RoomSession.get();
    this.route = s.route;
    this.game = s.route.game;
    this.status = s.status;
    this.selfId = s.selfId;
    this.maxPlayers = s.maxPlayers;
    if (s.players.length > 0) {
      this.applyRoster(s.players, s.maxPlayers);
    } else {
      this.refreshCanStart();
    }
  }

  private errorFor(code: string): Resource {
    if (code === ErrCode.ROOM_FULL) {
      return $r('app.string.err_room_full');
    }
    if (code === ErrCode.BAD_VERSION) {
      return $r('app.string.err_bad_version');
    }
    if (code === ErrCode.BAD_PROTOCOL) {
      return $r('app.string.err_protocol');
    }
    if (code === ErrCode.ALREADY_STARTED) {
      return $r('app.string.err_need_two_players');
    }
    return $r('app.string.err_connect_failed');
  }

  private applyRoster(entries: RosterEntry[], maxPlayers: number): void {
    this.selfId = RoomSession.get().selfId;
    this.game = RoomSession.get().route.game;
    const list: RoomPlayer[] = [];
    for (const entry of entries) {
      list.push(new RoomPlayer(entry.nickname, entry.isHost, entry.id === this.selfId));
    }
    this.players = list;
    this.maxPlayers = maxPlayers;
    this.refreshCanStart();
  }

  private refreshCanStart(): void {
    this.canStart = this.route.isHost && this.status === ConnStatus.OPEN && this.players.length >= 2;
  }

  private titleRes(): Resource {
    if (this.game.length === 0) {
      return $r('app.string.room_title');
    }
    return gameNameRes(this.game);
  }

  private accent(): Resource {
    if (this.game.length === 0) {
      return $r('app.color.brand');
    }
    return gameAccentRes(this.game);
  }

  private accentSoft(): Resource {
    if (this.game.length === 0) {
      return $r('app.color.brand_soft');
    }
    return gameAccentSoftRes(this.game);
  }

  private maxOfGame(): number {
    if (this.game.length === 0) {
      return this.maxPlayers;
    }
    return gameMaxPlayers(this.game);
  }

  private localAddr(): string {
    const ip: string = NetInfo.getLocalIpv4();
    return ip.length > 0 ? ip + ':' + this.route.port.toString() : '';
  }

  private shareAddr(): string {
    return NetInfo.shareAddress(this.route.port);
  }

  private guestAddr(): string {
    return this.route.hostIp + ':' + this.route.port.toString();
  }

  private statusText(): Resource {
    if (this.status === ConnStatus.OPEN) {
      return $r('app.string.status_online');
    }
    if (this.status === ConnStatus.RECONNECTING) {
      return $r('app.string.status_reconnecting');
    }
    if (this.status === ConnStatus.FAILED) {
      return $r('app.string.status_failed');
    }
    if (this.status === ConnStatus.CLOSED) {
      return $r('app.string.status_closed');
    }
    return $r('app.string.status_connecting');
  }

  private statusColor(): Resource {
    if (this.status === ConnStatus.OPEN) {
      return $r('app.color.success');
    }
    if (this.status === ConnStatus.FAILED || this.status === ConnStatus.CLOSED) {
      return $r('app.color.danger');
    }
    return $r('app.color.warning');
  }

  private copyAddress(): void {
    const addr: string = this.route.isHost ? this.shareAddr() : this.guestAddr();
    if (addr.length === 0) {
      return;
    }
    Clipboard.copyText(addr).then((ok: boolean) => {
      if (ok) {
        Toast.show(this.getUIContext(), $r('app.string.copied'));
      }
    });
  }

  private async leave(): Promise<void> {
    const ok: boolean = await Confirm.ask(this.getUIContext(),
      $r('app.string.leave_title'), $r('app.string.leave_msg'), $r('app.string.leave_ok'));
    if (!ok) {
      return;
    }
    await RoomSession.get().leave();
    this.pathStack.pop();
  }

  @Builder
  GameArea() {
    Column({ space: 6 }) {
      Text(this.titleRes())
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.room_placeholder'))
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
      Text($r('app.string.room_offline_hint'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_disabled'))

      Column({ space: 4 }) {
        if (this.route.isHost) {
          Text($r('app.string.room_share_title'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
          Text(this.shareAddr())
            .fontSize($r('app.float.font_subtitle'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          if (NetInfo.isEmulatorLike()) {
            Text($r('app.string.room_share_device'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.warning'))
            Row({ space: 6 }) {
              Text($r('app.string.room_local_internal'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_disabled'))
              Text(this.localAddr())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_disabled'))
            }
          }
        } else {
          Text($r('app.string.room_host_addr'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
          Text(this.guestAddr())
            .fontSize($r('app.float.font_subtitle'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
      }
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 10 })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.accentSoft())
    .borderRadius($r('app.float.radius_panel'))
  }

  @Builder
  PlayerRow(p: RoomPlayer) {
    Row({ space: 8 }) {
      Text('●')
        .fontSize(10)
        .fontColor(p.isHost ? this.accent() : $r('app.color.text_disabled'))
      Text(p.nickname)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (p.isHost) {
        Text($r('app.string.room_host_tag'))
          .fontSize($r('app.float.font_caption'))
          .fontColor(this.accent())
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(this.accentSoft())
          .borderRadius($r('app.float.radius_chip'))
      }
      if (p.isSelf) {
        Text($r('app.string.room_you_tag'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor($r('app.color.bg_sunken'))
          .borderRadius($r('app.float.radius_chip'))
      }
    }
    .width('100%')
    .height(30)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        TopBar({
          title: this.titleRes(),
          showBack: true,
          rightText: $r('app.string.action_copy'),
          showRight: true,
          onBack: () => {
            this.leave();
          },
          onRight: () => {
            this.copyAddress();
          }
        })

        Row({ space: 16 }) {
          this.GameArea()

          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Text('●')
                .fontSize(10)
                .fontColor(this.statusColor())
              Text(this.statusText())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Row() {
              Text($r('app.string.room_players'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.text_primary'))
              Text(this.players.length.toString() + ' / ' + this.maxOfGame().toString())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Divider().color($r('app.color.border_subtle'))

            Scroll() {
              Column({ space: 6 }) {
                ForEach(this.players, (p: RoomPlayer) => {
                  this.PlayerRow(p)
                }, (p: RoomPlayer) => p.nickname + (p.isSelf ? '-self' : '-other'))
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .layoutWeight(1)
            .align(Alignment.Top)

            if (this.hasError) {
              Text(this.errorText)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.danger'))
                .width('100%')
            } else if (!this.canStart) {
              Text(this.route.isHost ? $r('app.string.room_need_players')
                : $r('app.string.room_waiting'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }

            Row({ space: 12 }) {
              Column() {
                AppButton({
                  label: $r('app.string.room_start'),
                  primary: true,
                  active: this.canStart,
                  onTap: () => {
                    RoomSession.get().requestStart();
                  }
                })
              }
              .layoutWeight(1)

              Column() {
                AppButton({
                  label: $r('app.string.room_leave'),
                  primary: false,
                  active: true,
                  onTap: () => {
                    this.leave();
                  }
                })
              }
              .layoutWeight(1)
            }
            .width('100%')
          }
          .width($r('app.float.sidebar_width'))
          .height('100%')
          .padding($r('app.float.card_padding'))
          .alignItems(HorizontalAlign.Start)
          .backgroundColor($r('app.color.bg_surface'))
          .borderRadius($r('app.float.radius_card'))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
    }
    .hideTitleBar(true)
    .onShown(() => {
      // 从对局页返回后要允许「再来一局」再次跳转
      this.navigatedToGame = false;
    })
    .onReady((ctx: NavDestinationContext) => {
      const route: RoomRoute = ctx.pathInfo.param as RoomRoute;
      if (route !== undefined && route.port > 0) {
        this.route = route;
        RoomSession.get().route = route;
      }
    })
  }
}
