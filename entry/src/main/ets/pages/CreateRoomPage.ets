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
import { SettingsStore } from '../storage/SettingsStore';
import { InputCheck } from '../utils/InputCheck';

/**
 * 创建房间（横屏）：上半区选游戏，下半区分左右两栏填端口与昵称。
 * 昵称是必填项，为空时底部按钮不可点击。
 */
@Component
export struct CreateRoomPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State game: string = GameKind.GOMOKU;
  @State portText: string = SettingsStore.get().defaultPort.toString();
  @State nickname: string = SettingsStore.get().nickname;
  @State portHasError: boolean = false;
  @State portErrorText: ResourceStr = $r('app.string.error_port_required');
  private games: GameInfo[] = allGames();

  private autoFillPort(): void {
    this.portText = SettingsStore.get().defaultPort.toString();
    this.portHasError = false;
    Toast.show(this.getUIContext(), $r('app.string.create_auto_filled'));
  }

  private submit(): void {
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
    this.portHasError = false;

    SettingsStore.get().nickname = name;
    SettingsStore.flush();

    const route: RoomRoute = new RoomRoute();
    route.game = this.game;
    route.nickname = name;
    route.port = port;
    route.isHost = true;
    route.hostIp = '';
    this.pathStack.pushPathByName(ROUTE_ROOM, route);
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
            this.pathStack.pop();
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
              Column({ space: 8 }) {
                Row() {
                  Text($r('app.string.create_step_port'))
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                  Text($r('app.string.action_auto'))
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.brand'))
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor($r('app.color.brand_soft'))
                    .borderRadius($r('app.float.radius_chip'))
                    .onClick(() => {
                      this.autoFillPort();
                    })
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .alignItems(VerticalAlign.Center)

                TextInput({ text: this.portText, placeholder: $r('app.string.create_port_ph') })
                  .type(InputType.Number)
                  .maxLength(5)
                  .height($r('app.float.button_height'))
                  .width('100%')
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

                if (this.portHasError) {
                  Text(this.portErrorText)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.danger'))
                    .width('100%')
                }
              }
              .layoutWeight(1)

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

            Row({ space: 8 }) {
              Text('·')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_disabled'))
              Text($r('app.string.create_hint'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ top: 12 })
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
            active: this.nickname.trim().length > 0 && this.portText.length > 0,
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
