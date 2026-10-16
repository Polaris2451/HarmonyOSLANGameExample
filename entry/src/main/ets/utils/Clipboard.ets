import { pasteboard } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'Clipboard';

/** 复制文本到系统剪贴板，失败不抛出，由调用方决定是否提示。 */
export class Clipboard {
  static async copyText(text: string): Promise<boolean> {
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      return true;
    } catch (err) {
      const be = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'copyText failed: %{public}d %{public}s', be.code, be.message);
      return false;
    }
  }
}
