# Brushline Rally 0.5.0 发布记录

2026-10-21 · Godot 4.7.2 · Tag `v0.5.0`

## 内容

- GitHub 仓库更名为 `YicongCao/Brushline-Rally`，远程地址同步更新；日常本地工程路径继续使用 `/Users/cong/Documents/Projects/Art-Rally`。
- 标题主行：开始计时挑战、玩法演示、设置。自由练习移到次行。
- 操作指南使用透明 SVG 手柄线框、Godot 矢量键盘和鼠标示意；仅保留常用按键，按当前键盘映射标注。手柄按实际位置与 Xbox / PlayStation 键名标注。
- 成绩册按三赛道横排，一屏显示九个成绩；动力档选中态和返回按钮持续可见。
- 制作名单：引擎 Godot Engine、物理 Jolt Physics、创意设计 Pixelcao、领航语音 合成语音、代码生成 Codex、制作人 Pixelcao。
- 本次发行包含此前完成的 Brushline 漫画风格、三色检查点光柱、75 秒三赛道实录 Demo、简洁遥测 HUD，以及结束后的实播 FPS 图与统计。
- 应用、macOS Bundle、Windows 文件版本统一为 0.5.0；包名包含 Brushline-Rally 和版本号。

## 验证

本轮 **326 项检查通过**：原生 UI 89、主菜单入口 12、菜单手柄 35、菜单布局 135、输入 11、档案/幽灵 31、Demo 仪表/统计 13。

UI 使用不受 macOS 窗口宽度限制的独立 SubViewport，断言实际渲染尺寸。在 1280×720、1920×1080、2560×1080 下检查了主菜单、指南、成绩册和署名；成绩册覆盖满金牌、三动力档及 999.999 秒成绩。无纵向滚动，返回操作通过真实 Viewport GUI 输入路径验证。测试中的按键事件是模拟输入，不代表实体手柄验收。

原生 UI 测试等待页面转场结束后再发按钮事件；菜单左右导航的预期已按新顺序更新。透明图像导出检查了 alpha 通道。

macOS 导出包通过实际窗口启动：目录资源、字体、音频、驾驶、右摇杆、车牌、指南矢量、三赛道演示素材、HUD 与结束流程；输出 `PACKAGE SMOKE PASSED`。Bundle 版本为 0.5.0，ad-hoc 签名完整性验证通过。

Windows x86_64 包通过交叉导出、PE 架构和 ZIP 完整性检查。两个 ZIP 均通过 SHA-256 回读校验，具体大小和校验值见 [JSON](v050-release.json)。

[界面图册与透明线框图](v050/index.html) · [测试日志](v050/ui.log) · [macOS 包检查](v050/macos-app-check.log) · [Windows 包检查](v050/windows-package-check.log)

## 发行包与边界

- `Brushline-Rally-0.5.0-macos-universal.zip`：arm64 / x86_64，应用名 `Brushline Rally.app`。
- `Brushline-Rally-0.5.0-windows-x86_64.zip`：应用名 `Brushline Rally.exe`。
- 每包附带玩法说明、素材/字体/依赖许可，另发布对应 SHA-256 文件。
- macOS 未做 Developer ID 签名或 Apple 公证，下载后可能触发 Gatekeeper。Windows 未做真实系统运行验收。真人奖牌难度与实体手柄体验仍待人工验证。

复现：`./scripts/dev.sh export-macos`、`macos-app-check`、`export-windows`、`windows-package-check`。UI：`godot --path . --script res://tests/v050_ui_test.gd -- --test-defaults`。
