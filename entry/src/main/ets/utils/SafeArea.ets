import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'SafeArea';

export const KEY_SAFE_TOP: string = 'safeTopVp';
export const KEY_SAFE_BOTTOM: string = 'safeBottomVp';
export const KEY_SAFE_LEFT: string = 'safeLeftVp';
export const KEY_SAFE_RIGHT: string = 'safeRightVp';

/**
 * 挖孔（摄像头）与系统栏避让。
 *
 * 应用是横屏的，摄像头在**左右**两侧，必须把内容往中间收，
 * 否则左上角/右上角会被挡住。window 给出的避让区域单位是 px，
 * 而 ArkUI 的内边距是 vp，这里换算后写进 AppStorage，由根容器统一加内边距。
 *
 * 避让区为 0 的设备（平板、部分模拟器）不会有任何视觉变化。
 */
export class SafeArea {
  /** 订阅一次，并在旋转/折叠等导致避让区变化时同步更新。 */
  static watch(win: window.Window): void {
    SafeArea.publish(win);
    try {
      win.on('avoidAreaChange', () => {
        SafeArea.publish(win);
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'avoidAreaChange subscribe failed');
    }
  }

  private static publish(win: window.Window): void {
    let top: number = 0;
    let bottom: number = 0;
    let left: number = 0;
    let right: number = 0;

    // 摄像头挖孔：横屏时落在左右两侧
    try {
      const cut: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      left = SafeArea.max(left, cut.leftRect.width);
      right = SafeArea.max(right, cut.rightRect.width);
      top = SafeArea.max(top, cut.topRect.height);
      bottom = SafeArea.max(bottom, cut.bottomRect.height);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'cutout area unavailable');
    }

    // 状态栏 / 导航条
    try {
      const sys: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      top = SafeArea.max(top, sys.topRect.height);
      bottom = SafeArea.max(bottom, sys.bottomRect.height);
      left = SafeArea.max(left, sys.leftRect.width);
      right = SafeArea.max(right, sys.rightRect.width);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'system area unavailable');
    }

    const density: number = SafeArea.density();
    AppStorage.setOrCreate(KEY_SAFE_TOP, SafeArea.toVp(top, density));
    AppStorage.setOrCreate(KEY_SAFE_BOTTOM, SafeArea.toVp(bottom, density));
    AppStorage.setOrCreate(KEY_SAFE_LEFT, SafeArea.toVp(left, density));
    AppStorage.setOrCreate(KEY_SAFE_RIGHT, SafeArea.toVp(right, density));

    hilog.info(DOMAIN, TAG, 'safeavoid t=%{public}d b=%{public}d l=%{public}d r=%{public}d',
      top, bottom, left, right);
  }

  private static max(a: number, b: number): number {
    return a > b ? a : b;
  }

  private static toVp(px: number, density: number): number {
    if (px <= 0) {
      return 0;
    }
    return Math.ceil(px / density);
  }

  private static density(): number {
    try {
      const d: number = display.getDefaultDisplaySync().densityPixels;
      return d > 0 ? d : 1;
    } catch (err) {
      return 1;
    }
  }
}
