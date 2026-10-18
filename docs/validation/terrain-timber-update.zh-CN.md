# 弯外圆木、分散路面起伏与树木贴地

2026-10-18；Godot 4.7.2，Apple M5，原生 Metal Forward+。

## 内容与实现

- 松岭在 530 / 720 / 1760 / 2350 m，高地在 430 / 1190 / 1910 / 2390 m 的弯道外侧布置圆木；海岸不增加圆木。每堆底层至顶层为 4 / 3 / 2 / 1，共十根，约 4.8 m 长、直径 0.64 m。采用低多边形树皮、裂口和程序生成的同心年轮切面，两端均有年轮。
- 圆木沿局部路面坡度放置，靠道路的一侧保留约 1 m 路肩余量。每根使用圆柱碰撞，接入车辆障碍碰撞层；附近植被让出位置。路书新增 LOGS：矢量圆木／禁切图标、简短文字“圆木障碍 · 勿切”，以及男女声“圆木障碍，不要切弯”。语音使用项目原有 Kokoro 配音流程，来源和生成记录写入原清单；全部随游戏离线打包。
- 去掉原来沿整条路线连续存在的小幅正弦扰动，改用固定位置的稀疏起伏区。松岭 8 处、高地 9 处、海岸 4 处，名义幅度 3.5–5.5 cm；只作用于非柏油路面并在区段两端平滑收敛。路面混合边界按原材质权重衰减；起终点、桥面和桥引道、既有飞坡保持独立设计。
- 部分弯道分别加入有利横坡与反向横坡，外侧边缘相对中心高／低约 10–14 cm。横坡和起伏均写入同一个可见／碰撞三角网格，由现有轮胎接触与悬架响应，没有按弯道类型偷偷改写车辆速度或抓地力。
- 远景植被原先从连续高度函数取点，实际地形却是 8 m 网格，陡坡上的插值差会让树根离地。现在直接按实际绘制的三角形插值定位；近路装饰也使用道路三角形插值。额外剔除近乎垂直崖壁上的树，近景／远景 LOD 共享正确落点。
- 地形版本从 5 更新到 6，旧成绩、幽灵和新几何隔离；保留旧存档内容与已获得的动力解锁。

## 验证记录

新增 terrain_detail_test：56 项检查，覆盖十根圆木的碰撞、车辆层实体运动不能穿透、障碍路书与可切弯提示不冲突、正负横坡、稀疏起伏比例、桥面与柏油平顺、可见道路与碰撞重合、植被根部与地形网格一致。对实际渲染网格额外生成测试碰撞，以独立射线验证树根高度，而非只比较同一个高度函数。

| 赛道 | 非柏油路面有明显扰动的比例（单侧轮迹，超过 5 mm） | 轮迹实测最大起伏 | 远处被检查的树木 |
| --- | ---: | ---: | ---: |
| 松岭 | 11.4% | 4.54 cm | 1503 |
| 海岸 | 23.8% | 3.72 cm | 157 |
| 高地 | 11.0% | 4.54 cm | 1490 |

共 507 项断言通过（不重复计算复测）。三条赛道标准 F160 完整自动驾驶回归均正常完赛、0 次恢复：松岭 257.383 秒，海岸 213.733 秒，高地 271.058 秒。原始结果见 [整段回归数据](terrain-f160-routes.json)。

常规回归：stage_geometry、stage_art、route_revision、content_catalog、stage_session、hud、experience_update、profile_ghost、power_progression、bridge_hop 全部通过。语音测试同时校验实际资源路径与最后播放指令，避免旧音频残留导致假通过。

原生 720p／1080p 截图使用隔离存档，检查圆木年轮、四层排列、落地、正常道路余量、路书图标文字与高地山坡。截图中的 HUD 数值为受控展示，不作为驾驶数据。

- [松岭圆木](../previews/terrain-sunset_ridge-timber.jpg)
- [高地圆木](../previews/terrain-misty_highlands-timber.jpg)
- [高地路书提示](../previews/terrain-misty_highlands-approach.jpg)
- [修正后的高地树木](../previews/terrain-highland-grounded-trees.jpg)

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 120 --script res://tests/terrain_detail_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 120 --script res://tests/first_playable_matrix.gd -- --test-defaults --tier=0 --vehicle=F160
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://scripts/dev/terrain_detail_capture.gd
```

本次验证不替代真人手感与 Windows 实机验收，也没有重新发布安装包。
