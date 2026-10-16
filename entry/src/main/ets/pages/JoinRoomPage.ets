import { Toast } from '../utils/Toast';
import { TopBar } from '../components/TopBar';
import { AppButton } from '../components/AppButton';
import { LabeledInput } from '../components/LabeledInput';
import { RoomRoute } from '../core/RoomRoute';
import { ROUTE_ROOM } from '../core/Routes';
import { SettingsStore } from '../storage/SettingsStore';
import { InputCheck } from '../utils/InputCheck';

/** 加入房间（横屏）：IP 与端口并排，下面填昵称。 */
@Component
export struct JoinRoomPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State hostIp: string = SettingsStore.get().lastHost;
  @State portText: string = SettingsStore.get().lastPort.toString();
  @State nickname: string = SettingsStore.get().nickname;
  @State ipHasError: boolean = false;
  @State portHasError: boolean = false;
  @State portErrorText: ResourceStr = $r('app.string.error_port_required');
  @State recentText: string = '';

  aboutToAppear(): void {
    const s = SettingsStore.get();
    this.recentText = s.lastHost.length > 0 ? s.lastHost + ':' + s.lastPort.toString() : '';
  }

  private useRecent(): void {
    const s = SettingsStore.get();
    this.hostIp = s.lastHost;
    this.portText = s.lastPort.toString();
    this.ipHasError = false;
    this.portHasError = false;
  }

  private submit(): void {
    const name: string = this.nickname.trim();
    if (name.length === 0) {
      Toast.show(this.getUIContext(), $r('app.string.join_need_nickname'));
      return;
    }
    if (this.hostIp.trim().length === 0) {
      this.ipHasError = true;
      return;
    }
    this.ipHasError = false;
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

    const s = SettingsStore.get();
    s.nickname = name;
    s.lastHost = this.hostIp.trim();
    s.lastPort = port;
    SettingsStore.flush();

    const route: RoomRoute = new RoomRoute();
    route.nickname = name;
    route.port = port;
    route.isHost = false;
    route.hostIp = this.hostIp.trim();
    route.game = '';
    this.pathStack.pushPathByName(ROUTE_ROOM, route);
  }

  build() {
    NavDestination() {
      Column() {
        TopBar({
          title: $r('app.string.join_title'),
          showBack: true,
          onBack: () => {
            this.pathStack.pop();
          }
        })

        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 16 }) {
              Column() {
                LabeledInput({
                  label: $r('app.string.join_host_ip'),
                  placeholder: $r('app.string.join_host_ip_ph'),
                  text: this.hostIp,
                  maxLength: 64,
                  hasError: this.ipHasError,
                  errorText: $r('app.string.error_ip_required'),
                  onTextChange: (value: string) => {
                    this.hostIp = value;
                    this.ipHasError = false;
                  }
                })
              }
              .layoutWeight(2)

              Column() {
                LabeledInput({
                  label: $r('app.string.join_port'),
                  placeholder: $r('app.string.create_port_ph'),
                  text: this.portText,
                  inputKind: InputType.Number,
                  maxLength: 5,
                  hasError: this.portHasError,
                  errorText: this.portErrorText,
                  onTextChange: (value: string) => {
                    this.portText = value;
                    this.portHasError = false;
                  }
                })
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            if (this.recentText.length > 0) {
              Row({ space: 8 }) {
                Text($r('app.string.join_recent'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_secondary'))
                Text(this.recentText)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.brand'))
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor($r('app.color.brand_soft'))
                  .borderRadius($r('app.float.radius_chip'))
                  .onClick(() => {
                    this.useRecent();
                  })
              }
              .width('100%')
            }

            Row({ space: 16 }) {
              Column() {
                LabeledInput({
                  label: $r('app.string.join_nickname'),
                  placeholder: $r('app.string.settings_nickname_ph'),
                  text: this.nickname,
                  maxLength: 16,
                  onTextChange: (value: string) => {
                    this.nickname = value;
                  }
                })
              }
              .layoutWeight(1)

              Column() {
                Row({ space: 8 }) {
                  Text('·')
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_disabled'))
                  Text($r('app.string.join_hint'))
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 22 })
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          .width('100%')
          .padding({ left: 32, right: 32, bottom: 16 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.Top)

        Row() {
          AppButton({
            label: $r('app.string.join_submit'),
            primary: true,
            active: this.nickname.trim().length > 0 && this.hostIp.trim().length > 0
              && this.portText.length > 0,
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
