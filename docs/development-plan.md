
# 局域网联机小游戏 · 开发计划（待确认）

> 技术栈：HarmonyOS 6.0.0 / API 26（Stage 模型，ArkTS + ArkUI）· 横屏应用 · 房主 P2P（无公共服务器）
> 游戏：五子棋（2 人）· 你画我猜（2-8 人）· 俄罗斯方块对战（2 人）

---

## 0. 已完成的可行性验证

计划里的关键技术点已经在本机 SDK 上核对过签名，不是猜测：

| 能力 | 结论 |
|---|---|
| App 内起服务器 | `webSocket.createWebSocketServer()` 存在（API 19+，API 24 起 crossplatform），本项目 target 26 ✅ |
| 服务器配置 | `start({ serverPort, serverIP, maxConcurrentClientsNumber, maxConnectionsForOneClient })` |
| 服务器事件 | `on('connect' \\| 'messageReceive' \\| 'close' \\| 'error')`，`send(data, connection)`，`close(connection)`，`listAllConnections()`，`stop()` |
| 错误码 | `2302005` 端口无法监听、`2302007` 端口被占用 → 可直接做「端口冲突」提示 |
| 权限 | `ohos.permission.INTERNET`（客户端与服务端同一权限） |
| 取本机 IP | `connection.getDefaultNetSync()` + `getConnectionPropertiesSync(net)` → `linkAddresses[].address.address` / `interfaceName` |
| 横屏声明 | `module.json5` 中 `abilities[].orientation = "landscape"`（已从 SDK 的 module.json schema 校验，合法值含 landscape / landscape_inverted / auto_rotation_landscape 等） |

**已被验证的环境**：hvigor 6.26.8 构建成功 → `hdc install` → `aa start` → 截屏，全链路跑通。
构建必须 `export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk`。

---

## 1. 已有开源实现调研（借鉴机制，不抄代码）

| 游戏 | 参考项目 | 借鉴什么 |
|---|---|---|
| 五子棋 | `gitcode.com/soarjacky/gomoku`（HarmonyOS / ArkTS，Canvas 绘制） | ArkTS 下 Canvas 棋盘绘制的可行做法、棋盘坐标换算 |
| 五子棋 | `github.com/gkoos/gomoku`、`justinfernald/5moku` | 胜负判定与 AI（本项目不需要 AI，只取判定逻辑） |
| 你画我猜 | `gitee.com/rtzhang_0817/draw-and-guess`（基于 HarmonyOS 分布式能力）、`github.com/thor-op/Squiggle`、`github.com/PsydoV2/SkribbleX` | 回合状态机、笔迹数据结构、房间码加入的交互 |
| 俄罗斯方块 | `github.com/Explore-In-HMOS-Wearable/block-game`（HMOS）、`cch01/just-tetris`、`nazmul-nhb/tetris` | 方块形状与旋转数据、下落/锁定节奏、触摸手势操作 |
| 绘制与动画 | Gitee `applications_app_samples` 的 `ArkTSCard/CanvasGame` | ArkTS Canvas 逐帧重绘与卡片化布局 |

**结论**：这三个游戏的开源实现都很多，但 **没有任何一家的视觉风格能直接覆盖「主入口 + 房间 + 设置 + 三种游戏」**。所以计划是：机制参考上述项目，**视觉另建一套统一的浅色设计系统**（见第 4 节）。

---

## 2. 总体架构

### 2.1 房主即服务器，一条代码路径

~~~text
房主设备                                    加入方设备
┌──────────────────────────────┐            ┌──────────────────┐
│ WsRoomServer (WebSocketServer)│◀──── ws ───│ WsConnection     │
│        ▲                     │            │ (客户端)          │
│        │ 权威房间逻辑/规则     │            │                  │
│ WsConnection (连 127.0.0.1)  │            │                  │
│        │                     │            │                  │
│ RoomStore / GamePage (UI)    │            │ RoomStore/GamePage│
└──────────────────────────────┘            └──────────────────┘
~~~

**关键决策：房主自己的客户端也走 `ws://127.0.0.1:<port>`**，而不是走「本地直连内部对象」。
好处是只有一套客户端代码路径，房主与加入方跑的是完全相同的逻辑，能让「房主有特权」这类 bug 无处藏身。

所有规则（落子合法性、猜词判定、消行与垃圾行、计分）只在房主进程执行；其他设备只发**输入**。

### 2.2 模块划分

