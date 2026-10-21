# Brushline Rally — 素材与工具名单

- 游戏、程序地景及 Blender 网格自主制作；现有赛车依用户指定的真实车型及赛车涂装参考建模，品牌权利归各自权利人，不含外部下载的整车模型。
- 主菜单、金银铜奖牌及赛道符号 SVG 图标、三主题矢量场景插画：项目原创，源文件位于 `assets/ui/icons/` 与 `scripts/game/menu_backdrop.gd`。
- 专属车牌输入、预览和三维文字共用 Chakra Petch Bold 英文／数字字形及 Noto Sans SC 中文回退，不依赖系统字体。
- 车辆可编辑源：`art_source/vehicles/*.blend`，导出：`assets/vehicles/*.glb`，可用 `blender --background --python scripts/generate_vehicles.py` 重建。
- 音效与音乐（不含语音路书）：项目原创程序合成，生成脚本 `scripts/generate_audio.py`、`scripts/generate_music.py`、`scripts/generate_flag_sweep.py`；标题与三赛道的四首原创配乐同时保存 MIDI 源和离线 WAV。没有外部录音、在线音源或 Kenney 资源混入包内。
- Godot Engine：MIT，https://godotengine.org/license/ 。运行时许可与第三方依赖名单见随包 `Godot-LICENSE.txt`、`Godot-THIRD-PARTY.json`。
- Jolt Physics：Godot 自带物理后端，依其打包许可分发。
- Noto Sans SC / Noto Sans Mono：SIL Open Font License，原文见 `assets/fonts/` 随附许可。
- Blender：仅用于源资产制作，不随游戏打包。

项目原创资产的分发遵循项目所有者许可；第三方字体和引擎保持原许可。

- Chakra Petch Bold — Chakra Petch Project Authors, SIL OFL 1.1; `assets/fonts/OFL-ChakraPetch.txt`, https://github.com/google/fonts/tree/main/ofl/chakrapetch .
- 直升机、肩扛摄像记者、方格充气拱门、驯鹿、熊、斑马、鸵鸟、袋鼠、气球、海鸥、河流、桥梁、电线杆与架空线均为项目原创程序网格；上述音效与配乐不使用第三方采样或 soundfont。

- 中文语音路书：使用 [hexgrad/Kokoro-82M-v1.1-zh](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh) 的 `zf_001` / `zm_010` 合成，模型许可 Apache-2.0，许可文本见 `assets/audio/voice/LICENSE-Kokoro.txt`。模型卡说明中文训练数据由龙猫数据许可提供。生成脚本 `scripts/generate_pacenotes.py` 与逐句文本／声线清单 `assets/audio/voice/lines.json` 随仓库保存；游戏只打包 WAV，不包含模型或推理依赖，不需要联网。
- 河流水声、旋翼声与蹄声：项目原创合成，脚本 `scripts/generate_world_audio.py`。

## 套色拉力原创资产（2026-10-19）

- 三车新造型、涂装、轮系、描边代理及功能挂点：Blender 原创模型；权威源文件 `art_source/screenprint/vehicles/`，游戏 GLB 位于 `assets/screenprint/vehicles/`，独立视觉版本 `screenprint-1`。
- 木屋、灯塔、桥柱模块、直升机及记者摄像机、保障车、帆船、气球拱门与锚固件、AT 胎与五辐轮毂：原创 Blender 源文件 `art_source/screenprint/props/`。
- `scripts/export_screenprint.py` 从已保存的源文件生成 GLB、三档车身 LOD 和面数／挂点清单，不回写源文件。`create_screenprint_sources.py` 为一次性初始化；`refine_screenprint_sources.py` 记录本轮有版本标记的修整，不属于日常导出步骤。
- 套色材质、赛车专用墨线、UI 纸面印刷 shader 和矢量版式：项目原创代码。未引入外部品牌、赞助标识、贴图或字体。
- 方向参考图由内置 image_gen 生成，仅用于设计讨论；实际游戏继续使用原创三维资产和代码绘制 UI。

## 0.4.0 实际使用的美术资产

- 三辆参考赛车由项目 Blender 脚本自主建模，参考用户提供的 GTI／Red Bull、M3 E30／Mobil 1 和 quattro S1 照片与涂装要求；没有导入第三方下载的整车模型。车厂、车型与赞助名称及标识归各自权利人所有。
- 漫画 HUD 外壳、金色弯道箭头 atlas（`assets/ui/comic_hud/atlas.png`）和手绘云带（`assets/sky/comic/cloud-banks.png`）使用内置 image_gen 生成并实际随游戏打包；原始透明 RGBA 保留，裁区、镜像与色调适配由运行时代码完成。提示词及来源记录见仓库 `docs/art-direction/comic-hud/imagegen-prompts.md`。

## Brushline Rally 开发验证版（2026-10-21）

新增品牌、画册及路面插画由内置 imagegen 生成；权威矢量字标、Blender 源文件、导出流程、动画挂点和逐项用途见 [本轮素材记录](brushline/ASSETS.zh-CN.md)。上方早期“无品牌／纯程序网格”描述仅适用于对应历史阶段；当前实际内容以 0.4.0 和本节记录为准。


## 0.5.0 制作署名与指南

- 引擎：Godot Engine；物理：Jolt Physics。
- 创意设计：Pixelcao；制作人：Pixelcao。
- 领航语音：合成语音（既有 Kokoro 离线素材与对应许可保留）。
- 代码生成：Codex。
- 操作指南：透明 SVG 手柄轮廓、Godot 原生矢量键盘与动态标注；由本项目代码绘制，无新增外部图片依赖。


## 赤岩峡谷与自由车库扩展（2026-10-21）

- 五辆新车均为项目自主制作的 Blender 网格，未导入第三方整车模型。车型与商标参考来自厂商资料，车厂、车型及赞助名称属于各自权利人；参考与工程假设见 [车型卡](expansion/VEHICLES.md)。
- `art_source/screenprint/vehicles/{I20,DELTA,EVO6,WRX,P7}.blend` 为权威源，独立文字和色块网格可编辑；运行时每车三档 GLB。生成/导出脚本及挂点清单随项目保存。
- 地图、车库、五车概念由内置 imagegen 生成，保存于 `docs/expansion/concepts/`，只作设计参考。实际环境、车库货架、安装动画和 UI 由项目网格与代码实现。
- 五车声音由 `scripts/generate_expansion_audio.py` 原创合成，不包含实车录音或第三方音频采样。赤岩峡谷目前复用已有高地配乐与风声。
- 沙地中文提示使用既有 Kokoro 声线与许可生成，逐句记录已追加到 `assets/audio/voice/lines.json`。
