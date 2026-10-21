# 75 秒 Demo：速度、救车与沿途风景

主菜单 → **玩法演示**。准备三赛道完成后开始计时，75 秒到结束页；“再看一次”复用已加载场景。空格、Esc 或手柄 Start 暂停 / 继续。

- [分镜图册与完整影片](index.html)
- [75 秒实机录像](demo-75s.mp4)（720p / 60 FPS / 4,500 帧，含音轨）
- [侧拍 5 秒](side.mp4)、[救车 12 秒](recovery.mp4)
- [逐镜头实测与碰撞扫描](validation/metrics.json)
- [分镜清单](../../../resources/showcase/film.json)和同目录七份真实驾驶录制

## 成片结构

00–05 秋色俯拍；05–11 低位追车；11–16 固定侧拍与制动；16–28 后驱外甩与救车；28–34 驯鹿横穿。34–40 海湾全景；40–46 引擎盖；46–54 770 m 河桥；54–60 直升机伴飞。60–66 高地悬崖；66–72 头灯与琥珀光柱；72–75 拉远淡出。

进入赛道时短显名称，展示精简矢量遥测 HUD，隐藏悬浮检查点符号，保留世界光柱。跨赛道 0.4 秒叠化计入总时长。音乐贯穿，引擎转速、负载和轮胎声跟随遥测。新版 12 张预览来自实际 Godot 场景捕获。原版完整录像保留纯电影画面；新增带仪表的救车短片。

## 驾驶证据

R200 原厂 240 PS、F160 原厂 220 PS、A240 原厂 288 PS，120 Hz 物理录制、60 Hz 姿态与遥测。没有修改车辆动力、没有将动画轨迹冒充物理驾驶、没有加速播放。现有幽灵记录版本 1 保持不变；Demo 额外记录速度、转速、挡位、油门、制动、侧滑、线路进度和辅助系统状态。

救车是 12 秒连续片段，原始素材 7–19 秒映射到影片 16–28 秒：侧滑峰值 **15.39°**，出现反打后回落，在 4°以内连续保持约 **5 秒**。无碰撞、手刹或镜内复位。大角度外甩是短暂的真实动作，未将整镜宣称为持续漂移。录制专用 ABS 开、ESP/TC 关，未写入玩家设置。

各镜头巡航速度以实际物理素材为准。最高约 110 km/h；弯前制动和救车会低于原分镜目标，完整最小值 / 中位数 / 最大值见图册与 metrics.json。素材是精选跑段，剪辑间可能换到不同路段，不代表一段无剪辑比赛。

原始录制只建立道路碰撞世界；交付素材在完整景观世界额外进行了 60 Hz 车身包络扫描，未发现景物碰撞。未篡改记录中的姿态；仅裁掉未使用的尾段，保留预热和来源参数。被裁尾素材的原始完整运行状态保存在 provenance 中。

## 实现

- `scripts/showcase/showcase_director.gd`：75 秒时间轴、三个 SubViewport、短标题、叠化、暂停重播。
- `showcase_world.gd`：独立档案、冻结物理代理、关闭普通驾驶与回放更新；关闭失焦 / 设备通知的旧暂停信号，避免旧输入控制器暂停整个树。
- `showcase_camera.gd`：绝对时刻机位函数，平滑道路方向和录制姿态；固定侧拍方向、水平地平线。引擎盖只保留真实车身运动。
- `showcase_audio.gd`：单一声音控制者；遥测同步引擎 / 路面，景观声音按镜头调度。
- 鸟群、动物、直升机、灯柱、车灯以及水面 / 植被 shader 使用电影时钟。暂停冻结时间，重播重置事件。粒子使用固定种子，普通回放效果重建轮胎接触与扬尘。
- `export_presets.cfg` 明确包含 `resources/showcase/*.json`；文档与 MP4 不进入游戏运行包。

## 验证与复现

在常用工程目录运行，Godot 版本锁定 **4.7.2**：

```sh
cd /Users/cong/Documents/Projects/Art-Rally
godot --path .
godot --headless --path . --script res://tests/showcase_test.gd -- --test-defaults
```