~~~text
entry/src/main/ets/
  core/                     纯逻辑，无 ArkUI、无网络，可脱离设备单测
    Protocol.ets            Envelope 定义、消息类型常量、版本号
    Codec.ets               encode/decode、长度与字段校验
    NetInfo.ets             取本机局域网 IP
    games/gomoku/GomokuRules.ets
    games/drawguess/DrawGuessRules.ets
    games/tetris/TetrisRules.ets
  net/
    RoomServer.ets          WebSocketServer 封装（房主侧：连接管理/广播/踢人/端口冲突）
    RoomClient.ets          WebSocket 客户端封装（重连、心跳、序号）
    Transport.ets           两者共同实现的接口（游戏层只依赖这个）
  app/
    Session.ets             当前身份、角色(host/guest)、房间信息
    RoomController.ets      房间状态机：大厅 → 游戏中 → 结算
  viewmodel/
    LobbyStore.ets  RoomStore.ets  SettingsStore.ets
    games/GomokuStore.ets  TetrisStore.ets  DrawGuessStore.ets
  pages/
    Index.ets               主入口（创建 / 加入 / 设置）
    CreateRoom.ets  JoinRoom.ets  Settings.ets  Room.ets
    games/GomokuPage.ets  TetrisPage.ets  DrawGuessPage.ets
  components/
    theme/AppTheme.ets      设计 token（颜色/圆角/间距/字号/阴影）
    AppCard.ets  PrimaryButton.ets  TopBar.ets  PlayerChip.ets
    StatusBanner.ets  EmptyState.ets  LoadingSkeleton.ets
    games/GomokuBoard.ets  TetrisBoard.ets  CanvasBoard.ets
  storage/
    Prefs.ets               昵称、默认端口、最近连接、主题偏好
~~~

依赖方向：`pages → viewmodel → app → net → core`，游戏规则只在 `core`，UI 里不出现任何 socket 或 JSON 解析。

### 2.3 通信协议

~~~typescript
export interface Envelope {
  v: number;      // 协议版本，不匹配直接拒绝并给出可读原因
  t: string;      // 'hello'|'welcome'|'roomInfo'|'playerJoin'|'playerLeave'
                  // 'ready'|'start'|'input'|'state'|'event'|'ping'|'pong'|'error'
  seq: number;    // 发送方单调递增，接收方丢弃重复/过期帧
  ts: number;     // 房主时间戳
  body: string;   // JSON 字符串，按 t 解析成具体类型
}
~~~

规则：握手先行（`hello → welcome` 含 playerId/房间配置/tick 率）；心跳双向 3s，10s 无响应判定掉线；重连用 `resume{playerId, token}` 回到原座位。

### 2.4 房间人数与开始规则

| 游戏 | 人数 | 开始条件 | 备注 |
|---|---|---|---|
| 五子棋 | **恰好 2** | 第 2 人进入即自动开始 | 第 3 人连接直接拒绝：「房间已满（2/2）」 |
| 你画我猜 | 2 - 8 | 房主点「开始游戏」，≥2 即可；**>2 也直接开始** | 人数越多轮换越慢，房间页显示预计时长 |
| 俄罗斯方块对战 | 2 | 同上 | 每人独立棋盘 |

---

## 3. 页面与交互设计

### 3.1 主入口 `Index`（横屏三段式）

~~~text
┌──────────────────────────────────────────────────────────┐
│  [Logo]  局域网联机小游戏                    [设置 ⚙]      │
├──────────────────────────────────────────────────────────┤
│                                                          │
│   ┌────────────┐   ┌────────────┐   ┌────────────┐       │
│   │  创建房间   │   │  加入房间   │   │   设置     │       │
│   │  作为房主   │   │  输入IP端口 │   │ 昵称/端口  │       │
│   └────────────┘   └────────────┘   └────────────┘       │
│                                                          │
│   本机 IP：192.168.1.23     |     常用端口：9911           │
└──────────────────────────────────────────────────────────┘
~~~

底部常驻显示**本机 IP**，房主报给同学时不用再去设置里翻。

### 3.2 创建房间 `CreateRoom`

~~~text
┌──────────────────────────────────────────────────────────┐
│  ← 返回    创建房间                                       │
├──────────────────────────────────────────────────────────┤
│  选择游戏                                                 │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│   │  五子棋   │  │ 你画我猜  │  │ 俄罗斯方块│               │
│   │  2 人     │  │  2-8 人   │  │  2-4 人   │               │
│   └──────────┘  └──────────┘  └──────────┘               │
│                                                          │
│  端口号   [ 9911 ]   [自动选择]      状态：可用 ✓          │
│  昵称     [ 房主小明 ]                                    │
│                                                          │
│                        [ 创建房间并开始等待 ]              │
└──────────────────────────────────────────────────────────┘
~~~

