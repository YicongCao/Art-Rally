# Retro 仪表盘验证

2026-10-18，Godot 4.7.2，Apple M5 / 原生 Metal。

- HUD 保持原有 262×264 逻辑尺寸与透明亚克力底层，加入双层表圈、奶油色刻度、红区、橙色转速指针、独立挡位窗口与分段踏板条。
- HUD 核心读数及驾驶舱共用标题 ART RALLY 的 `RallyFonts.plate()` 字体链（Chakra Petch Bold，中文回退）；计时与路书布局保持原样。
- 胎纹和泥点为固定种子的程序矢量装饰，集中在表壳边缘，不随帧随机跳动，不覆盖主要数字。手刹与同步换挡图标预加载，避免首次显示时出现实色占位方块。
- `tests/hud_test.gd`：20 项通过，0 失败；覆盖实际速度/转速/挡位数据、倒挡、计时与多分辨率边界。
- `scripts/dev/gauge_capture.gd`：原生渲染成功，无脚本或资源错误。检查松岭 1280×720、海岸 1920×1080，以及驾驶舱 768×300 渲染纹理。大号三位速度、挡位、RPM 与手刹图标没有重叠，明亮背景下可读。
- 截图使用隔离档案及人为设置的 128 / 236 km/h、4 / 6 / R 挡、900 / 5200 / 7500 RPM，验证排版极值，不能视为对应速度的完整驾驶测试。未修改玩家存档；音频静音仅作用于截图进程。

预览：

- [松岭仪表](../previews/retro-gauge-sunset_ridge.jpg)
- [海岸高转速](../previews/retro-gauge-sunlit_cape.jpg)
- [海岸倒挡与手刹](../previews/retro-gauge-sunlit_cape-reverse.jpg)
- [驾驶舱](../previews/retro-cockpit.png)

复现：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/hud_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --max-fps 60 --script res://scripts/dev/gauge_capture.gd -- --test-defaults
```
