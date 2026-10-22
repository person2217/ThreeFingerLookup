# 三指查词

这是一个 macOS 菜单栏应用：三指轻点时读取指针下的文字，并通过 URL Scheme 发送到一个预选词典。

版本：0.1.0

支持的目标：

- 欧路词典：`eudic://dict/<word>`
- GoldenDict-ng：通过 `goldendict:///<word>?target=popup` 将词放入 URL path，避免 URL hostname 将中文或俄文转换为 punycode。

## 构建和运行

```sh
./script/build_and_run.sh
```

脚本会先用 SwiftPM 构建，再生成 `.build/ThreeFingerLookup.app` 并以菜单栏应用方式启动。只检查构建和包内容时运行：

```sh
./script/build_and_run.sh --verify
```

生成可分发的 App、ZIP 和 DMG：

```sh
./script/package.sh
```

产物位于 `dist/`。

首次使用需要在“系统设置 -> 隐私与安全性 -> 辅助功能”允许本应用。设置窗口里的“启用三指查词”是监听器的总开关；关闭后监听会停止，避免出现 AALookup 中关闭功能后仍期待手势的状态不一致。

启用时应用会保存两个触控板偏好域中的 `TrackpadThreeFingerTapGesture`，写入关闭值以避免系统查询覆盖层冲突。关闭应用功能或退出时，仅当值仍是应用写入的值才恢复原值；若应用异常退出，会在下一次启动时先恢复保存的值。

设置中的“系统手势巡检”可选择每 1、5、15 或 60 秒检查一次系统三指轻点状态。巡检使用进程内偏好 API，不会反复启动 `defaults` 子进程。

系统服务同时声明了“用三指查词查询”，选中文字后可从右键服务菜单调用，作为三指手势不可用时的备用入口。

## 取词流程

优先通过辅助功能读取指针位置和该位置的字符偏移，再由系统词典服务 `DCSGetTermRangeInString` 按当前启用的词典取得词项；系统词典没有返回有效范围时，才用 Apple `NaturalLanguage` 在指针位置进行词语分段。中文句子不会整行或整句直接传给词典。辅助功能无法提供指针下的有效词框时，且“启用 OCR 识别不可选文字”已打开，才截取指针附近区域并用 Vision 识别。OCR 需要在“屏幕录制”隐私设置中允许本应用；“测试 OCR”可以单独验证识别结果。

设置页的触控状态会显示监听后收到的帧数、最大触点数和识别到的三指轻点次数。监听启动只说明底层输入已连接；收到触控帧、识别到三指轻点、成功读取词语、成功打开词典是不同阶段。当前 Mac 优先使用私有的 `MultitouchSupport.framework`，其行为可能随 macOS 版本变化。

应用图标使用菜单栏的 `hand.tap` 图形生成。

当前版本在本机优先动态加载 macOS 的 `MultitouchSupport.framework`，直接读取触控帧；加载失败时回退到 AppKit 的公开 `NSEvent` gesture 事件。前者是私有 API，只针对当前 Mac 的 macOS 版本验证，不适合作为通用分发方案。系统服务入口仍可作为触控监听失败时的备用方式。
