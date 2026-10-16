import { UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'Toast';

/** 统一的轻提示。集中处理，避免各处直接调用已弃用的全局 showToast。 */
export class Toast {
  static show(ctx: UIContext, message: ResourceStr): void {
    try {
      ctx.getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'showToast failed');
    }
  }
}
