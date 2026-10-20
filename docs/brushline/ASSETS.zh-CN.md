# Brushline Rally 素材与制作记录

本轮插画由 OpenAI 内置 imagegen 生成。以下是各次生成的任务规格摘要；PNG 为原始输出，未用图像处理脚本改绘。运行时通过图集区域选取、缩放和覆盖文字适配。插画不充当实机截图。

- `assets/brushline/stage-artbook.png`：1536 × 1024，三等宽旅行画册插页。秋林金草与木屋、青蓝黄金海岸与灯塔、蓝紫暮色临崖山道。复古套色、干笔刷、暖纸底；不含文字、UI、边框数据。用于赛道卡和加载插页。
- `assets/brushline/car-artbook.png`：1536 × 1024，三等宽后侧四分之三赛车画册插页。深蓝 GTI／Red Bull 16、白色 E30／Mobil 1 三色条带 27、黄白 quattro S1 44；奶油色纸面、橙红套色底。用于选车和加载页。车厂及赞助标识仍属各自权利人；未下载外部整车模型。
- `assets/brushline/key-art.png`：1536 × 1024，Brushline Rally 品牌提案，秋林、海岸和暮色山岳拼接，海报字样与扬尘赛车。用途为宣传设计参考。
- `assets/brushline/banner.png`：2172 × 724，以上主视觉的横版再创作；左侧干笔刷字样，右侧海岸赛车、秋林与紫色远山。README 使用完整 banner；游戏背景仅截取右侧景物，正式标题由 Godot 字体绘制。
- `assets/brushline/road-wear.png`：1254 × 1254，2 × 2 无文字材质图集。柏油补丁、磨损砂石、方向性泥车辙、潮湿边缘；漫射平光、无投影。shader 用固定世界 UV、稀疏区域遮罩、mipmap 和 35–95 米淡出。路面物理参数不受贴图影响。

## 精确品牌与字体

`wordmark.svg`、`icon.svg` 是字体轮廓构成的矢量资产，`generate_brushline_wordmark.py` 导出；字体为现有 SIL OFL Chakra Petch。正式游戏标题、布旗、拱门和 HUD 由同一字体体系精确排字；不依赖生图中的文字准确度。新默认车牌 `BRUSHLINE`，保留用户自定义车牌。

## Blender 权威源

`art_source/screenprint/vehicles/*.blend` 与 `props/*.blend` 是可编辑源；`assets/screenprint/` 是 GLB 交付。`build_brushline_assets.py` 保存本轮建模步骤，`refine_brushline_tail_lenses.py` 保存尾灯修整；日常只运行 `export_screenprint.py`，避免覆盖后续手工编辑。

- 三车尾部：灯罩和透镜、尾门缝／锁扣、后挡泥板、扩散器、连接杆、色带与通风口。去除原有 `RearModel` 大字。
- 新建气柱、24 片拼缝热气球、五种动物、补给棚、旗手和观众；精修直升机门外记者及肩扛摄像机、帆船支索与船舱。
- 动物 `Leg0..3` 挂点保留，运行时使用原有步态与袋鼠跳跃。旋翼和记者随已有直升机系统；帆船沿用海湾运动。
- GLB 导出按父挂点与语义材质合批，保留动画节点；三车有三档 LOD，其他 GLB 使用 Godot 导入生成网格 LOD。车辆保留墨线，环境无描边。
- 29 个导出资产的面数和挂点见 `assets/screenprint/manifest.json`。配色共享运行时材质缓存。

## 声音

补齐 `female/ROCKFALL.wav` 和 `male/ROCKFALL.wav`，沿用 Kokoro 中文生成流程及原许可；文本、声线见 `assets/audio/voice/lines.json`。落石撞地使用现有原创撞击音变调，并配空间衰减和碎尘。全部离线打包。
