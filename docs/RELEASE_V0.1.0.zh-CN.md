# Art Rally v0.1.0

首个可独立运行的垂直切片版本：在约 3.05 km 的“夕照松岭”完成 FWD / AWD / RWD 拉力驾驶、计时赛段、图形路书、检查点、罚时恢复和本地成绩。

## 主要内容

- 200 PS、六速、自动离合与安全自动换挡
- 自定义轮胎、悬架、限滑传动、四类路面与积水响应
- FWD / AWD / RWD 选择与停稳自动倒挡
- 三视角、驾驶舱仪表、HUD、合成音效、尘泥水反馈和轮胎印
- 默认关闭、真人可立即接管的虚拟键盘 / 虚拟手柄自动驾驶
- 按驱动布局与标定版本隔离的人类最佳和自动驾驶参考成绩
- F9 四轮、动力和车身实时调试面板
- 内置中文与数字字体，无系统字体依赖

## 下载

- `Art-Rally-macos-universal.zip`
  - macOS universal：Apple Silicon arm64 + Intel x86_64
  - ad-hoc 签名，未进行 Developer ID 签名或 Apple 公证
- `Art-Rally-windows-x86_64.zip`
  - Windows x86_64，项目资源嵌入 `Art Rally.exe`
  - 未进行 Authenticode 签名，可能触发 SmartScreen
- 同名 `.sha256` 文件用于校验下载完整性

macOS 包已在 Apple M4 Pro 上启动并通过主场景、字体、音频、设置与成绩读写冒烟。Windows 包由 macOS 使用官方 Godot 4.7.2 模板交叉导出，PE/ZIP 结构检查通过，但尚未在真实 Windows 机器上运行。

## 常用操作

- W / S 或方向键：油门 / 制动
- A / D 或方向键：转向
- Space：手刹
- C：切换视角
- R：恢复车辆
- Esc：暂停与设置
- F9：实时调试面板
- F10：关闭 / 虚拟键盘 / 虚拟手柄自动驾驶

## 验证摘要

- FWD / AWD / RWD × 虚拟键盘 / 虚拟手柄六组合均通过 31 个检查点，恢复 0 次
- 30 / 60 / 120 FPS 固定输入回放差异低于 1%
- M4 Pro、1920×1080、Metal / Forward+ 的三次完整跑段性能和内存报告已记录
- macOS universal 应用的 ad-hoc 签名与包内冒烟通过
- Windows x86_64 的 PE32+、嵌入资源与 ZIP 完整性通过

## 已知限制

- 当前会话未连接真实手柄；扳机量程、震动、热插拔及六组真人完整跑段仍待正式记录
- 主观声音平衡仍待真实耳机 / 扬声器试听；当前声音为程序合成，不是实车录音
- Windows 的 D3D12 / Vulkan、镜头光斑、性能、手柄和 AppData 写入仍待真实 Windows 验收
- 轮胎接触仍是射线包络；没有完整非簧载质量、侧壁碰撞、温度磨损、动态车辙或精细车损
- 两个平台都不是面向公开分发的正式代码签名 / 公证版本

完整技术结果见 `docs/M6_VALIDATION.zh-CN.md`。
