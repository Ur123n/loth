# World 架构

## 场景结构

```
world/map/Main.tscn（根脚本 core/world/main.gd）
├── Background（ColorRect）
├── PartyEntity（Character：core/character/character.gd + CharacterVisual）
├── BattleTrigger（ColorRect + Label，脚本内构建）
├── SkillLight（core/world/skill_light.gd，未消耗时构建）
├── CharacterPanel（ui/character/character_panel.gd）
├── PartyBar（ui/character/party_bar.gd）
├── SkillPrompt（ui/character/skill_prompt.gd）
└── InventoryPanel（ui/inventory/inventory_panel.gd）
```

场景通过 `party_characters` 导出数组注入 4 名角色（ExtResource 引用 content/characters/*.tres）。

## 数据流

1. `_ready()`：GameState.setup_party → load_game → apply_path_system → ensure_basic_deck_cards；随后构建 PartyManager、实体、面板。
2. 输入分发：_input 处理面板/背包/切换；_physics_process 检测战斗触发与技能光点。
3. 状态变化（面板数据、学习技能、位置）→ GameState.save_game()。

## 与战斗的边界

- main.gd 不参与战斗规则：只负责“靠近触发点 → 保存 → 切场景”。
- BattleMap 结束后自行返回；若将来需要剧情/任务响应，应通过 BattleResult 由上层处理（见 docs/architecture.md 依赖方向）。

## NPC 现状

- NpcDB 已加载数据；尚无 NPC 场景节点与对话 UI。
- 规划：对话数据不硬编码在 NPC 脚本中（见 docs/story/architecture.md），NPC 交互走 DialogueSystem。