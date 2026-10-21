# 三赛道光柱检查点

2026-10-21：先使用内置 imagegen，参考三条赛道的既有实机截图生成[概念图](concept.png)，随后按图实现游戏效果。[完整生成提示词](concept-prompt.txt)随工程保存。图片是设计参考，运行时光柱使用网格和 shader，不把概念图当作游戏贴图。

## 配色与造型

- **夕照松岭：冰青 `#61E8FF`**，与金橙植被形成冷暖对比。
- **晴岬海岸：兰紫 `#D69AFF`**，在浅黄地形与蓝绿天空中区分检查点。
- **雾杉高地：琥珀金 `#FFC46B`**，在深蓝紫暮色中提供温暖的道路标记。

共同造型为约 0.8 m 宽、0.25 m 高的石墨色六边形灯座，环形发光透镜，5.2 m 高的光束。细亮芯、半透明外晕、上升光点和顶部淡出对应概念图；每对灯座附近投射同色地面灯光。光柱本身不带实体管壳，不投影，不添加碰撞。

当前目标亮度为 1.0，未来目标为 0.48，通过后为 0.13；通过时有短暂余辉。只有当前目标显示菱形符号。动画随暂停冻结；灯光在远距离关闭。起终点拱门、检查点顺序、通过判定、漏点罚时、成绩与幽灵格式沿用现有逻辑。

## 实机效果

- [松岭](sunset_ridge.jpg)
- [海岸](sunlit_cape.jpg)
- [高地](misty_highlands.jpg)
- [灯座近景](projector-detail.jpg)

以上是 Godot 4.7.2 / Metal Forward+ / Apple M5 的 1600 × 900 原生窗口截图。与概念图相比，实机维持原有赛道构图，光晕范围更收敛以保持路面可读性。

## 实现与复现

- `scripts/presentation/checkpoint_markers.gd`：配色、低矮灯座、分组实例、门状态、两个复用的局部地灯。
- `assets/shaders/checkpoint_light.gdshader`：朝向镜头但保持竖直的柔光、光点、地面光晕和通过余辉；使用暂停同步的时钟。
- `assets/shaders/checkpoint_projector.gdshader`：石墨灯座和发光环。
- `scripts/dev/light_checkpoint_capture.gd`：三赛道与灯座截图，使用隔离档案和静音练习模式。
- `tests/light_checkpoint_test.gd`：替代旧压力气柱专项检查，覆盖所有赛道的配色、成对数量、路面净空、坡道竖直、锚点高度、顺序状态、暂停和灯光复用。

历史气柱／螺旋风帆源文件及制作脚本保留，不再由检查点运行时代码加载。原来的风机循环音效已从沿途检查点移除。

```bash
godot --headless --path . --script res://tests/light_checkpoint_test.gd
godot --path . --max-fps 60 --script res://scripts/dev/light_checkpoint_capture.gd -- --test-defaults
```

## 验证

8 组针对性验证共 **236 项检查、0 失败**：光柱专项 52，原生渲染状态 58，车身过门 7，赛段计时 20，赛段运行 13，驾驶提示 23，环境主题 20，场景内容 43。详见 [validation.json](validation.json) 与本目录日志。

已逐张查看三赛道及灯座截图，确认白天、暮色下的颜色和光束，原生截图过程无脚本或 shader 错误。本次未运行整套回归或 Windows 实机验证。
