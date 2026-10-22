# 扩展车型参考与校准边界

## XPENG 新 P7 四驱（2025 车身）

用户确认四驱，银色为当前美术方案。使用新款长溜背、贯穿式灯带与低车头，不沿用老 P7/P7i 车身。拉力化包括全地形轮胎、轮拱保护、底部护板和小幅抬高。

- 官方参数：5017 × 1970 × 1427 mm，轴距 3008 mm，双电机四驱最大 437 kW / 695 N·m。功率在资源中换算为 PS，扭矩曲线同时受额定功率上限约束。
- 游戏工程假设：质量 2210 kg、轮距 1.66 m、单速总减速比 9.0、前轴基础扭矩份额 38%、回收扭矩上限 85 N·m。这些不是厂商标定数据。统一轮胎模型简化了原车前后不同胎宽；不模拟原车智驾、空气弹簧控制或电池热管理。
- 参考：[新 P7 官网](https://www.xiaopeng.com/p7n.html)、[配置表](https://www.xiaopeng.com/p7n/configuration.html)。在线检索与核对日期：2026-10-21。
- 官方照片用于观察前后与侧面比例，不是工程三视图；参考照片临时缓存未作为最终贴花进入运行时。
- 2026-10-22 重建：车身由 `scripts/create_p7_vehicle.py` 在 Blender 中按 21 个测量截面放样，保留官方长宽高与轴距。对照官网侧面照片校正：低而钝的车头与贯穿式白色灯带（下衬黑色饰带、两端竖向灯刀）、长平发动机盖、大倾角前挡、单弧溜背车顶落到短鸭尾、鸭尾下方贯穿红色尾灯、车身色 C 柱、半隐藏门把手。布尔切出真实轮拱，拉力化保留哑光轮拱护板、底护板和泥挡。挂点与原版一致，相机、车牌、尾灯和车轮物理不变。
- 高保真例外（同日）：P7 是唯一不使用屏印低多边形风格的车。车身截面加密后做一级 Catmull-Clark 细分，导出时不生成描边壳，三档 LOD 为 52.6k / 21.1k / 7.5k 三角形（P7 单独预算 90k，其余车仍为 40k）。游戏内由 `assets/shaders/hifi_vehicle.gdshader` 渲染：平滑包裹漫反射、清漆高光与天空反射，暗部沿用 Brushline 紫色阴影墨。配专用双辐条空气动力轮毂（`RallyWheelMeshes.aero_rim`）和红色卡钳。名单在 `RallyVehicleAppearance.HIFI_VEHICLES`。

## Hyundai i20 N Rally2

初代 i20 N Rally2 五门短轴距车身，蓝灰底、红色几何块、独立网格文字贴花；保留大尾翼，避免混入 Rally1 混合动力车身。

- 尺寸参考 4040 × 1820 mm、轴距 2560 mm。最低车重 1230 kg、四驱五速序列式，标称约 300 hp / 350 N·m。
- 游戏使用 300 PS 上限，是保守的游戏校准值；完整扭矩曲线、质量分布、阻尼、五挡具体比例均为工程近似。
- [Hyundai Motorsport Rally2 技术资料](https://motorsport.hyundai.com/Corporate%20Site/Car%20Spec/i20%20N%20Rally2/Hyundai%20Rally2%20Tech%20Specs.pdf)。复核时该 PDF 出现间歇性超时，参考值需随来源归档继续核对。

## Lancia Delta HF Integrale Evoluzione

方正五门宽体、四圆灯、短车尾和车顶后扰流板。深蓝车身配奶白、少量红金条带，与 WRX 明亮蓝黄区别。

- 采用 210 PS / 304 N·m、1300 kg、轴距 2.48 m 的近似量产基线，五挡四驱。模型长/宽采用约 3.90 / 1.77 m；高度与轮拱为拉力化美术近似。
- 外形版本由官方历史资料定位，具体整备重量、齿比、动态分布和曲线均为当前游戏校准，不冒充赛事认证数据。
- [Lancia 官方拉力历史](https://www.media.stellantis.com/em-en/lancia/press/lancia-synonymous-with-rally-in-the-world)。

## Mitsubishi Lancer Evolution VI（1999）

红白车身、四门三厢、前杠大进气、发动机盖散热区域和高位尾翼；参考的是 EVO VI 年代，不使用后代 EVO X 灯组。

- 游戏模型长/宽约 4.35 / 1.77 m；基线 280 PS / 373 N·m、1360 kg、轴距 2.51 m、五挡四驱；具体扭矩曲线、差速器耦合和悬架为游戏校准。
- [Mitsubishi 官方 1999 WRC 资料](https://www.mitsubishi-motors.com/jp/brand/motorsports/wrc/1999/)。赛事历史参考不等同量产 GSR 机械认证。

## Subaru WRX STI 2015（VA）

蓝车身、黄色图案、金轮圈、四门车身、大进气口和高尾翼。六挡四驱，合成声源采用不同于另外三台四缸车的脉冲结构。

- 305 SAE hp 对应约 309 PS；游戏质量 1535 kg，轴距 2.65 m、长/宽 4.595 / 1.795 m。详细曲线、轮胎、前后质量分布和减振器仍为工程标定。
- [Subaru Canada 2015 STI 规格书](https://www.pr.subaru.ca/content/7907/media/en-ca/download/2015sti_pg_en.pdf)。不同市场/配置的质量与装备有差异。

## 美术与运行时约定

- 概念图在 `concepts/`；建模预览在 `models/`；实际场景截图在 `runtime/`。模型预览来自 Godot，不能与概念图混称。
- `.blend` 为权威编辑源，独立文字/色块网格作为贴花；生成图片中的文字没有直接贴到车上。
- `scripts/create_expansion_vehicles.py` 默认保留现有源文件，`--rebuild` 仅用于明确重建 I20、DELTA、EVO6、WRX；P7 改由 `scripts/create_p7_vehicle.py` 生成，同样默认保留。导出脚本生成三档 LOD 和挂点清单。
- 菜单车型图与赛道缩略图统一由 `scripts/render_menu_models.py` 在 Blender Cycles 中渲染为透明 RGBA，八车与四赛道风格一致；源文件在 `art_source/menu_models/`。
- 新车音色是原创合成近似，不是实车录音。P7 使用电驱谐波与回收声，不播放燃油车换挡声。
- 原三车资源、物理版本、挑战键和既有演示录制保持兼容。新车型版本为 `exp1`，所有新增奖牌目标标记为未经过真人难度标定。
