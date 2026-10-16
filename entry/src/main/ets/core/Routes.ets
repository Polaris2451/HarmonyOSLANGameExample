/** Navigation 路由名，全局唯一，避免各处写字符串字面量。 */
export const ROUTE_SETTINGS: string = 'settings';
export const ROUTE_CREATE: string = 'createRoom';
export const ROUTE_JOIN: string = 'joinRoom';
export const ROUTE_ROOM: string = 'room';
export const ROUTE_GAME: string = 'game';

/** 协议版本，握手时双方比对。 */
export const PROTOCOL_VERSION: number = 1;

/** 默认监听端口。 */
export const DEFAULT_PORT: number = 8080;

/** 端口合法区间，1024 以下需要特权端口，直接排除。 */
export const PORT_MIN: number = 1024;
export const PORT_MAX: number = 65535;
