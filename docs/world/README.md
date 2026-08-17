# World 模块

大世界地图、地点、场景切换与 NPC（世界实体）。当前实现为“垂直切片”大世界：移动、角色切换、战斗触发点、技能光点、NPC 数据。

## 是什么

- **world/map/Main.tscn** — 大世界主场景
- **core/world/** — `main.gd`（大世界逻辑）、`skill_light.gd`（技能光点）、`npc_data.gd` / `npc_database.gd`（NPC 数据与数据库）
- **world/encounters/BattleMap.tscn** — 战斗遭遇场景（从大世界触发点进入）
- **content/npcs/** — NPC 数据（JSON，Excel 同步）
- **core/save/game_state.gd** — 大世界位置/触发点状态持久化

## 文件地图

| 文件 | 职责 |
| --- | --- |
| core/world/main.gd | 大世界：WASD 移动、角色切换、Tab 面板、B 背包、战斗触发、技能光点 |
| core/world/skill_light.gd | 技能光点（靠近询问是否学习技能） |
| core/world/npc_data.gd | NPC 数据资源（描述/互动/对话） |
| core/world/npc_database.gd | NpcDB（Autoload）：content/npcs/*.json |
| world/map/Main.tscn | 主场景（四人队伍资源注入 party_characters） |

## 规则与实现文档

- [rules.md](rules.md) — 世界规则（移动/触发/场景切换/NPC）
- [architecture.md](architecture.md) — 场景结构与数据流