端口交互要点：

- 默认 `9911`；限制 `1024-65535`（小于 1024 需要特权端口，直接拦掉）。
- 失焦即校验：范围 → 非数字 → 被占用（捕获 `2302007`）→ 三种不同提示，输入框红边。
- 「自动选择」从 9911 递增试到 9931，成功即采用。
- 创建成功后房间页顶部**大字显示** `IP:端口` 与一个「复制」按钮，方便念给同学。

### 3.3 加入房间 `JoinRoom`

~~~text
┌──────────────────────────────────────────────────────────┐
│  ← 返回    加入房间                                       │
├──────────────────────────────────────────────────────────┤
│  房主 IP    [ 192.168.1.23 ]     最近：192.168.1.23:9911  │
│  端口       [ 9911 ]                                      │
│  昵称       [ 学生A ]                                     │
│                                                          │
│  状态：正在连接 192.168.1.23:9911 …                        │
│                                                          │
│                        [ 加入 ]                           │
└──────────────────────────────────────────────────────────┘
~~~

失败分类提示（这是最容易做出「能用的演示」还是「一脸懵」的分水岭）：

- 超时 → 「连不上，确认房主已创建房间、且在同一 Wi-Fi」
- 连接被拒 → 「端口不对或房主已退出」
- 房间已满 → 「五子棋房间已满（2/2）」
- 协议版本不符 → 「双方版本不一致，请用同一份安装包」
- 游戏不匹配 → 「你的选择与房主房间不一致，已自动切换为 XXX」

### 3.4 房间页 `Room`（三种游戏共用外壳）

~~~text
┌──────────────────────────────────────────────────────────┐
│  ← 离开   五子棋   房间 192.168.1.23:9911   [复制]  3/2   │
├───────────────────────────────────┬──────────────────────┤
│                                   │  玩家 (2/2)           │
│        游戏主区域                  │  ● 房主小明 (房主)     │
│     （棋盘 / 画布 / 对战棋盘）       │  ● 学生A             │
│                                   │                      │
│                                   │  [ 开始游戏 ]（房主）   │
│                                   │  状态：等待玩家…       │
└───────────────────────────────────┴──────────────────────┘
~~~

- 手机横屏：主区域 `layoutWeight(2)` + 右侧栏 `layoutWeight(1)`，最小右栏宽度 240vp。
- 平板横屏（≥840vp）：主区域居中定宽，右栏固定 320vp。
- 房主才看得到「开始游戏 / 踢人 / 结束本局」；加入方看到的是「等待房主开始」。
- 房主退出 → 全员收到 `event{type:'hostLeft'}` → 显示「房主已离开，房间结束」并回主入口。
  （这是 P2P 的固有限制，UI 上要**提前说清**，不要让学生以为是 bug。）

### 3.5 设置页 `Settings`

| 分组 | 项 |
|---|---|
| 个人 | 昵称、头像色（从 8 个预设色里选） |
| 网络 | 默认端口、连接超时秒数、心跳间隔 |
| 外观 | 浅色/深色（默认浅色）、动效开关 |
| 游戏 | 五子棋棋盘线显示、你画我猜提示强度、俄罗斯方块按键灵敏度 |
| 关于 | 版本、协议版本、清空最近连接、清空本地数据 |

设置统一持久化到 `Preferences`，房主创房时直接读默认端口与昵称。

---

## 4. 视觉统一方案（浅色系）

### 4.1 候选风格

| 方案 | 特征 | 优点 | 风险 |
|---|---|---|---|
| **A. Material 3 浅色渐变（推荐）** | 柔和分层底色、大圆角 16-20、极淡阴影、单一主色 + 每游戏一个 tonal 辅色 | 与 ArkUI 组件气质最贴、表单类页面（设置/房间）最好做、投影仪上对比清晰 | 个性偏弱，需要靠游戏内主色找记忆点 |
| B. 新拟物硬边框（Neo-brutalism 浅色） | 高饱和浅底 + 2px 深色描边 + 硬阴影 | 游戏感强、棋子/方块辨识度高 | 小字号下边框显脏，设置页容易花 |
| C. 纸面手绘 | 米白纸底 + 墨线 | 和你画我猜绝配 | 俄罗斯方块的「科技感」冲突，难统一 |
| D. 毛玻璃 | 半透明面板 + 柔和渐变 | 现代 | ArkUI 上模糊开销大，低端机掉帧，可读性差 |

