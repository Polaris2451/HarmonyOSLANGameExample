import { NetInfo } from '../utils/NetInfo';
import {
  KEY_SAFE_BOTTOM, KEY_SAFE_LEFT, KEY_SAFE_RIGHT, KEY_SAFE_TOP
} from '../utils/SafeArea';
import { SettingsStore } from '../storage/SettingsStore';
import { OptionCard } from '../components/OptionCard';
import { RoomRoute } from '../core/RoomRoute';
import { ROUTE_CREATE, ROUTE_GAME, ROUTE_JOIN, ROUTE_ROOM, ROUTE_SETTINGS } from '../core/Routes';
import { SettingsPage } from './SettingsPage';
import { CreateRoomPage } from './CreateRoomPage';
import { JoinRoomPage } from './JoinRoomPage';
import { RoomPage } from './RoomPage';
import { GomokuPage } from './GomokuPage';
import { DrawGuessPage } from './DrawGuessPage';
import { GameKind } from '../core/GameKind';
import { RoomSession } from '../app/RoomSession';

/**
 * 主入口。
 * 用 Navigation + NavPathStack 做页面栈，不使用已废弃的 router。
 * 横屏布局：标题区 / 三个选项 / 底部本机信息。
 */
@Entry
@Component
struct Index {
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();
  @State localIp: string = '';
  @State defaultPort: number = 8080;
  /** 摄像头/系统栏避让，单位 vp，由 SafeArea 写入 */
  @StorageProp(KEY_SAFE_TOP) safeTop: number = 0;
  @StorageProp(KEY_SAFE_BOTTOM) safeBottom: number = 0;
  @StorageProp(KEY_SAFE_LEFT) safeLeft: number = 0;
  @StorageProp(KEY_SAFE_RIGHT) safeRight: number = 0;

  aboutToAppear(): void {
    this.refresh();
  }

  onPageShow(): void {
    this.refresh();
  }

  private refresh(): void {
    this.localIp = NetInfo.getLocalIpv4();
    this.defaultPort = SettingsStore.get().defaultPort;
  }

  @Builder
  destBuilder(name: string) {
    if (name === ROUTE_SETTINGS) {
      SettingsPage()
    } else if (name === ROUTE_CREATE) {
      CreateRoomPage()
    } else if (name === ROUTE_JOIN) {
      JoinRoomPage()
    } else if (name === ROUTE_ROOM) {
      RoomPage()
    } else if (name === ROUTE_GAME) {
      this.GameDest()
    }
  }

  /** 同一个 ROUTE_GAME 入口，按房主选的游戏分发到不同对局页。 */
  @Builder
  GameDest() {
    if (RoomSession.get().route.game === GameKind.DRAW_GUESS) {
      DrawGuessPage()
    } else {
      GomokuPage()
    }
  }

  build() {
    // 最外层统一让开摄像头与系统栏，所有页面（含 Navigation 里的各 NavDestination）都受益
    Column() {
      Navigation(this.pathStack) {
      Column() {
        Column({ space: 6 }) {
          Text($r('app.string.app_title'))
            .fontSize($r('app.float.font_display'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row({ space: 16 }) {
          Column() {
            OptionCard({
              title: $r('app.string.menu_create'),
              showDesc: false,
              glyph: '＋',
              accent: $r('app.color.brand'),
              softAccent: $r('app.color.brand_soft'),
              onTap: () => {
                this.pathStack.pushPathByName(ROUTE_CREATE, new RoomRoute());
              }
            })
          }
          .layoutWeight(1)

          Column() {
            OptionCard({
              title: $r('app.string.menu_join'),
              showDesc: false,
              glyph: '⇢',
              accent: $r('app.color.accent_gomoku'),
              softAccent: $r('app.color.accent_gomoku_soft'),
              onTap: () => {
                this.pathStack.pushPathByName(ROUTE_JOIN, new RoomRoute());
              }
            })
          }
          .layoutWeight(1)

          Column() {
            OptionCard({
              title: $r('app.string.menu_settings'),
              showDesc: false,
              glyph: '⚙',
              accent: $r('app.color.accent_tetris'),
              softAccent: $r('app.color.accent_tetris_soft'),
              onTap: () => {
                this.pathStack.pushPathByName(ROUTE_SETTINGS, new RoomRoute());
              }
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Text($r('app.string.footer_local_ip'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
          Text(this.localIp.length > 0 ? this.localIp : '—')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_primary'))
          Text('·')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_disabled'))
            .margin({ left: 8, right: 8 })
          Text($r('app.string.footer_default_port'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
          Text(this.defaultPort.toString())
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(28)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 32, right: 32, top: 20, bottom: 12 })
      .backgroundColor($r('app.color.bg_page'))
    }
      .navDestination(this.destBuilder)
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .backgroundColor($r('app.color.bg_page'))
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.safeTop,
      bottom: this.safeBottom,
      left: this.safeLeft,
      right: this.safeRight
    })
    .backgroundColor($r('app.color.bg_page'))
  }
}
