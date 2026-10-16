import { connection } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'NetInfo';

/**
 * 读取本机局域网 IPv4 地址。
 * 房主需要把地址念给同学，所以主入口常驻显示。
 * 依赖 ohos.permission.GET_NETWORK_INFO，读不到时返回空串由界面兜底。
 */
export class NetInfo {
  static getLocalIpv4(): string {
    try {
      const net: connection.NetHandle = connection.getDefaultNetSync();
      if (net.netId === 0) {
        return '';
      }
      const props: connection.ConnectionProperties = connection.getConnectionPropertiesSync(net);
      const links: connection.LinkAddress[] = props.linkAddresses;
      for (const link of links) {
        const family: number = link.address.family === undefined ? 1 : link.address.family;
        const addr: string = link.address.address;
        if (family === 1 && addr !== '127.0.0.1') {
          return addr;
        }
      }
      return '';
    } catch (err) {
      const be = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'getLocalIpv4 failed: %{public}d %{public}s', be.code, be.message);
      return '';
    }
  }
}
