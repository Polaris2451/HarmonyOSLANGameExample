# 局域网联机：验证方式与实测结论

## 已端到端验证的完整链路

两台模拟器（都跑 ArkTS 客户端）真实连通：

| 步骤 | 结果 |
|---|---|
| 房主设备起 WebSocketServer | ✓ `server listening on 8080` |
| 房主自己的客户端连 `127.0.0.1` | ✓ `connected 127.0.0.1:57186` |
| 加入方从另一台模拟器经 `10.0.2.2` 连入 | ✓ `connected 127.0.0.1:37892` |
| 成员列表实时广播到双方 | ✓ 两边都显示 2/2 |
| 人数 ≥ 2 时「开始游戏」点亮（仅房主） | ✓ |
| 第三个客户端被拒并收到原因 | ✓ `<- error {"code":"room_full"}` |

证据：[07-host-two-devices.jpeg](assets/screenshots/07-host-two-devices.jpeg)（房主）、
[08-guest-two-devices.jpeg](assets/screenshots/08-guest-two-devices.jpeg)（加入方）。

## 关键结论：该填哪个 IP

| 场景 | 同学要填的地址 |
|---|---|
| **同一台电脑上的模拟器之间** | `10.0.2.2:端口`（`10.0.2.2` 是宿主机回环在该模拟器里的别名） |
| **真机之间（同一 Wi-Fi）** | 房主设备的**真实局域网 IP** `192.168.x.x:端口` |
| **模拟器房主 + 真机加入** | 电脑的局域网 IP + 映射端口（App 读不到电脑 IP，需人工告知） |

模拟器里 App 读到的 `10.0.2.15` 是它自己的内部地址，**任何其他设备都连不上**。
界面上「发给同学」显示的是 `10.0.2.2:端口`，并把 `10.0.2.15` 标为「本机内部地址（别人连不上）」。
注意 `hdc fport` 只监听 `127.0.0.1`，所以真机无法经电脑的局域网 IP 连到模拟器里的房主。

## 无头客户端

没有第二台设备时，用 Node 冒充加入方：

~~~bash
node tools/headless-client.mjs ws://127.0.0.1:8080 StudentA
~~~

依赖 Node 22+ 内置的 WebSocket，不需要 `npm install`。它在实测中直接抓出了房间满员的拒绝报文。

## 模拟器互联（必须做端口映射）

~~~bash
hdc -t 127.0.0.1:5555 fport tcp:8080 tcp:8080   # 房主设备的 8080 → 宿主机 8080
hdc fport ls                                     # 确认映射还在
~~~

模拟器各自 NAT，互相不可直达，必须借宿主机搭桥。

## 踩过的坑（都已在代码里修掉）

### 1. WebSocketServer 的配置非常挑

`webSocket.createWebSocketServer().start(config)` 在模拟器上的实测结果：

| 配置 | 结果 |
|---|---|
| 带 `serverIP: '0.0.0.0'` | ✗ `2302999 Websocket Unknown Other Error` |
| `maxConcurrentClientsNumber: 16` 或 `maxConnectionsForOneClient: 16` | ✗ `2302999` |
| 只给 `serverPort` + `maxConcurrentClientsNumber: 8` + `maxConnectionsForOneClient: 8` | ✓ |

**两个连接数上限都不能超过官方文档的默认值 10**，超过就直接起不来；**也不要显式写 `serverIP`**。

### 2. `maxConnectionsForOneClient` 是按「来源 IP」算的（最容易踩）

模拟器经宿主机端口映射时，**所有客户端在房主看来都来自 `127.0.0.1`**（房主自己的回环客户端也是）。
这个值取 2 时，第 3 个连接会被 WebSocket 层直接拒掉，服务端只看到 `server error: 200`，
根本走不到我们自己的「房间已满」逻辑。取 8 后正常。

### 3. 拒绝连接时必须延迟关闭

只等 `send()` 的 Promise 落定还是不够 —— 立刻 `close()` 会把这一帧截断，客户端只看到
「连接被断开」而拿不到原因。代码里在发送后再延迟 500ms 关闭，客户端才收到
`{"code":"room_full"}`。`RoomServer.reject()` 有注释说明。

### 4. 端口映射会丢

模拟器重启或重连后 `hdc fport` 会消失（`fport ls` 显示 `[Empty]`）。**每次上课前重新执行并确认。**

### 5. 房间页的两个时序问题（加入方看不到自己）

- 加入方的连接在跳转前就已经 OPEN，房间页却把状态初始化成「正在连接…」→ 改成进入页面时
  先从 `RoomSession` 同步当前状态。
- 服务器在 `welcome` 之后立刻广播 `roster`，可能早于房间页订阅 → `RoomSession` 缓存最近一次成员列表，
  房间页创建时补放一次。
- 顺带：加入方本来不知道房主选了什么游戏，现在从 `welcome` 里拿到，标题能正确显示「五子棋」。

### 6. 不同模拟器分辨率不同，坐标不能复用

5555 是 2832×1280，5557 是 2444×1080。用 `uitest uiInput click` 自动化时必须按设备量。

### 7. 2in1 设备的 `hdc file recv` 会挂死

同一套脚本在手机形态的模拟器上正常；2in1（MateBook Pro）上 `snapshot_display` 能写文件，
但 `file recv` 一直不返回。排查设备问题时优先用手机形态的模拟器。

## 冒烟测试清单

~~~bash
hdc fport ls                                          # 1. 映射在不在
node tools/headless-client.mjs ws://127.0.0.1:8080 A  # 2. 能否加入（应收到 welcome + roster）
node tools/headless-client.mjs ws://127.0.0.1:8080 B  # 3. 五子棋满员后应收到 room_full
~~~
