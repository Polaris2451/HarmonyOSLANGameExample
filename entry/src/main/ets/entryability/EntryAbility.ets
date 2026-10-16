import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { SettingsStore, THEME_DARK, THEME_SYSTEM } from '../storage/SettingsStore';

const DOMAIN = 0x0000;
const TAG = 'testTag';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 设置要在任何页面读取之前加载好
    SettingsStore.init(this.context);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
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

    windowStage.getMainWindow().then((win: window.Window) => {
      win.setPreferredOrientation(window.Orientation.LANDSCAPE).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'setPreferredOrientation failed: %{public}s', err.message);
      });
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'getMainWindow failed: %{public}s', err.message);
    });
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
