## Brushline Rally 0.5.0

项目已更名为 **Brushline Rally**，GitHub 仓库为 `YicongCao/Brushline-Rally`。

### 本版内容
- 75 秒三赛道、三辆车实录 Demo，展示速度、后驱救车、动物、河桥、直升机与暮色风景。
- Demo 加入精简遥测 HUD，结束显示本次实播帧率曲线及平均、最高、最低 FPS。
- 玩法演示移到标题主行，自由练习移到次行。
- 透明矢量手柄图、精简键盘与鼠标示意，按实际操作标注。
- 三赛道成绩并排展示，返回主菜单按钮始终可见。
- 检查点光柱与 Brushline 漫画视觉；制作名单按 Pixelcao / Codex 等角色更新。

### 下载
- **macOS**：`Brushline-Rally-0.5.0-macos-universal.zip`（Apple Silicon / Intel），解压后打开 `Brushline Rally.app`。
- **Windows**：`Brushline-Rally-0.5.0-windows-x86_64.zip`，解压后打开 `Brushline Rally.exe`。
- 两包均附操作说明与依赖许可；对应 `.sha256` 可用于校验下载。

### 验证与已知边界
- 本轮 326 项自动检查通过；覆盖菜单输入、720p / 1080p / 超宽布局、档案/幽灵、Demo 仪表与帧率计算。
- macOS 包已实际启动并验证驾驶、音频、指南和三赛道 Demo。
- Windows 为 macOS 上交叉导出，已校验 PE / ZIP，尚未在真实 Windows 上运行验收。
- macOS 使用 ad-hoc 签名，未做 Apple 公证，下载后可能出现 Gatekeeper 提示。
- 实体手柄体验与真人奖牌难度仍待人工验证。G 值根据录制运动计算；HUD 扭矩为原厂全油门曲线值，不是当前实际输出扭矩。

完整验证记录与界面预览见仓库 `docs/validation/v050-release.zh-CN.md`。
