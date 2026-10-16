import { Toast } from '../utils/Toast';
import { TopBar } from '../components/TopBar';
import { AppButton } from '../components/AppButton';
import { LabeledInput } from '../components/LabeledInput';
import { OptionCard } from '../components/OptionCard';
import {
  GameInfo, GameKind, allGames, gameAccentRes, gameAccentSoftRes,
  gameNameRes, gamePlayersRes
} from '../core/GameKind';
import { RoomRoute } from '../core/RoomRoute';
import { ROUTE_ROOM } from '../core/Routes';
import { RoomSession } from '../app/RoomSession';
import { StartResult } from '../net/RoomServer';
import { SettingsStore } from '../storage/SettingsStore';
import { InputCheck } from '../utils/InputCheck';

const AUTO_PICK_TRIES: number = 10;

/**
 * 创建房间（横屏）：选游戏、选端口、填昵称。
 * 「创建房间」会真的把 WebSocket 服务器起来，端口被占用会当场报错；
 * 服务器实例交给 RoomSession，由房间页接管。
 */
@Component
export struct CreateRoomPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State game: string = GameKind.GOMOKU;
  @State portText: string = SettingsStore.get().defaultPort.toString();
  @State nickname: string = SettingsStore.get().nickname;
  @State portHasError: boolean = false;
  @State portErrorText: ResourceStr = $r('app.string.error_port_required');
  @State busy: boolean = false;
  private games: GameInfo[] = allGames();

  private portErrorFor(code: string): Resource {
    if (code === 'busy') {
      return $r('app.string.err_port_busy');
    }
    if (code === 'nic') {
      return $r('app.string.err_port_nic');
    }
    if (code === 'permission') {
      return $r('app.string.err_port_permission');
    }
    return $r('app.string.err_port_unknown');
  }

  /** 自动选择：从默认端口往后逐个真的去 listen，第一个成功的即保留。 */
  private async autoPickPort(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.portHasError = false;
    const start: number = SettingsStore.get().defaultPort;
    const name: string = this.nickname.trim().length > 0 ? this.nickname.trim() : '房主';
    for (let p = start; p < start + AUTO_PICK_TRIES; p++) {
      const result: StartResult = await RoomSession.get().startServer(p, this.game, name);
      if (result.ok) {
        this.portText = p.toString();
        this.busy = false;
        Toast.show(this.getUIContext(), $r('app.string.auto_pick_ok'));
        return;
      }
      if (result.errorCode !== 'busy') {
        this.portErrorText = this.portErrorFor(result.errorCode);
        this.portHasError = true;
        this.busy = false;
        return;
      }
    }
    this.portErrorText = $r('app.string.auto_pick_none');
    this.portHasError = true;
    this.busy = false;
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    const name: string = this.nickname.trim();
    if (name.length === 0) {
      Toast.show(this.getUIContext(), $r('app.string.create_need_nickname'));
      return;
    }
    if (this.portText.length === 0) {
      this.portErrorText = $r('app.string.error_port_required');
      this.portHasError = true;
      return;
    }
    const port: number = InputCheck.parsePort(this.portText);
    if (port <= 0) {
      this.portErrorText = $r('app.string.error_port_range');
      this.portHasError = true;
      return;
    }

    this.busy = true;
    const existing = RoomSession.get().server;
    let ok: boolean = false;
    let errorCode: string = '';
    if (existing !== undefined && existing.running && existing.port === port
      && existing.game === this.game) {
      // 自动选择已经把这个端口起好了，直接复用
      ok = true;
    } else {
      const result: StartResult = await RoomSession.get().startServer(port, this.game, name);
      ok = result.ok;
      errorCode = result.errorCode;
    }
    this.busy = false;

    if (!ok) {
      this.portErrorText = this.portErrorFor(errorCode);
      this.portHasError = true;
      return;
    }
    this.portHasError = false;

    SettingsStore.get().nickname = name;
    SettingsStore.flush();

    const route: RoomRoute = new RoomRoute();
    route.game = this.game;
    route.nickname = name;
    route.port = port;
    route.isHost = true;
    route.hostIp = '';
    RoomSession.get().route = route;
    this.pathStack.pushPathByName(ROUTE_ROOM, route);
  }

  private abandon(): void {
    // 返回时如果已经起过服务器，要关掉，避免端口一直被占
    RoomSession.get().leave();
    this.pathStack.pop();
  }

  @Builder
  SectionLabel(title: ResourceStr) {
    Text(title)
      .fontSize($r('app.float.font_caption'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ top: 8, bottom: 8 })
  }

  build() {
    NavDestination() {
      Column() {
        TopBar({
          title: $r('app.string.create_title'),
          showBack: true,
          onBack: () => {
            this.abandon();
          }
        })

        Scroll() {
          Column() {
            this.SectionLabel($r('app.string.create_step_game'))
            Row({ space: 12 }) {
              ForEach(this.games, (item: GameInfo) => {
                Column() {
                  OptionCard({
                    title: gameNameRes(item.kind),
                    desc: gamePlayersRes(item.kind),
                    showGlyph: false,
                    cardHeight: 84,
                    accent: gameAccentRes(item.kind),
                    softAccent: gameAccentSoftRes(item.kind),
                    selected: this.game === item.kind,
                    showSelection: true,
                    onTap: () => {
                      this.game = item.kind;
                    }
                  })
                }
                .layoutWeight(1)
              }, (item: GameInfo) => item.kind)
            }
            .width('100%')

            Row({ space: 16 }) {
              // 标签行只放标签，「自动选择」挪到输入框右侧。
              // 两列首行因此等高（都是 caption 文字 + 8 间距 + 48 高输入框），
              // 昵称输入框才会和端口输入框严格对齐。
              Column({ space: 8 }) {
                Text($r('app.string.create_step_port'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')

                Row({ space: 10 }) {
                  TextInput({ text: this.portText, placeholder: $r('app.string.create_port_ph') })
                    .type(InputType.Number)
                    .maxLength(5)
                    .height($r('app.float.button_height'))
                    .width(140)
                    .fontSize($r('app.float.font_body'))
                    .fontColor($r('app.color.text_primary'))
                    .placeholderColor($r('app.color.text_disabled'))
                    .backgroundColor($r('app.color.bg_sunken'))
                    .borderRadius($r('app.float.radius_input'))
                    .padding({ left: 12, right: 12 })
                    .borderWidth(this.portHasError ? 1 : 0)
                    .borderColor($r('app.color.danger'))
                    .onChange((value: string) => {
                      this.portText = value;
                      this.portHasError = false;
                    })

                  Text($r('app.string.action_auto'))
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.brand'))
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor($r('app.color.brand_soft'))
                    .borderRadius($r('app.float.radius_chip'))
                    .onClick(() => {
                      this.autoPickPort();
                    })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                if (this.portHasError) {
                  Text(this.portErrorText)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.danger'))
                    .width('100%')
                }
              }
              .width(280)

              Column() {
                LabeledInput({
                  label: $r('app.string.create_step_nickname'),
                  placeholder: $r('app.string.settings_nickname_ph'),
                  text: this.nickname,
                  maxLength: 16,
                  onTextChange: (value: string) => {
                    this.nickname = value;
                  }
                })
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .padding({ top: 14 })

          }
          .width('100%')
          .padding({ left: 32, right: 32, bottom: 16 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.Top)

        Row() {
          AppButton({
            label: $r('app.string.create_submit'),
            primary: true,
            active: !this.busy && this.nickname.trim().length > 0 && this.portText.length > 0,
            onTap: () => {
              this.submit();
            }
          })
        }
        .width('100%')
        .padding({ left: 32, right: 32, top: 4, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
    }
    .hideTitleBar(true)
  }
}
