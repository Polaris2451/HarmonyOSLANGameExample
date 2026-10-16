import { UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'Confirm';

/** 危险操作的二次确认。点「取消」或弹窗失败都返回 false。 */
export class Confirm {
  static async ask(ctx: UIContext, title: ResourceStr, message: ResourceStr,
    okText: ResourceStr): Promise<boolean> {
    try {
      const res = await ctx.getPromptAction().showDialog({
        title: title,
        message: message,
        buttons: [
          { text: $r('app.string.action_cancel'), color: '#6B7280' },
          { text: okText, color: '#E5484D' }
        ]
      });
      return res.index === 1;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'confirm dialog failed');
      return false;
    }
  }
}
