# 75 秒 Demo：速度、救车与沿途风景

主菜单 → **玩法演示**。准备三赛道完成后开始计时，75 秒到结束页；“再看一次”复用已加载场景。空格、Esc 或手柄 Start 暂停 / 继续。

- [分镜图册与完整影片](index.html)
- [75 秒实机录像](demo-75s.mp4)（720p / 60 FPS / 4,500 帧，含音轨）
- [侧拍 5 秒](side.mp4)、[救车 12 秒](recovery.mp4)
- [逐镜头实测与碰撞扫描](validation/metrics.json)
- [分镜清单](../../../resources/showcase/film.json)和同目录七份真实驾驶录制

## 成片结构

00–05 秋色俯拍；05–11 低位追车；11–16 固定侧拍与制动；16–28 后驱外甩与救车；28–34 驯鹿横穿。34–40 海湾全景；40–46 引擎盖；46–54 770 m 河桥；54–60 直升机伴飞。60–66 高地悬崖；66–72 头灯与琥珀光柱；72–75 拉远淡出。

进入赛道时短显名称，隐藏 HUD、遥测和悬浮检查点符号，保留世界光柱。跨赛道 0.4 秒叠化计入总时长。音乐贯穿，引擎转速、负载和轮胎声跟随遥测。最终 12 张预览取自交付录像。

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

专项 91 项与相关回归 149 项通过；日志位于 `validation/`。验证包含全场景碰撞扫描、真实位移 / 速度一致性、救车遥测、30 / 60 / 120 FPS 轨迹连续性、键盘和模拟手柄输入、暂停、事件重现、无存档修改、结束与复用场景重播。实际检查 720p、1080p 菜单布局；实体手柄未额外测试。

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
