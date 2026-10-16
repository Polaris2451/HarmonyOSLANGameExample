# 局域网联机：验证方式与实测结论

## 已验证的完整链路

房主设备起 WebSocketServer → 房主自己的客户端连 `127.0.0.1` → 外部客户端加入 → 成员列表实时广播 → 人数 ≥ 2 时「开始游戏」按钮点亮。

证据：[06-room-two-players.jpeg](assets/screenshots/06-room-two-players.jpeg)（房主 HostPhone、加入方 StudentA、2/2、开始游戏可点）。

## 无头客户端（教室里最实用的一件工具）

没有第二台设备时，用 Node 冒充一个加入方：

~~~bash
node tools/headless-client.mjs ws://127.0.0.1:8080 StudentA
~~~

实际输出：

~~~text
[StudentA] connected ws://127.0.0.1:8080
[StudentA] <- welcome {"playerId":"p2","game":"gomoku","maxPlayers":2,"protocolVersion":1}
[StudentA] <- roster {"game":"gomoku","maxPlayers":2,"players":[
  {"id":"p1","nickname":"HostPhone","isHost":true},
  {"id":"p2","nickname":"StudentA","isHost":false}]}
~~~

依赖 Node 22+ 内置的 WebSocket，不需要 `npm install`。

## 模拟器互联（关键，必须做端口映射）

模拟器各自 NAT，**互相不可直达**，必须借宿主机做桥：

~~~bash
# 把「房主设备」的 8080 映射到宿主机的 8080
hdc -t 127.0.0.1:5555 fport tcp:8080 tcp:8080
hdc fport ls                     # 确认映射存在
~~~

- 房主设备在 8080 起服务 → 宿主机 `127.0.0.1:8080` 转发到它。
- **加入的模拟器填 `10.0.2.2:8080`**（`10.0.2.2` 是宿主机回环在该模拟器里的别名）。
- 房主界面显示的「发给同学」正是 `10.0.2.2:8080`；而 `10.0.2.15` 是它自己的内部地址，**任何其他设备都连不上**，界面上已标为「本机内部地址（别人连不上）」。

> `hdc fport` 只监听 `127.0.0.1`。所以真机**无法**通过电脑的局域网 IP 连到模拟器里的房主；真机加入要么房主本身是真机，要么用真机当房主。

## 真机互联

房主是真机时，界面显示本机局域网 IP:端口，同学直接填这个即可。
房主是模拟器、同学是真机时，需要「电脑的局域网 IP:映射端口」，App 读不到电脑的 IP，因此界面上给出的是提示文案，需要人工告诉同学。

## 踩过的坑

### 1. WebSocketServer 起不来（2302999）

`webSocket.createWebSocketServer().start(config)` 在模拟器上：

| 配置 | 结果 |
|---|---|
| 显式 `serverIP: '0.0.0.0'` + `maxConcurrentClientsNumber: 16` | ✗ `2302999 Websocket Unknown Other Error` |
| 只给 `serverPort` + `maxConcurrentClientsNumber: 8` + `maxConnectionsForOneClient: 2` | ✓ 正常监听 |

**结论：不要显式写 `serverIP`，连接数取小值。** 错误码对照：`2302005`/`2302007` = 端口不可用/被占用，`2302004` = 网卡，`201` = 权限。

### 2. 端口映射会丢

模拟器重启或重连后 `hdc fport` 会消失（`fport ls` 显示 `[Empty]`）。**每次上课前重新执行一遍并确认**，否则学生一定连不上。

### 3. 「先发错误再断开」必须等发送完成

服务器拒绝连接（房间满、版本不符）时，如果 `send()` 之后立刻 `close()`，这一帧会被丢掉，客户端只看到「连接被断开」而拿不到原因。代码里 `RoomServer.reject()` 会等发送的 Promise 落定后再关闭。

### 4. 模拟器的 `hdc file recv` 在 2in1 设备上会挂起

同一套脚本在手机模拟器上正常。2in1（MateBook Pro）上 `snapshot_display` 能写文件，但 `file recv` 会卡住不返回。排查设备问题时优先用手机形态的模拟器。

## 冒烟测试清单（每次改动网络层后）

~~~bash
hdc fport ls                                     # 1. 映射在不在
node tools/headless-client.mjs ws://127.0.0.1:8080 A   # 2. 能不能加入
node tools/headless-client.mjs ws://127.0.0.1:8080 B   # 3. 五子棋满员后应收到 room_full
~~~