**推荐 A**：用 M3 浅色的骨架保证「主入口 / 房间 / 设置」这类表单页干净统一，再给三种游戏各一个主色作为视觉锚点。

### 4.2 统一 Token（草案）

| Token | 值 | 用途 |
|---|---|---|
| `bg_page` | `#F5F6F8` | 页面底 |
| `bg_surface` | `#FFFFFF` | 卡片/面板 |
| `bg_sunken` | `#EDEFF3` | 输入框、棋盘凹槽 |
| `text_primary` | `#1A1B1F` | 主文字 |
| `text_secondary` | `#6B7280` | 次要说明 |
| `border_subtle` | `#E3E6EB` | 分隔线、卡片描边 |
| `brand` | `#3B6FF5` | 全局主色（按钮/焦点） |
| `accent_gomoku` | `#2FA37A` | 五子棋主色 |
| `accent_drawguess` | `#F2963C` | 你画我猜主色 |
| `accent_tetris` | `#7C5CF0` | 俄罗斯方块主色 |
| `success / `warning / `danger` | `#2FA37A / #E9A23B / #E5484D` | 状态 |
| 圆角 | `card 16 / panel 20 / chip 999 / input 12` | |
| 间距 | `4 / 8 / 12 / 16 / 24 / 32` | 8 的倍数体系 |
| 字号 | `display 28 / title 20 / body 15 / caption 12`（fp） | |
| 阴影 | `0 2 8 rgba(20,24,40,0.06)` | 仅卡片 |

深色主题用同一套 key 在 `resources/dark/element/color.json` 覆盖，代码里永远只写 `$r('app.color.bg_surface')`。

### 4.3 一致性载体

一套公共组件让 6 个页面天然长得像：`AppCard` / `PrimaryButton` / `SecondaryButton` / `TopBar` / `SectionHeader` / `PlayerChip` / `StatusBanner` / `EmptyState` / `LoadingSkeleton` / `NumberField`。
页面骨架固定为 **TopBar（返回 + 标题 + 右侧状态） + 内容区 + 底部操作条**。

---

## 5. 横屏与小屏适配

- `module.json5` 声明 `orientation: "landscape"`，同时运行时 `setPreferredOrientation(LANDSCAPE)` 兜底。
- 横屏下刘海在**左右**，用 `expandSafeArea` 或让 TopBar 内缩。
- 断点（横屏宽）：手机 ≈ 640-900vp，折叠/小平板 ≈ 900-1100vp，大平板 ≥ 1200vp。
- 手机横屏高度只有 ~360vp：**所有弹窗必须能滚动**，内容区允许纵向滚动但不允许整页滚动。
- 游戏区域一律用 `onAreaChange` 量出实际尺寸后换算格子大小，不写死 vp。

---

## 6. 三种游戏的实现要点

### 6.1 五子棋

- 15×15，Canvas 单层绘制（33 个交叉点/行），不做一个格一个组件。
- 落子 → 房主判定 → 广播；悔棋需对方同意；认输；「再来一局」重置。
- 胜负判定：以落子点为中心四方向计数 ≥5。
- 房间满 2 人自动开局。

### 6.2 你画我猜

- 状态机：`lobby → choosing(15s) → drawing(60-90s) → reveal(5s) → scoreboard → 下一轮`。
- 笔迹**归一化坐标**存储，`stroke{color,width,points:[[x,y],…]}` 批量上报，单帧上限 200 点。
- **答案只发给画手**，其他人收到的是字数占位（`"__"`）——这是最容易做错、抓包就穿帮的一点。
- 服务端归一化猜词（去空格、转小写），猜对者在广播里只显示昵称。
- 词库放 `resources/rawfile/words.json`，房主进程读取并随机。

### 6.3 俄罗斯方块对战（已实现）

- 每人独立棋盘（10×20），房主侧权威，7-bag 随机出块。
- 客户端只发 `input{action:'move'|'rotate'|'softdrop'|'harddrop'}`。
- 消行按 1/2/3/4 行给对方累积 0/1/2/4 行垃圾，对方下一次锁定方块时落到其底部。
- 新方块出生位置被占住即出局，2 人局另一人直接获胜。
- 重力由房主每 100ms 的 tick 驱动，间隔随等级从 800ms 递减到 120ms 下限。
- 活动方块只发给本人，对手只拿到棋盘快照——省流量，也顺手防了作弊。

