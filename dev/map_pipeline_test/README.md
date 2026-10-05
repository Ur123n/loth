# 地图架构第一阶段实验场

入口：`res://dev/map_pipeline_test/map_pipeline_test.tscn`

本场景只验证架构，不迁移正式大地图。运行时包含：

- 48px Terrain TileMap 地面与道路；
- `house_a` 完整小屋 Pattern（一次实例化，不逐 Tile 重搭）；
- `iserra_monastery` 大型建筑 PackedScene（完整视觉、独立碰撞、Anchor、Roof）；
- `roadside_rock` 自由 Prop（不是 TileMap 单元）；
- 与建筑同一 YSort 域的玩家；
- E 键进入独立 `interior_test.tscn`，南门返回；
- 大型建筑 Ghost：半透明视觉、Footprint 网格、Anchor、Entrances、合法性颜色。

操作：WASD 移动，E 交互，F 切换现有建筑屋顶，G 切换 Ghost，移动鼠标更新 Anchor，左键在合法位置做仅本次运行的放置，R 复位。

持久化地图编辑仍使用 `maps/godot/tools/building_tool.gd`；Ghost 的运行时放置不会写正式场景。

