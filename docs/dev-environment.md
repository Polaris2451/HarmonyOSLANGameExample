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

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。
`signingConfigs` 为空，所以是未签名包；模拟器可直接安装，**真机调试需要另行配置签名**。

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