实现落在 `core/games/tetris/`（`TetrisPieces` 形状与旋转、`TetrisBoard` 棋盘与消行、`TetrisGame` 对局）
与 `pages/TetrisPage.ets`。活动方块与等级/垃圾行等实时状态走同一条 `GameSession` 接口，网络层没有任何改动。

---

## 7. 验证策略（这是本计划最需要先试验的一环）

| 方案 | 做法 | 可行性 |
|---|---|---|
| 1. 模拟器 + Node 无头客户端 | 模拟器当房主，`hdc fport tcp:18080 tcp:9911` 把端口映射到 Mac，Mac 上跑 Node 脚本连 `127.0.0.1:18080` | 高，几乎一定能通，适合早期联调 |
| 2. 双模拟器互连 | 两个 AVD 互相连 | **未知**，模拟器各自 NAT，可能互不可达 |
| 3. 双真机同 Wi-Fi | 最真实 | 需要两台设备 |
| 4. 单机回环 | 同一设备连 `127.0.0.1` 自己 | 只能验证协议，不能验证网络 |

本机当前已部署 AVD：Mate 90 Pro / Mate X7 / MatePad Pro 13 等，但**当前只有一个模拟器在线**（`127.0.0.1:5555`）。

**M0 的第一件事就是做方案 1 的连通性 spike**，确认「模拟器当房主 + 外部客户端连进来」可行；若不可行，就改用方案 3 或「双模拟器 + fport 桥接」。这个结论会决定后续所有联调方式，所以必须先做。

另有单元测试兜底：`core/` 下的规则是纯函数，用 hypium 在 `entry/src/test` 里跑，不需要设备——五子棋胜负、四方向计数、7-bag 分布、消行与垃圾行、猜词归一化全部可测。

---

## 8. 里程碑

| 阶段 | 交付 | 验收标准 |
|---|---|---|
| **M0 骨架** | 工程结构、协议、Token/组件库、主入口三选项、设置页、创建/加入房间、房间页空壳、横屏配置 | 两台设备能连上同一房间，互相看到昵称；端口冲突/连不上有正确提示 |
| **M1 五子棋** | 完整对局 + 再来一局 + 认输/悔棋 | 2 人下完一整局，胜负判定正确，房主退出有提示 |
| **M2 你画我猜** | 完整轮次 + 词库 + 计分 | 3 人玩满一轮，答案不泄露，笔迹同步流畅 |
| **M3 俄罗斯方块** | 独立棋盘 + 垃圾行 | 2 人一局，无 desync，先顶住者胜 |
| **M4 打磨** | 视觉统一、多尺寸适配、错误态补齐、课堂文档 | 手机/平板横屏均正常；四种连接失败态都有文案 |

---

## 9. 风险与对策

| 风险 | 对策 |
|---|---|
| 模拟器之间互不可达 | M0 spike 定方案，必要时用 `hdc fport` 桥接或双真机 |
| 房主切后台/锁屏导致服务器挂起 | `setWindowKeepScreenOn(true)` + 房间页提示「保持前台」+ 掉线检测 |
| 明文 `ws://` 被策略拦截 | M0 一并验证；若被拦则改用 `http` 长轮询或加入网络安全配置 |
| 教室 AP 开了客户端隔离 | 课前检查清单；文档写明如何关闭 |
| 端口被占用 | 捕获 `2302007`，给出「换一个端口」而非泛化错误 |
| 30 人同时重连打爆房主 | 指数退避 + 抖动（250ms → 5s 上限） |
| 横屏小高度下弹窗溢出 | 弹窗内容可滚动，最大高度 `90%` |

---

## 10. 需要你确认的点

1. **视觉风格**：选 A（M3 浅色 + 每游戏辅色，推荐）/ B（硬边框）/ C（纸面手绘）/ D（毛玻璃）？
2. **默认端口**：`9911` 可以吗？
3. **昵称**：是否允许空昵称自动生成（如「玩家1234」）？
4. **聊天**：五子棋和俄罗斯方块是否需要文字聊天？（你画我猜本身有猜词输入）
5. **开局方式**：房间页统一由房主点「开始游戏」，还是五子棋满 2 人自动开始？（我倾向：五子棋自动，其余房主手动）
6. **参数**：五子棋 15×15；你画我猜每轮 90 秒、每词 3 轮；俄罗斯方块起始速度 1 格/秒——是否合适？
7. **是否需要「再来一局」保持同一房间**，还是每局结束回房间页重新准备？
8. **代码注释语言**：中文注释可以吗？（面向教学，我建议中文注释 + 英文标识符）
