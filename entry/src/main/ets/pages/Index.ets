import { NetInfo } from '../utils/NetInfo';
import { SettingsStore } from '../storage/SettingsStore';
import { OptionCard } from '../components/OptionCard';
import { RoomRoute } from '../core/RoomRoute';
import { ROUTE_CREATE, ROUTE_JOIN, ROUTE_ROOM, ROUTE_SETTINGS } from '../core/Routes';
import { SettingsPage } from './SettingsPage';
import { CreateRoomPage } from './CreateRoomPage';
import { JoinRoomPage } from './JoinRoomPage';
import { RoomPage } from './RoomPage';

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
    }
  }

  build() {
    Navigation(this.pathStack) {
      Column() {
        Column({ space: 6 }) {
          Text($r('app.string.app_title'))
            .fontSize($r('app.float.font_display'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.app_subtitle'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row({ space: 16 }) {
          Column() {
            OptionCard({
              title: $r('app.string.menu_create'),
              desc: $r('app.string.menu_create_desc'),
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
              desc: $r('app.string.menu_join_desc'),
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
              desc: $r('app.string.menu_settings_desc'),
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
  }
}
