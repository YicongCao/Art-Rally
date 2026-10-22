# 另一台电脑更新审查

日期：2026-10-22。审查范围：`872d364..8f1c87c`，12 个提交、89 个文件。当前工作目录和常用工程目录均已通过 fast-forward 拉到被审查版本。以下结论来自实际 diff、调用链和引擎文档；本轮没有运行测试套件或驾驶复现，也没有修改游戏实现。

## 发现

### 1. [P2] 墙体碰撞没有使用修正朝向后的三角形

位置：[redrock_scenery.gd](../../scripts/presentation/redrock_scenery.gd)，218–220、237–238 行。

`_walls()` 为左右两侧使用 `_tri(..., facing)` 修正可见网格的顶点绕序，随后却把未修正的 `[a,c,b,b,c,d]` 直接加入碰撞 `faces`。镜像侧的法线因此反向，且 `ConcavePolygonShape3D` 没有开启背面碰撞。以沿 -Z 前进的竖直墙段为例，两侧原始碰撞法线都指向 -X，而道路左侧墙面应指向 +X；车辆从路面撞向该侧时面对的是碰撞背面，会穿入可见岩壁。端部 `_cap()` 也只写入可见网格，未进入碰撞面，形成另一条入口。

建议：用已定向且含端盖的最终网格生成碰撞，或让同一个三角形生成函数同时填充渲染和碰撞数据。建议后续从左右道路侧以及墙段端部逐一检查碰撞；现有 `redrock_art_test` 只证明行车走廊没有障碍，不能证明墙面阻挡有效。

引擎依据：[ConcavePolygonShape3D 官方说明](https://docs.godotengine.org/en/stable/classes/class_concavepolygonshape3d.html#class-concavepolygonshape3d-property-backface-collision)：默认关闭背面碰撞，仅法线朝向的一侧产生碰撞。尚未实机撞墙复现，运行表现属于依据代码和该契约的推断。

### 2. [P2] 软沙物理变化仍沿用旧成绩与幽灵版本

位置：[soft_sand.tres](../../resources/surfaces/soft_sand.tres)，10–12 行。

软沙摩擦从 0.51 改为 0.66，侧向系数从 0.70 改为 0.76，已经改变制动与过弯条件；但赤岩赛道、车库试车赛段的 `stage_version`、挑战规则和车辆物理版本没有相应变更。`RallyChallengeDefinition.key()` 仍产生旧键，`RallyGarageStore.load_ghost()` 也仍接受旧物理版本及配置指纹。结果是更新前后的成绩进入同一最佳纪录桶，车库 A/B 会把环境物理变化表现成相同配置下的表现差异。

建议：为受影响赛段或物理规则更新版本并明确保留旧成绩为历史数据；幽灵可标注旧版本或拒绝作为同条件对比。不要直接清除用户旧进度。该身份碰撞由键构造和资源值可静态确认，本轮未创建或改写玩家存档。

### 3. [P2] 跨整段沙漠的植被批次使用过短的整批可见距离

位置：[desert_landmarks.gd](../../scripts/presentation/desert_landmarks.gd)，108–120、123–134 行；共用 `_batch()` 在 57 行设置距离。

仙人掌与约书亚树覆盖 930–2230 m 整段路线，却只按模型变体合并为三个/两个 `MultiMeshInstance3D`，分别使用 420 m / 380 m 可见距离。这个距离针对整批包围盒中心，不会按每株植物计算。驾驶到整段首尾时，摄像机即使贴近某株植物，仍可因远离整批中心而让整批消失；反向接近时也会一起出现。当前只检查植被实例数量，无法覆盖这一显示问题。

建议：参考同文件组中原有 `RallyRedrockScenery._plants()` 的按里程分块方式，把新植物按空间或 150–250 m 路段分批，再应用距离剔除。后续需沿 930 m 和 2230 m 两端连续驾驶检查淡入淡出；本轮尚未逐帧实机确认出现位置。

引擎依据：[Visibility ranges 官方说明](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html#visibility-range-properties)：End 使用摄像机到实例 AABB 中心的距离。

## 范围与完成状态

- 已审查赤岩景观/碰撞、沙地参数、P7 建模与材质导出、车轮与幽灵、车库/演示原生像素尺寸、菜单素材生成和新增测试覆盖。
- 常用目录 `/Users/cong/Documents/Projects/Art-Rally` 的 Godot 4.7.2 资源导入成功，导入日志未见 ERROR/WARNING；日志保存在本机 `/tmp/brushline-pull-import.log`。
- 本轮仅拉取、静态审查和记录结果，没有运行自动驾驶、回归测试或性能复测。远端文档里的通过数量和 M4 Pro 性能数据不是本机本轮验证结果。
- 未实施上述修复。P7 取消黑描边并使用独立精细材质是这些提交明确表达的美术选择，未把它作为代码缺陷。
