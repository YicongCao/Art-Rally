# 可复核证据

- `suites.json`：87 个项目测试套件的最终结果及本地原始日志名。初跑发现的旧目录数量、五/六/单速假设、无树沙漠场景断言均已按实际内容修正并复跑；未以测试绕过实际动力或成绩隔离。
- `parse.json`：全部 GDScript 解析结果。
- `frame-rates.json`：P7 沙地改装配置在 30/60/120 FPS 下、固定物理输入的轨迹与速度。
- `audio.json`：25 个原创音色循环的长度、峰值和接缝幅度。P7 idle 有意静音。
- `matrix.json`：96 个固定组合全部完赛、零复位。
- `performance.json`：同机基线/扩展三次交替采样，以及赤岩 P7 的原生 1080p 采样。

完整原始运行日志保留在工程忽略目录 `logs/expansion/`。矩阵的物理耗时是在并行自动跑段期间采集，不能当作单机独占帧率；性能比较使用单独的原生 1080p 探针。

## 重跑

```sh
./scripts/dev.sh check
godot --headless --path . --fixed-fps 120 --script res://tests/first_playable_matrix.gd -- --test-defaults
for fps in 30 60 120; do
  godot --headless --path . --fixed-fps "$fps" --script res://scripts/dev/expansion_frame_probe.gd
done
godot --path . --fixed-fps 60 --disable-vsync --max-fps 0 --script res://scripts/dev/expansion_perf_probe.gd -- --test-defaults
```

性能探针脚本也兼容扩展前的 `002438d` checkout：把 `--path` 指向基线工程，并把 `--script` 写为当前脚本的绝对路径，使用相同机器和画质运行。探针排除加载、预热 180 帧，采集接下来 600 帧，采用固定模拟步长；它是短样本，不代表全赛道最低帧率。
