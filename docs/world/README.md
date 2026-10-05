# World 模块

大世界地图、地点、场景切换与 NPC（世界实体）。当前实现为“垂直切片”大世界：移动、角色切换、战斗触发点、技能光点、NPC 数据。

## 是什么

- **world/map/Main.tscn** — 大世界主场景
- **maps/godot/** — 唯一地图管线（**48×48 黑暗奇幻**：素材 → TileSet → 手绘 `.tscn`，带图块语义、地形集与标记）；见 [map_pipeline.md](map_pipeline.md)
- **world/map/MainGodotMap.tscn** — 管线地图的接入演示入口（大世界底图 = `maps/godot/scenes/abbey_outskirts.tscn`）
- **dev/map_pipeline_test/** — 地图架构第一阶段实验场：Terrain、Pattern、大型建筑、自由 Prop、Door/Interior、Ghost/Anchor 的统一验收入口
- **core/world/** — `main.gd`（大世界逻辑）、`map_scene.gd`（管线地图的尺寸/倍率/标记/通行性接口）、`skill_light.gd`（技能光点）、`npc_data.gd` / `npc_database.gd`（NPC 数据与数据库）
- **world/encounters/BattleMap.tscn** — 战斗遭遇场景（从大世界触发点进入）
- **content/npcs/** — NPC 数据（JSON，Excel 同步）
- **core/save/game_state.gd** — 大世界位置/触发点状态持久化

## 文件地图

| 文件 | 职责 |
| --- | --- |
| core/world/main.gd | 大世界：WASD 移动、角色切换、Tab 面板、B 背包、战斗触发、技能光点 |
| core/world/map_scene.gd | 地图场景接口（`MapScene`）：图层约定、标记坐标、`is_walkable()`、结构自检 |
| core/world/map_pattern_library.gd | 小型完整建筑 Pattern 数据库与一键场景 Stamp 放置 |
| core/world/map_pattern_instance.gd | Pattern 实例语义：id、footprint、anchor、入口与 Interior |
| core/world/free_prop.gd | 自由 Prop：底部 Anchor、独立 footprint 与碰撞 |
| core/world/scene_door.gd | 外部/室内场景门：目标场景与交互式切换 |
| core/building/building_ghost.gd | 大型建筑放置预览：视觉、Footprint 网格、Anchor、Entrances 与统一合法性校验 |
| core/world/skill_light.gd | 技能光点（靠近询问是否学习技能） |
| core/world/npc_data.gd | NPC 数据资源（描述/互动/对话） |
| core/world/npc_database.gd | NpcDB（Autoload）：content/npcs/*.json |
| world/map/Main.tscn | 主场景（四人队伍资源注入 party_characters） |
| world/map/MainGodotMap.tscn | 同上，大世界底图指向 48px 示例地图（接入演示） |

## 规则与实现文档

- [rules.md](rules.md) — 世界规则（移动/触发/场景切换/NPC）
- [architecture.md](architecture.md) — 场景结构与数据流
- [map_pipeline.md](map_pipeline.md) — **地图制作管线**（本地素材 + Godot 地图编辑器：图块集生成、图层/标记约定、校验与接入）
- [npc_schedule.md](npc_schedule.md) — NPC 行动轨迹（时间轴）

第一阶段实验场运行与验收见 `dev/map_pipeline_test/README.md`；自动测试为 `tests/map/test_map_pipeline_phase_one.gd`。

## 现有地图版本更迭（Codex）

[伊瑟拉修道院与莱顿城操作指南](version_guides/README.md)：核对活动版本、改材质/布局、候选验证、替换与回退。修道院现有贴图已获用户允许更换。
