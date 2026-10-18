# Art Rally — 素材与工具名单

- 游戏与车辆设计、原创涂装、程序地景：Art Rally。没有汽车厂商标志、真实赞助商或第三方车型模型。
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
- 直升机、记者、气球、海鸥、河流、桥梁、电线杆与架空线均为项目原创程序网格；上述音效与配乐不使用第三方采样或 soundfont。

- 中文语音路书：使用 [hexgrad/Kokoro-82M-v1.1-zh](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh) 的 `zf_001` / `zm_010` 合成，模型许可 Apache-2.0，许可文本见 `assets/audio/voice/LICENSE-Kokoro.txt`。模型卡说明中文训练数据由龙猫数据许可提供。生成脚本 `scripts/generate_pacenotes.py` 与逐句文本／声线清单 `assets/audio/voice/lines.json` 随仓库保存；游戏只打包 WAV，不包含模型或推理依赖，不需要联网。
- 河流水声、旋翼声与蹄声：项目原创合成，脚本 `scripts/generate_world_audio.py`。
