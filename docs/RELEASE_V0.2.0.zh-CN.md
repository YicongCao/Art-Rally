# Art Rally v0.2.0 prerelease

v0.2.0 将原固定半径、单点合力轮胎升级为可解释的降阶动态轮胎模型。

## 轮胎与接触

- 悬架—轮胎串联径向形变和被动阻尼
- 加载半径与运动学有效滚动半径
- 载荷相关的动态椭圆接触斑
- 5 / 9 / 17 点自适应地形、材质和湿区采样
- 支撑聚类、跨沟拒绝与局部压力上限
- 接触斑感知刷子力、解析松弛和 split-μ 节点积分
- 轮胎形变、斑尺寸、压力中心、Mz、耗散功率和异常标志遥测
- F9 四轮接触斑读数和 0–2 倍只读视觉形变

标定版本为 `200ps-v2-patch1`；v0.1 成绩不会与 v0.2 混榜。

## 自动验证

- 全部快速测试与 30 / 60 / 120 FPS 回放通过
- 4 / 8 轮胎子步加速与制动差异低于 2%
- FWD / AWD / RWD × 虚拟键盘 / 虚拟手柄六组合均通过 31 门，恢复 0 次
- 六组合最大路线偏离 0.41–0.61 m
- M4 Pro、1920×1080、默认画质三次完整跑段：
  - 帧节奏 P95 约 8.35 ms
  - 总物理 P95 约 3.71–3.97 ms
  - 车辆回调 P95 约 1.47–1.48 ms

## 下载

- `Art-Rally-macos-universal.zip`：macOS arm64 + x86_64，ad-hoc 签名，未公证
- `Art-Rally-windows-x86_64.zip`：Windows x86_64，未 Authenticode 签名
- 同名 `.sha256` 文件用于校验

## Prerelease 原因

- 当前环境没有连接真实手柄，六组真人完整跑段、扳机、震动和热插拔待验收
- Windows 包可交叉导出且 PE/ZIP 结构可验证，但尚未在真实 Windows 上运行
- D3D12/Vulkan、Windows 光斑遮挡、性能和 AppData 读写待验证
- 主观听感和轮胎模型盲测待用户完成

完整公式和边界见 `docs/V0.2_TIRE_CONTACT_DEFORMATION.zh-CN.md`，自动结果见 `docs/V0.2_VALIDATION.zh-CN.md`，人工清单见 `docs/V0.2_MANUAL_ACCEPTANCE.zh-CN.md`。
