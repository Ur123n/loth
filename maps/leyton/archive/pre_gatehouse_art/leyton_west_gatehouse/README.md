# 莱顿 M07 西门楼结构灰盒

2026-09-27。独立Building场景 `LeytonWestGatehouse.tscn`，地基左上(85,32)，11×16格。

- 地面：176格占用、66格通道、110格实体；北/南各11×5翼楼；中央东西六格净宽门洞；两端各6格入口。
- 上层：地图x=92..94三格南北巡逻道，独立视觉和地图通行层，不写入地面可走掩码。
- 共画布624×864；Base z=0、Floor z=-1、WallWalk z=4；四周1格透明留白。
- 地面玩家z=0，墙顶玩家z=5。墙梯由地图数据指定，保持(87,49)/(93,49)，马车不能使用。
- 地面关门判定、门区动态StaticBody2D和可见遮挡由 `maps/leyton/graybox_map.gd` 的同一个gate_state驱动；独立包保存开放态的静态结构。
- 宵禁与封锁均关闭地面通道，上层巡逻不受影响；水门是独立对象，河道仍不通航。
- 这只是测量灰盒。没有正式立面、屋顶、门扇、徽记或材质，不作为完成的门楼美术交付。

## 规范源与重建

此阶段由 `maps/leyton/tools/prepare_gatehouse.gd` 维护测量几何并生成spec及三层灰盒图。修改灰盒几何应先改生成脚本，不独立编辑生成物。进入正式美术阶段再切换源图与规格维护方式。

按顺序运行（godot为项目的Godot 4.7.1控制台程序）：

1. `godot --headless --path . --script maps/leyton/tools/prepare_gatehouse.gd`
2. `godot --headless --path . --script maps/godot/tools/build_building.gd -- --id leyton_west_gatehouse --phase masks`
3. `godot --headless --path . --script maps/godot/tools/build_building.gd -- --id leyton_west_gatehouse --phase visual`
4. `godot --headless --path . --editor --import`
5. `godot --headless --path . --script maps/godot/tools/build_building.gd -- --id leyton_west_gatehouse --phase prefab`
6. `godot --headless --path . --script tests/map/test_leyton_gatehouse.gd`

运行入口 `maps/leyton/scenes/slice_test.tscn`，按7进入M07。实际截图可用 `maps/leyton/tools/run_gatehouse_capture.ps1`（后台启动并输出PID，结果在qa日志）。

完整方案/结果：`maps/leyton/GATEHOUSE_PLAN.md`、`maps/leyton/qa/GATEHOUSE_QA.md`。生成器的preview.png只显示Base翼楼，完整双层外观应看运行截图。
