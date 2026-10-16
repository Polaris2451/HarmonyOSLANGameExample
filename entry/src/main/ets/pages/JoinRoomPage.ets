import { Toast } from '../utils/Toast';
import { TopBar } from '../components/TopBar';
import { AppButton } from '../components/AppButton';
import { LabeledInput } from '../components/LabeledInput';
import { RoomRoute } from '../core/RoomRoute';
import { ROUTE_ROOM } from '../core/Routes';
import { RoomSession } from '../app/RoomSession';
import { ConnStatus, ErrCode } from '../core/Protocol';
import { SettingsStore } from '../storage/SettingsStore';
import { InputCheck } from '../utils/InputCheck';

/**
 * 加入房间（横屏）：IP 与端口并排，下面填昵称。
 * 连接结果在这里先给一次反馈：成功才进房间页，失败留在本页显示原因。
 */
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
  @State connecting: boolean = false;
  @State hasError: boolean = false;
  @State errorText: ResourceStr = $r('app.string.err_connect_failed');

  aboutToAppear(): void {
    const s = SettingsStore.get();
    this.recentText = s.lastHost.length > 0 ? s.lastHost + ':' + s.lastPort.toString() : '';
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
    return $r('app.string.err_connect_failed');
  }

  private useRecent(): void {
    const s = SettingsStore.get();
    this.hostIp = s.lastHost;
    this.portText = s.lastPort.toString();
    this.ipHasError = false;
    this.portHasError = false;
  }

  private submit(): void {
    if (this.connecting) {
      return;
    }
    const name: string = this.nickname.trim();
    if (name.length === 0) {
      Toast.show(this.getUIContext(), $r('app.string.join_need_nickname'));
      return;
    }
    const host: string = this.hostIp.trim();
    if (host.length === 0) {
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
    s.lastHost = host;
    s.lastPort = port;
    SettingsStore.flush();

    this.connecting = true;
    this.hasError = false;

    const session: RoomSession = RoomSession.get();
    session.onStatus = (status: string) => {
      if (status === ConnStatus.OPEN) {
        this.connecting = false;
        this.hasError = false;
        const route: RoomRoute = new RoomRoute();
        route.nickname = name;
        route.port = port;
        route.isHost = false;
        route.hostIp = host;
        route.game = '';
        session.route = route;
        this.pathStack.pushPathByName(ROUTE_ROOM, route);
      } else if (status === ConnStatus.FAILED) {
        this.connecting = false;
        this.errorText = $r('app.string.err_connect_failed');
        this.hasError = true;
      }
    };
    session.onError = (code: string) => {
      this.connecting = false;
      this.errorText = this.errorFor(code);
      this.hasError = true;
      session.leave();
    };
    session.connectRemote(host, port, name);
  }

  build() {
    NavDestination() {
      Column() {
        TopBar({
          title: $r('app.string.join_title'),
          showBack: true,
          onBack: () => {
            RoomSession.get().leave();
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
              .layoutWeight(1)

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
              .width(200)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            Row({ space: 8 }) {
              Text('·')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_disabled'))
              Text($r('app.string.join_ip_hint'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
            }
            .width('100%')

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
                if (this.connecting) {
                  Text($r('app.string.join_connecting'))
                    .fontSize($r('app.float.font_body'))
                    .fontColor($r('app.color.brand'))
                    .padding({ top: 22 })
                } else if (this.hasError) {
                  Text(this.errorText)
                    .fontSize($r('app.float.font_body'))
                    .fontColor($r('app.color.danger'))
                    .padding({ top: 22 })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
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
            active: !this.connecting && this.nickname.trim().length > 0
              && this.hostIp.trim().length > 0 && this.portText.length > 0,
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
