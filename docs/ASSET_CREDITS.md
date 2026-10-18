# Art Rally — 素材与工具名单

- 游戏与车辆设计、原创涂装、程序地景：Art Rally。没有汽车厂商标志、真实赞助商或第三方车型模型。
- 主菜单、金银铜奖牌及赛道符号 SVG 图标、三主题矢量场景插画：项目原创，源文件位于 `assets/ui/icons/` 与 `scripts/game/menu_backdrop.gd`。
- 专属车牌输入、预览和三维文字共用项目随附的 Noto Sans SC 字体，不依赖系统字体。
- 车辆可编辑源：`art_source/vehicles/*.blend`，导出：`assets/vehicles/*.glb`，可用 `blender --background --python scripts/generate_vehicles.py` 重建。
- 声音与菜单音乐：项目原创程序合成，生成脚本 `scripts/generate_audio.py`。没有外部录音、在线音源或 Kenney 资源混入包内。
- Godot Engine：MIT，https://godotengine.org/license/ 。运行时许可与第三方依赖名单见随包 `Godot-LICENSE.txt`、`Godot-THIRD-PARTY.json`。
- Jolt Physics：Godot 自带物理后端，依其打包许可分发。
- Noto Sans SC / Noto Sans Mono：SIL Open Font License，原文见 `assets/fonts/` 随附许可。
- Blender：仅用于源资产制作，不随游戏打包。

项目原创资产的分发遵循项目所有者许可；第三方字体和引擎保持原许可。
