import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DEFAULT_PORT } from '../core/Routes';

const DOMAIN: number = 0x0000;
const TAG: string = 'SettingsStore';
const PREF_NAME: string = 'game_settings';

export const THEME_LIGHT: string = 'light';
export const THEME_DARK: string = 'dark';
export const THEME_SYSTEM: string = 'system';

/** 本地设置的内存模型，字段与 Preferences 的 key 一一对应。 */
export class AppSettings {
  nickname: string = '';
  defaultPort: number = DEFAULT_PORT;
  connectTimeoutSec: number = 8;
  themeMode: string = THEME_LIGHT;
  motion: boolean = true;
  lastHost: string = '';
  lastPort: number = DEFAULT_PORT;
}

/**
 * 设置持久化。
 * 进程启动时 init 一次，之后各页面直接 get() 读写内存模型，改动后 flush()。
 */
export class SettingsStore {
  private static prefs: preferences.Preferences | undefined = undefined;
  private static data: AppSettings = new AppSettings();

  static init(ctx: common.Context): void {
    try {
      const options: preferences.Options = { name: PREF_NAME };
      const p: preferences.Preferences = preferences.getPreferencesSync(ctx, options);
      SettingsStore.prefs = p;
      const s: AppSettings = SettingsStore.data;
      s.nickname = p.getSync('nickname', '') as string;
      s.defaultPort = p.getSync('defaultPort', DEFAULT_PORT) as number;
      s.connectTimeoutSec = p.getSync('connectTimeoutSec', 8) as number;
      s.themeMode = p.getSync('themeMode', THEME_LIGHT) as string;
      s.motion = p.getSync('motion', true) as boolean;
      s.lastHost = p.getSync('lastHost', '') as string;
      s.lastPort = p.getSync('lastPort', DEFAULT_PORT) as number;
    } catch (err) {
      const be = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'init failed: %{public}d %{public}s', be.code, be.message);
    }
  }

  static get(): AppSettings {
    return SettingsStore.data;
  }

  static flush(): void {
    const p: preferences.Preferences | undefined = SettingsStore.prefs;
    if (p === undefined) {
      return;
    }
    const s: AppSettings = SettingsStore.data;
    try {
      p.putSync('nickname', s.nickname);
      p.putSync('defaultPort', s.defaultPort);
      p.putSync('connectTimeoutSec', s.connectTimeoutSec);
      p.putSync('themeMode', s.themeMode);
      p.putSync('motion', s.motion);
      p.putSync('lastHost', s.lastHost);
      p.putSync('lastPort', s.lastPort);
      p.flushSync();
    } catch (err) {
      const be = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'flush failed: %{public}d %{public}s', be.code, be.message);
    }
  }

  static clearRecent(): void {
    const s: AppSettings = SettingsStore.data;
    s.lastHost = '';
    s.lastPort = s.defaultPort;
    SettingsStore.flush();
  }
}