本次专项 95 项、仪表与统计计算 13 项，以及 HUD / 调试面板 / 菜单输入回归 105 项通过；原版相关回归 149 项的记录仍保留；日志位于 `validation/`。验证包含全场景碰撞扫描、真实位移 / 速度一致性、救车遥测、30 / 60 / 120 FPS 轨迹连续性、键盘和模拟手柄输入、暂停、事件重现、无存档修改、结束与复用场景重播。实际检查 720p、1080p 菜单布局；实体手柄未额外测试。

原生短片录制在先，机位修正后才串联完整影片。30 / 120 FPS 的侧拍 / 救车和引擎盖已原生渲染检查，完整 60 FPS 影片覆盖全部 12 镜。固定帧率录制是帧序列验证，不作为硬件实时性能承诺。

```sh
# 生成实际场景机位预览（独立测试档案）
godot --path . --max-fps 60 --script res://scripts/dev/showcase_capture.gd -- --test-defaults

# 按物理输入重录救车候选；不能直接替换成片，需重新跑专项验收
mkdir -p logs/showcase
godot --headless --path . --fixed-fps 120 --script res://scripts/dev/record_showcase.gd -- --start=2700 --duration=20 --speed=22 --drift=10 --kick=.30 --hold=.52 --counter=.65 --out=res://logs/showcase/recovery-candidate.json

# 原生渲染影片，再按准确帧号移除准备阶段（不改变播放速度）
godot --path . --write-movie logs/showcase/full-native.avi --fixed-fps 60 --script res://scripts/dev/showcase_movie.gd -- --from=0 --duration=75 --fps=60 --test-defaults
python3 scripts/dev/encode_showcase.py logs/showcase/full-native.avi logs/showcase/movie-0-60.json docs/brushline/showcase/demo-75s.mp4
python3 scripts/dev/build_showcase_report.py
```

`record_showcase.gd` 只给车辆发送转向、油门、制动、换挡命令；唯一起点复位在录制前完成。实际性能和音量仍取决于设备及玩家声音设置。主片未使用额外镜头震动。

## 精简遥测与播放性能（2026-10-21）

- 左下：车身侧滑角、行进方向与车头朝向示意、前轮转向、油门/制动条、横向和纵向 G。
- 右下：车型/驱动形式、真实车速、挡位、RPM、原厂全油门扭矩曲线和当前转速位置。
- 复用 HUD 暖白赛车字体、橙色强调色、深色斜切面板；全部原生矢量绘制，无新增栅格图片依赖。按 1280×720 基准等比适配屏幕。
- 速度、转速、挡位、输入和侧滑直接读取 60 Hz 录制遥测。G 由录制位移的对称 200 ms 窗口二阶差分、转换到车身坐标并除以 9.81 获得；与 T 调试面板一样为运动学加速度，未加静态重力项。横向向右为正，纵向加速为正。指示球显示范围 1 G，数值不裁剪。
- **扭矩是该转速下的全油门曲线值，不是当前实际输出扭矩。** 现有素材没有记录逐轮受力或实际轴端扭矩，因此没有伪造这些读数。侧滑角是车身速度相对车头的角度，不等同于单条轮胎的侧偏角。
- 仪表与车辆读取同一源片段时刻，暂停保持、跳转重算，切镜不混用两段数据。G 的窗口只在原录制片段内取样，不跨电影切镜。
- 结束页显示实际播放的帧率曲线，以及平均、最高、最低 FPS。每个 `_process` 使用单调微秒时钟测量两次画面更新间隔；平均值为帧数除以有效总时长，最高/最低为单帧耗时倒数；图中每 0.5 秒汇总，保留卡顿帧参与统计。它衡量游戏更新/渲染节奏，并非显示器扫描输出测量。
- 加载、暂停不计入；重播清空前次结果。Headless、MovieWriter、`--fixed-fps` 均不作为性能记录；无有效样本时显示空态。实测结果只代表当前设备、分辨率与设置。

相关文件：`showcase_hud.gd`、`showcase_instruments.gd`、`showcase_metrics.gd`、`showcase_results.gd`。

```sh
godot --headless --path . --script res://tests/showcase_telemetry_test.gd
godot --path . --script res://scripts/dev/showcase_performance_capture.gd -- --test-defaults
```

[带仪表的连续救车片段](telemetry-recovery.mp4) · [720p 结束页](validation/performance-1280.jpg) · [1080p 结束页](validation/performance-1920.jpg) · [本机实际播放记录](validation/playback-performance.json)
