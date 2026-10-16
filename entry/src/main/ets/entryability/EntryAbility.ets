import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { SettingsStore, THEME_DARK, THEME_SYSTEM } from '../storage/SettingsStore';
import { SafeArea } from '../utils/SafeArea';

const DOMAIN = 0x0000;
const TAG = 'testTag';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 设置要在任何页面读取之前加载好
    SettingsStore.init(this.context);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  /**
   * 系统状态栏/导航栏默认是白底，横屏时会在底部露出难看的一条白边。
   * 这里把两条系统栏都刷成页面底色，白边就消失了。
   */
  private paintSystemBars(win: window.Window): void {
    try {
      const argb: number = this.context.resourceManager.getColorSync($r('app.color.bg_page').id);
      let hex: string = (argb & 0xFFFFFF).toString(16);
      while (hex.length < 6) {
        hex = '0' + hex;
      }
      const color: string = '#' + hex;
      win.setWindowSystemBarProperties({
        statusBarColor: color,
        navigationBarColor: color,
        statusBarContentColor: '#1F2328',
        navigationBarContentColor: '#1F2328'
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'setWindowSystemBarProperties failed: %{public}s', err.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'read bg_page color failed');
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });

    // 应用已保存的主题；module.json5 已声明横屏，这里再兜底一次
    try {
      const mode: string = SettingsStore.get().themeMode;
      let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      if (mode === THEME_DARK) {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      } else if (mode === THEME_SYSTEM) {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      }
      this.context.getApplicationContext().setColorMode(colorMode);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode: %{public}s', JSON.stringify(err));
    }

    // 用同步接口：getMainWindow() 的 Promise 在某些设备上迟迟不落定，
    // 那样避让区就永远量不到，摄像头会挡住界面。
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      // 必须开全屏布局：否则页面高度不含系统导航栏，底部会露出一条白色区域。
      // 开完之后再测避让区，底部内边距才是导航栏真实高度。
      win.setWindowLayoutFullScreen(true).then(() => {
        SafeArea.watch(win);
        this.paintSystemBars(win);
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}s', err.message);
        SafeArea.watch(win);
        this.paintSystemBars(win);
      });
      win.setPreferredOrientation(window.Orientation.LANDSCAPE).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'setPreferredOrientation failed: %{public}s', err.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'window setup failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
