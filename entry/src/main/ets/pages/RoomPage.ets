import { Toast } from '../utils/Toast';
import { TopBar } from '../components/TopBar';
import { AppButton } from '../components/AppButton';
import { RoomPlayer } from '../core/RoomPlayer';
import { RoomRoute } from '../core/RoomRoute';
import { gameAccentRes, gameAccentSoftRes, gameMaxPlayers, gameNameRes } from '../core/GameKind';
import { Clipboard } from '../utils/Clipboard';
import { NetInfo } from '../utils/NetInfo';

/**
 * 房间页外壳，三种游戏共用。
 * 左：游戏区域；右：侧栏（地址 + 玩家列表 + 操作）。
 * 侧栏只有玩家列表滚动，地址与按钮固定，避免人多时布局错位。
 * 本步只做界面：玩家列表暂时只有自己，真正同步在下一步接服务器后替换。
 */
@Component
export struct RoomPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State route: RoomRoute = new RoomRoute();
  @State players: RoomPlayer[] = [];
  @State roomIp: string = '';

  private applyRoute(route: RoomRoute): void {
    this.route = route;
    const ip: string = route.isHost ? NetInfo.getLocalIpv4() : route.hostIp;
    this.roomIp = ip.length > 0 ? ip : route.hostIp;
    const list: RoomPlayer[] = [];
    list.push(new RoomPlayer(route.nickname, route.isHost, true));
    this.players = list;
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

  private maxPlayers(): number {
    if (this.route.game.length === 0) {
      return 8;
    }
    return gameMaxPlayers(this.route.game);
  }

  private canStart(): boolean {
    return this.route.isHost && this.players.length >= 2;
  }

  private startReason(): Resource {
    if (this.players.length < 2) {
      return $r('app.string.room_need_players');
    }
    return $r('app.string.room_waiting');
  }

  private copyAddress(): void {
    const addr: string = this.roomIp + ':' + this.route.port.toString();
    Clipboard.copyText(addr).then((ok: boolean) => {
      if (ok) {
        Toast.show(this.getUIContext(), $r('app.string.copied'));
      }
    });
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
            this.pathStack.pop();
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
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(this.accentSoft())
          .borderRadius($r('app.float.radius_panel'))

          Column({ space: 8 }) {
            Column({ space: 4 }) {
              Text($r('app.string.room_address'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
              Text(this.roomIp + ':' + this.route.port.toString())
                .fontSize($r('app.float.font_subtitle'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Divider().color($r('app.color.border_subtle'))

            Row() {
              Text($r('app.string.room_players'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.text_primary'))
              Text(this.players.length.toString() + ' / ' + this.maxPlayers().toString())
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

            if (!this.canStart()) {
              Text(this.startReason())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }

            Row({ space: 12 }) {
              Column() {
                AppButton({
                  label: $r('app.string.room_start'),
                  primary: true,
                  active: this.canStart(),
                  onTap: () => {
                    Toast.show(this.getUIContext(), $r('app.string.room_not_yet'));
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
                    this.pathStack.pop();
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
      this.applyRoute(route);
    })
  }
}
