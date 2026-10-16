import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { TopBar } from '../components/TopBar';
import { AppButton } from '../components/AppButton';
import { SettingsRow } from '../components/SettingsRow';
import { Toast } from '../utils/Toast';
import { AppSettings, SettingsStore, THEME_DARK, THEME_LIGHT, THEME_SYSTEM } from '../storage/SettingsStore';
import { InputCheck } from '../utils/InputCheck';
import { DEFAULT_PORT, PROTOCOL_VERSION } from '../core/Routes';

const DOMAIN: number = 0x0000;
const TAG: string = 'SettingsPage';

/**
 * 设置页（横屏两栏）：
 * 左栏 = 个人 + 网络，右栏 = 外观 + 关于。
 * 改动先落在内存，点保存才写盘。
 */
@Component
export struct SettingsPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State nickname: string = SettingsStore.get().nickname;
  @State portText: string = SettingsStore.get().defaultPort.toString();
  @State timeoutText: string = SettingsStore.get().connectTimeoutSec.toString();
  @State themeMode: string = SettingsStore.get().themeMode;
  @State motion: boolean = SettingsStore.get().motion;

  private applyTheme(mode: string): void {
    try {
      const ctx: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      if (mode === THEME_DARK) {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      } else if (mode === THEME_SYSTEM) {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      }
      ctx.getApplicationContext().setColorMode(colorMode);
    } catch (err) {
      const be = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'applyTheme failed: %{public}d %{public}s', be.code, be.message);
    }
  }

  private save(): void {
    const s: AppSettings = SettingsStore.get();
    s.nickname = this.nickname.trim();
    const port: number = InputCheck.parsePort(this.portText);
    s.defaultPort = port > 0 ? port : DEFAULT_PORT;
    const timeout: number = Number.parseInt(this.timeoutText, 10);
    s.connectTimeoutSec = Number.isNaN(timeout) ? 8 : timeout;
    s.themeMode = this.themeMode;
    s.motion = this.motion;
    SettingsStore.flush();
    Toast.show(this.getUIContext(), $r('app.string.saved'));
    this.pathStack.pop();
  }

  @Builder
  GroupTitle(title: ResourceStr) {
    Text(title)
      .fontSize($r('app.float.font_caption'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 4, top: 6, bottom: 6 })
  }

  @Builder
  ThemeChip(label: ResourceStr, value: string) {
    Text(label)
      .fontSize($r('app.float.font_caption'))
      .fontColor(this.themeMode === value ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
      .backgroundColor(this.themeMode === value ? $r('app.color.brand') : $r('app.color.bg_sunken'))
      .borderRadius($r('app.float.radius_chip'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .onClick(() => {
        this.themeMode = value;
        this.applyTheme(value);
      })
  }

  @Builder
  CardShell() {
  }

  @Builder
  ProfileCard() {
    Column() {
      SettingsRow({
        label: $r('app.string.settings_nickname'),
      }) {
        TextInput({ text: this.nickname, placeholder: $r('app.string.settings_nickname_ph') })
          .maxLength(16)
          .width(220)
          .height(40)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_disabled'))
          .backgroundColor($r('app.color.bg_sunken'))
          .borderRadius($r('app.float.radius_input'))
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.nickname = value;
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.bg_surface'))
    .borderRadius($r('app.float.radius_card'))
  }

  @Builder
  NetworkCard() {
    Column() {
      SettingsRow({
        label: $r('app.string.settings_default_port'),
      }) {
        TextInput({ text: this.portText })
          .type(InputType.Number)
          .maxLength(5)
          .width(120)
          .height(40)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.bg_sunken'))
          .borderRadius($r('app.float.radius_input'))
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.portText = value;
          })
      }
      Divider().color($r('app.color.border_subtle'))
      SettingsRow({
        label: $r('app.string.settings_timeout'),
      }) {
        TextInput({ text: this.timeoutText })
          .type(InputType.Number)
          .maxLength(2)
          .width(120)
          .height(40)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.bg_sunken'))
          .borderRadius($r('app.float.radius_input'))
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.timeoutText = value;
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.bg_surface'))
    .borderRadius($r('app.float.radius_card'))
  }

  @Builder
  AppearanceCard() {
    Column() {
      SettingsRow({ label: $r('app.string.settings_theme'), showHint: false }) {
        Row({ space: 8 }) {
          this.ThemeChip($r('app.string.theme_light'), THEME_LIGHT)
          this.ThemeChip($r('app.string.theme_dark'), THEME_DARK)
          this.ThemeChip($r('app.string.theme_system'), THEME_SYSTEM)
        }
      }
      Divider().color($r('app.color.border_subtle'))
      SettingsRow({
        label: $r('app.string.settings_motion'),
      }) {
        Toggle({ type: ToggleType.Switch, isOn: this.motion })
          .selectedColor($r('app.color.brand'))
          .onChange((isOn: boolean) => {
            this.motion = isOn;
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.bg_surface'))
    .borderRadius($r('app.float.radius_card'))
  }

  @Builder
  AboutCard() {
    Column() {
      SettingsRow({ label: $r('app.string.settings_version'), showHint: false }) {
        Text('1.0.0')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_secondary'))
      }
      Divider().color($r('app.color.border_subtle'))
      SettingsRow({ label: $r('app.string.settings_protocol'), showHint: false }) {
        Text(PROTOCOL_VERSION.toString())
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_secondary'))
      }
      Divider().color($r('app.color.border_subtle'))
      SettingsRow({
        label: $r('app.string.settings_clear_recent'),
      }) {
        Text($r('app.string.action_clear'))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.danger'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            SettingsStore.clearRecent();
            Toast.show(this.getUIContext(), $r('app.string.cleared'));
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.bg_surface'))
    .borderRadius($r('app.float.radius_card'))
  }

  build() {
    NavDestination() {
      Column() {
        TopBar({
          title: $r('app.string.settings_title'),
          showBack: true,
          onBack: () => {
            this.pathStack.pop();
          }
        })

        Row({ space: 24 }) {
          Scroll() {
            Column({ space: 2 }) {
              this.GroupTitle($r('app.string.settings_group_profile'))
              this.ProfileCard()
              this.GroupTitle($r('app.string.settings_group_network'))
              this.NetworkCard()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .align(Alignment.Top)

          Scroll() {
            Column({ space: 2 }) {
              this.GroupTitle($r('app.string.settings_group_appearance'))
              this.AppearanceCard()
              this.GroupTitle($r('app.string.settings_group_about'))
              this.AboutCard()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .align(Alignment.Top)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 32, right: 32 })
        .alignItems(VerticalAlign.Top)

        Row() {
          AppButton({
            label: $r('app.string.action_save'),
            primary: true,
            active: true,
            onTap: () => {
              this.save();
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
