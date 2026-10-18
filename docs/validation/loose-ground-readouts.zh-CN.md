# 松软路面动力与仪表读数调整

日期：2026-10-18。Godot 4.7.2，Apple M5；画面用原生 Metal Forward+ 检查。

## 实现

- 三车基础动力增加 20%：F160 192 PS、R200 240 PS、A240 288 PS；进阶／极限组仍按 1.5／2.0 倍计算，选车页显示实际 PS。
- 砂石摩擦系数 0.76 → 0.84，泥地 0.48 → 0.64，草地／土路肩 0.68 → 0.75；柏油、积水的速度损失和路面过渡逻辑不变。
- 旧自动变速箱用实际路速阻止空转升挡，但满油门松软坡地会持续红线打滑。正式车辆现在依据有载驱动轮的滑移渐进调低发动机输入，保留约 18% 的目标滑移；低转速保护自动离合器起步区间，恢复抓地后平顺归还油门。没有强制改写轮速、车速或转速。
- 松软路面升挡目标 6200 rpm、实际路速转速比例 0.82；原有离地、手刹、制动、离合器滑差和真实路速限制保留。手动模式保留玩家选择的挡位。
- 标定版本从 fp2 更新到 fp3，旧成绩和幽灵仍保存在原键下，不与新动力成绩比较；已获得的动力解锁保留。奖牌目标尚未重新真人标定；仅按要求删掉加载页的“暂定”字样，没有伪造已标定状态。
- HUD 与驾驶舱时速均为最少两位，按实际文字宽度居中。三条赛道各使用已有的三个近似等距分段（约 1/3、2/3、终点）；HUD 改读取 split_times，不再读取每个检查点的 gate_times。提示位于顶部中央、路书下方，保留两次闪烁、停留、渐隐和历史最快分段差。
- 检查点图标与文本按共同中心对齐。车牌字号目标增加 20%，长文本以车牌框每侧至少 10% 留白为上限自动缩放。

## 物理复现与回归

基线为修改前的 7409bae。独立物理试验使用 10% 上坡、真实轮胎接触、直接满油门，不经过自动驾驶油门辅助。

| F160 工况 | 修改前 20 秒车速 | 修改后 20 秒车速 | 修改后结果 |
| --- | ---: | ---: | --- |
| 砂石坡 | 50.96 km/h | 61.37 km/h | 二挡，后段平均滑移 0.178 |
| 泥地坡 | 9.15 km/h | 33.53 km/h | 40 秒达 42.60 km/h，后段平均滑移 0.182，无持续红线空转 |

泥地陡坡 F160 仍可能处于一挡，但可以持续加速，不靠虚假的强制升挡掩盖牵引力限制。R200 / A240 在相同试验中也通过砂石 20 秒、泥地 40 秒回归。原始数据见 [修改前](loose-climb-before.json) 与 [修改后](loose-climb-after.json)。

标准 F160 高地整段自动驾驶回归：271.175 秒完成、0 次恢复，累计分段时间 86.250 / 183.950 / 271.175 秒；未写入玩家纪录。见 [完整赛道结果](highland-f160-fp3.json)。这不是真人驾驶手感验收或独立性能基准。

## 验证

共 534 项断言通过：drivetrain、power_gearing、power_progression、content_catalog、surface、hud、experience_update、plate_identity、first_playable_flow、profile_ghost、stage_session、loose_climb，以及 6 项动力辅助边界检查与高地完整跑段 3 项检查。

覆盖空转不误升挡、手动挡保持、离地保护、低转速起步、回柏油恢复动力、坡地持续加速、三段距离划分、普通检查点不弹分段、分段差与重跑重置、长车牌边距、加载文案和存档隔离。新增边界测试最初使用了错误的路面测试类型，已改为 RallySurfaceSample 并重跑通过。

原生截图使用隔离存档，静音仅限截图进程；720p / 1080p 的 07、99、100 均检查，驾驶舱 07 / 100、短车牌、十位英文与中英混合车牌、加载页均检查。截图为受控 HUD 数值展示，不作为实际驾驶速度证据。

- [720p HUD](../previews/readout-hud-720-7.jpg)
- [1080p HUD](../previews/readout-hud-1080-100.jpg)
- [驾驶舱](../previews/readout-cockpit-100.png)
- [长车牌](../previews/readout-plate-10W.jpg)
- [加载页](../previews/readout-loading.jpg)

复现命令：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 120 --script res://tests/loose_climb_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 120 --script res://tests/first_playable_matrix.gd -- --test-defaults --tier=0 --stage=misty_highlands --vehicle=F160
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://scripts/dev/readout_capture.gd
```

本次没有重发发行包，没有进行 Windows 实机或实体手柄验收。
