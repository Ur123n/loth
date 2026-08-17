# Character 模块

角色属性、HP、成长、技能库、队伍管理，以及道途（成长）与装备/物品数据。

## 是什么

- **core/character/** — `character.gd`（大世界角色实体）、`character_data.gd`（CharacterData 资源）、`skill_data.gd`、`party_manager.gd`（四人队伍切换）、`character_visual.gd`
- **core/progression/** — `path_data.gd` / `path_database.gd`（PathDB）/ `passive_data.gd`：道途与被动
- **core/equipment/**、**core/items/** — 装备/物品数据类与数据库、背包（Inventory）
- **content/characters/**（.tres）、**content/paths/**、**content/equipment/**、**content/items/** — 角色/道途/装备/物品数据
- **ui/character/**、**ui/inventory/** — 角色面板、队伍条、装备面板、技能提示、背包界面

## 文件地图

| 文件 | 职责 |
| --- | --- |
| core/character/character_data.gd | 角色数据资源（属性/HP/经验/卡组/技能库/装备/道途） |
| core/character/character.gd | 大世界实体：移动、输入、套用角色数据 |
| core/character/party_manager.gd | 队伍：当前角色、切换、选中信号 |
| core/character/skill_data.gd | 技能库条目 |
| core/progression/path_data.gd | 道途数据（专属初始牌/被动/美术） |
| core/progression/passive_data.gd | 被动效果数据 |
| core/equipment/equipment_data.gd | 装备数据（部位/属性修正） |
| core/items/item_data.gd | 物品数据（形状/价值） |
| core/items/inventory.gd | 背包（按形状占格） |
| ui/character/character_panel.gd | 角色面板（属性加点/卡组/技能/装备） |

## 规则与实现文档

- [rules.md](rules.md) — 属性、成长、道途、装备规则
- [architecture.md](architecture.md) — 数据流与类关系