import { connection } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'NetInfo';

/** 模拟器里 10.0.2.x 是内部地址，别人连不上；10.0.2.2 才是宿主机的回环别名。 */
const EMULATOR_PREFIX: string = '10.0.2.';
const EMULATOR_HOST_ALIAS: string = '10.0.2.2';

/**
 * 读取本机网络信息。
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

  /**
   * 是否大概率跑在模拟器里。
   * SDK 没有提供 isEmulator，这里用 QEMU 用户态网络的固定网段判断：
   * 模拟器一定会拿到 10.0.2.15。
   */
  static isEmulatorLike(): boolean {
    return NetInfo.getLocalIpv4().startsWith(EMULATOR_PREFIX);
  }

  /** 模拟器访问宿主机的固定别名。 */
  static emulatorHostAlias(): string {
    return EMULATOR_HOST_ALIAS;
  }

  /**
   * 建议发给同学的地址。
   * 模拟器：10.0.2.2:端口（同机另一个模拟器可以直接用）
   * 真机：本机局域网 IP:端口
   * 注意真机连模拟器房主时需要宿主机的局域网 IP，这个 App 读不到，界面会另外提示。
   */
  static shareAddress(port: number): string {
    if (NetInfo.isEmulatorLike()) {
      return EMULATOR_HOST_ALIAS + ':' + port.toString();
    }
    const ip: string = NetInfo.getLocalIpv4();
    return ip.length > 0 ? ip + ':' + port.toString() : '';
  }
}
