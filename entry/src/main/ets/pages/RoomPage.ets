import { Toast } from '../utils/Toast';
import { TopBar } from '../components/TopBar';
import { AppButton } from '../components/AppButton';
import { RoomPlayer } from '../core/RoomPlayer';
import { RoomRoute } from '../core/RoomRoute';
import { gameAccentRes, gameAccentSoftRes, gameMaxPlayers, gameNameRes } from '../core/GameKind';
import { Clipboard } from '../utils/Clipboard';
import { NetInfo } from '../utils/NetInfo';
import { RoomSession } from '../app/RoomSession';
import { ConnStatus, ErrCode, RosterEntry } from '../core/Protocol';

/**
 * 房间页外壳，三种游戏共用。
 * 成员列表来自房主服务器的实时广播；
 * 房主自己的客户端连的是 127.0.0.1，与加入方共用同一套客户端代码。
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
      Toast.show(this.getUIContext(), $r('app.string.room_game_started'));
    };
    if (this.route.isHost) {
      session.connectLocal();
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
    if (this.route.game.length === 0) {
      return $r('app.string.room_title');
    }
    return gameNameRes(this.route.game);
  }

  private accent(): Resource {
    if (this.route.game.length === 0) {
      return $r('app.color.brand');
    }
    return gameAccentRes(this.route.game);
  }

  private accentSoft(): Resource {
    if (this.route.game.length === 0) {
      return $r('app.color.brand_soft');
    }
    return gameAccentSoftRes(this.route.game);
  }

  private maxOfGame(): number {
    if (this.route.game.length === 0) {
      return this.maxPlayers;
    }
    return gameMaxPlayers(this.route.game);
  }

  private localAddr(): string {
    const ip: string = NetInfo.getLocalIpv4();
    return ip.length > 0 ? ip + ':' + this.route.port.toString() : '';
  }

  /** 房主展示给同学的地址：模拟器用 10.0.2.2，真机用本机局域网 IP。 */
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
    await RoomSession.get().leave();
    this.pathStack.pop();
  }

  @Builder
  AddressBlock() {
    Column({ space: 4 }) {
      if (this.route.isHost) {
        Text($r('app.string.room_share_title'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Text(this.shareAddr())
          .fontSize($r('app.float.font_subtitle'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

      } else {
        Text($r('app.string.room_host_addr'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Text(this.guestAddr())
          .fontSize($r('app.float.font_subtitle'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
    .height(32)
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
          Column({ space: 10 }) {
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
            if (this.route.isHost && NetInfo.isEmulatorLike()) {
              // 模拟器里 10.0.2.x 是内部地址，别人连不上，必须说清楚
              Text($r('app.string.room_share_device'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.warning'))
                .padding({ top: 10 })
              Row({ space: 6 }) {
                Text($r('app.string.room_local_internal'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_disabled'))
                Text(this.localAddr())
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_disabled'))
              }
              .alignItems(VerticalAlign.Center)
            }
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(this.accentSoft())
          .borderRadius($r('app.float.radius_panel'))

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

            this.AddressBlock()

            Divider().color($r('app.color.border_subtle'))

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

            Scroll() {
              Column({ space: 8 }) {
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
    .onReady((ctx: NavDestinationContext) => {
      const route: RoomRoute = ctx.pathInfo.param as RoomRoute;
      if (route !== undefined && route.port > 0) {
        this.route = route;
        RoomSession.get().route = route;
      }
    })
  }
}
