# 套色拉力资产源

这些 `.blend` 是精修模型的权威源文件。游戏只读取 `assets/screenprint/` 中的 GLB。

## 日常编辑

1. 用 Blender 打开相应源文件。单位为米，Blender Z 向上；导出工具转换为 Godot Y 向上、车辆 -Z 向前。
2. 保持空节点名称和挂点位置；车身尺寸及轮系不能改变现有物理包络。
3. 保存源文件，运行 `./scripts/dev.sh screenprint-export`。单车可用 `--only=F160`。
4. 运行 `./scripts/dev.sh screenprint-check`，然后在驾驶、选车与回放中检查。

`create_screenprint_sources.py` 是一次性初始化工具，存在的源文件会跳过。`refine_screenprint_sources.py` 记录本轮带版本标记的修整。两者都不是日常导出步骤，旧 `generate_vehicles.py` 不管理本目录。

## 车辆约定

- `PlateFront/Rear`、`TailLeft/Right`、`CameraCockpit/Hood`、`WheelMount0…3` 是功能空节点。车身原点沿用物理车体原点。
- 外壳部件的 `outline` 属性决定导出时是否建立描边代理；分件内结构线由门缝等几何控制。
- `BrakeLamp` 前缀保留给刹车灯，不能随意改名。玻璃材质含 `glass`。
- 导出副本应用修饰器，生成三个 LOD 并按材质合批；不会保存或改写 `.blend`。
- 车轮局部 Y 为轴向，运行时沿用已有悬架、转向、旋转和轮胎形变。
- 设计稿十六进制色值为 sRGB，Blender Base Color／GLTF 保存对应的线性数值。不要直接把 sRGB 数字填入 Python 的 Base Color。

## 环境约定

环境源文件不带描边及碰撞。现有场景保留原碰撞代理，视觉模块单独挂载。桥面仍由原路线生成以精确匹配坡度和碰撞；Blender 桥柱模块用于细节。直升机螺旋桨、灯塔光束、帆船运动、拱门文字与布面动画仍由游戏驱动。

环境模型继续采用项目原创设计。车辆在本次用户指定的参考改造中改为 Volkswagen GTI / Red Bull、BMW M3 E30 / Mobil 1、Audi quattro S1。车身网格及几何涂装由 Blender Python 制作；品牌名称和标识来源于用户指定的赛车主题，不再声称车辆涂装不含第三方商标。未下载或导入第三方整车模型。

## 参考赛车改造

`build_reference_cars.py` 是独立、显式的一次性建模记录，只有传入 `--replace-reference-cars` 才会覆盖这三辆车的源文件。**日常修改只编辑 `.blend` 并导出，不重新运行建模脚本，避免覆盖之后的手工修整。**

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/build_reference_cars.py -- --replace-reference-cars
./scripts/dev.sh screenprint-export --only=F160
./scripts/dev.sh screenprint-export --only=R200
./scripts/dev.sh screenprint-export --only=A240
./scripts/dev.sh screenprint-check
```

内部 ID、机械尺寸、轴距、轮距、号码与机械版本均沿用旧车型。只改变外观及显示名称；导出产物不带碰撞体。参考来源、实机截图与验证记录见 `docs/art-direction/reference-cars/README.zh-CN.md`。
