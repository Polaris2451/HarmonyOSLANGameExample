# 开发环境（已在本机验证）

## 工具链位置

| 用途 | 路径 |
|---|---|
| DevEco Studio | `/Applications/DevEco-Studio.app` |
| SDK（API 26 / HarmonyOS 6.0.0） | `/Applications/DevEco-Studio.app/Contents/sdk` |
| hvigor | `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw`（6.26.8） |
| JDK | `/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home`（JBR 25.0.2） |
| hdc | `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`（3.2.0f） |

工程本身**没有** `hvigorw` 包装脚本，也没有在 `local.properties` 里写 `sdk.dir`，所以必须靠环境变量。

## 构建

```bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"

/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  assembleHap --mode module -p product=default --no-daemon
```

两个坑：

1. 缺 `DEVECO_SDK_HOME` → 立刻报 `00303217 Configuration Error`。
2. 缺 `JAVA_HOME` → ArkTS 编译能过，但 `PackageHap` 报 `00308018 Unknown Error`，真实原因被藏在 "Unable to locate a Java Runtime" 里。本机没有系统 JDK。

产物有两个：

- `entry/build/default/outputs/default/entry-default-signed.hap` —— **要装这个**
- `entry/build/default/outputs/default/entry-default-unsigned.hap`

### 踩过的坑：装错了包，改动"看起来不生效"

工程一旦有了签名配置，构建会同时产出 signed 与 unsigned 两个 HAP。
**把 unsigned 包 `install -r` 到已经装过 signed 包的设备上，hdc 会打印 `AppMod finish`（看起来成功），
但系统实际上没有替换应用。** 表现就是：改代码、构建成功、安装"成功"，界面却纹丝不动。

排查这种"改了没反应"时，第一步就是确认装的是哪个包：

~~~bash
SIGNED=entry/build/default/outputs/default/entry-default-signed.hap
hdc install -r "$SIGNED"
~~~

顺带：signed 与 unsigned 之间来回切换会让系统清掉应用数据（昵称、最近连接都会丢）。

## 运行与调试

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc

"$HDC" list targets                      # 127.0.0.1:5555 = 模拟器在线
"$HDC" install -r entry/build/default/outputs/default/entry-default-unsigned.hap
"$HDC" shell aa force-stop com.example.gameexample20261016
"$HDC" shell aa start -a EntryAbility -b com.example.gameexample20261016
"$HDC" shell hilog | grep -i testTag     # 运行日志
"$HDC" shell snapshot_display -f /data/local/tmp/s.jpeg && "$HDC" file recv /data/local/tmp/s.jpeg shot.jpeg
"$HDC" shell uitest uiInput click <x> <y>     # 模拟点击（分辨率 2832x1280）
"$HDC" shell uitest uiInput text <内容>        # 向已聚焦的输入框输入
"$HDC" shell uitest uiInput keyEvent Back
```

## 已部署的模拟器

`~/.Huawei/Emulator/deployed` 下有 Mate 90 Pro / Mate X7 / MatePad Pro 13 / MateBook Pro 等 AVD。
模拟器镜像：`~/Library/Huawei/Sdk/system-image/HarmonyOS-7.0.0`（pc_all_arm、phone_all_arm）。

## 横屏全屏与避让区

### 底部一条白边

现象：每个页面最下面都露出一条白色横带，中间是系统的返回手势条。
**根因不是页面没铺满，而是窗口本身没有铺满整屏。** 不开全屏布局时，页面的 `height('100%')`
只到系统导航栏之上，导航栏那段就由系统填成白色。

排查办法是量一下，别猜：

~~~typescript
const p = win.getWindowProperties();
hilog.info(0x0000, 'geo', 'win=%{public}dx%{public}d screen=%{public}dx%{public}d',
  p.windowRect.width, p.windowRect.height, d.width, d.height);
~~~

修复：

~~~typescript
win.setWindowLayoutFullScreen(true).then(() => {
  SafeArea.watch(win);      // 全屏之后再量避让区，底部内边距才是真实导航栏高度
});
~~~

再用 `setWindowSystemBarProperties()` 把状态栏/导航栏刷成页面底色，
个别设备上系统栏仍然不透明时也能融进去。

### 摄像头挖孔

横屏时挖孔在**左右两侧**，用 `getWindowAvoidArea(TYPE_CUTOUT)` 拿到的是 px，
要除以 `display.getDefaultDisplaySync().densityPixels` 换成 vp 再当内边距用。
把四个值写进 `AppStorage`、由最外层容器统一加 `padding`，所有页面一次性生效。

注意两点：

- 用 `getMainWindowSync()`，`getMainWindow()` 的 Promise 在某些设备上迟迟不落定，避让区会永远量不到。
- 验证时**别只看截图**，用像素采样确认。JPEG 存下来直接数一行里有多少接近纯白的点，
  比人眼判断可靠得多：

~~~python
im = Image.open(path).convert('RGB'); w, h = im.size; px = im.load()
white = sum(1 for y in range(h-40, h) for x in range(0, w, 20)
            if px[x, y][0] > 250 and px[x, y][1] > 250 and px[x, y][2] > 250)
~~~
