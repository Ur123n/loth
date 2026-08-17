# Character 架构

## 类关系

```
GameState (Autoload, core/save/game_state.gd)
  └── party_characters: Array[CharacterData]
        └── deck: Array[CardData]（来自 CardDB）
        └── skill_library: Array[SkillData]
        └── path_name / equipment…

PartyManager (core/character/party_manager.gd)
  └── setup(characters) / select_next / select_previous / character_selected 信号

Character (core/character/character.gd) — 大世界实体 Node2D
  └── apply_character_data(CharacterData) → 更新外观/占位
  └── CharacterVisual（core/character/character_visual.gd）

PathDB (Autoload, core/progression/path_database.gd)
  └── content/paths/*.json → PathData（name/character/passive/starter_cards）

EquipDB / ItemDB / Inventory（core/equipment、core/items）
```

## 数据流

1. 启动：GameState.setup_party → load_game → apply_path_system（道途 + 专属初始牌）→ ensure_basic_deck_cards（补齐基础牌）→ save。
2. 角色面板（ui/character/character_panel.gd）显示属性/卡组/技能/装备；加点、改牌组等操作即时写档（data_changed 信号 → GameState.save_game()）。
3. 战斗：CharacterData 提供给 BattleMap 生成玩家单位；成长（经验/属性点）在战斗结算时经 GameState 写档。

## 装备系统现状

- EquipmentPanel 显示 8 槽位（头部/身体/腿部/足部/首饰×2/左右手），点击已穿装备卸下回背包；
  背包点击装备物品穿到当前角色（槽位被占先卸旧装备，背包无空位则取消）。
- 数据模型：EquipmentData.mods（type/value/stat），正修正=得、负修正=舍（有舍有得，见 GDD 第 14 节）。
- 合并链路：CharacterData 提供 equip/unequip_slot、get_effective_*、get_equipment_mod_total；
  BattleUnit/TurnSystem/BattleManager/BattleMap 使用合并后属性与修正
  （HP、伤害基数、行动值、移动力、攻击范围、抽牌/费用、回合开始格挡、防御卡格挡）。
- 存档：装备按名称随角色持久化（save version 3；旧档缺省为空，读档由 EquipDB 还原）。

## 存档协作

- 角色成长、卡组、技能库、道途由 GameState 统一持久化（user://savegame.json），其他系统不自行实现存档。
