# World 规则

## 1. 大世界移动与操作

- WASD 四向移动；地图上只有一个实体：当前选中的角色代表整个队伍。
- ↑/↓ 切换队伍角色（PartyManager）；Tab 打开角色面板；B 打开背包。
- 面板/背包打开时暂停移动与事件触发。

## 2. 战斗触发

- 大世界配置一个战斗触发点（battle_trigger_position + radius）。
- 角色进入半径即触发：保存当前世界位置 → 切换到 `world/encounters/BattleMap.tscn`。
- 触发点消耗后，离开一定距离才重新武装（避免返回时立即再次触发）。

## 3. 技能光点

- 光点位置/是否已学习由 GameState 持久化（skill_light_position / skill_light_consumed）。
- 靠近光点弹窗询问是否学习“冲锋”（当前演示技能）；选择“否”后 2 秒冷却不再触发。
- 确认后技能加入当前角色技能库并写档。

## 4. 场景切换

- 大世界 → 战斗：main.gd 保存位置并切换场景。
- 战斗结束 → 大世界：battle_map.gd 切回 `res://world/map/Main.tscn`；Demo 模式切回 `res://demo/DemoHub.tscn`。

## 5. NPC

- NPC 数据（content/npcs/*.json）由 NpcDB 加载：name/description/color/ai/interaction/dialogue/美术接口。
- 互动选项与对话树字段已存在；NPC 场景交互与对话系统尚未实现（规划见 docs/story/ 与 docs/quest/）。

## 6. 存档

- 大世界位置、触发点状态、光点状态统一由 GameState 保存（user://savegame.json）。
- 进入战斗前保存位置；战斗结算/面板修改即时写档。