# Quest 架构（已实现）

## 当前状态

- QuestSystem 已实现：`core/quest/` 四个脚本 + Autoload（QuestDB / QuestSystem）。
- 无任务 UI（符合设计：无任务栏/无提示）。
- content/quests/ 已填充示例分支链（修道院委托 → 花园/厨房分支）。

## 结构

```
core/quest/
├── quest_data.gd        QuestData：id/name/description/start/complete/rewards/next/branches
├── quest_condition.gd   QuestCondition：条件求值 + 校验（纯逻辑，无 UI 依赖）
├── quest_database.gd    QuestDB（Autoload）：读取 content/quests/*.json，输出问题列表
└── quest_system.gd      QuestSystem（Autoload）：状态机/自动推进/分支/奖励/信号
```

- 数据类脚本通过 `preload` 互相引用（不依赖全局 class 缓存，无头测试与新建文件均可用）；
  `quest_data.gd` 的 `from_dict` 用 `load("res://...")` 自实例化。
- QuestSystem 不保留 class_name（与 Autoload 同名会冲突）。

## 状态与存档

- 状态全部写入 `GameState.quest_state`：`active`（当前任务）、`done`（已完成）、
  `talked`（交谈过的 NPC）、`battles_won`（战斗胜利数）。
- 经 `GameState.save_game()` 持久化（v5 起预留，v6 增加 world_time），不新建存档通道。
- 世界时钟：`GameState.world_time`（小时 0-24，v6），`advance_world_time()` 推进。

## 与外部模块接口

- 上层：World（main.gd 定时 check_advance + NPC 交互 notify_npc_talked）、
  Dialogue/Story（置 Flag → flag_changed → 自动检查）。
- 下层：Battle（BattleMap 胜利 → notify_battle_won）、Character/Progression/Items/
  Card（奖励发放经对应 DB + GameState）。
- 信号：`quest_started(id)`、`quest_completed(id, result)`（result.texts 为线索文案）。

## 实施记录

1. QuestData/QuestDB + 状态机核心（v1）。
2. 条件与奖励接口（v1）。
3. 示例垂直切片：接取（npc_talked）→ 收集（item_count）→ 分支（flag/always）→
   后续任务（battle_won / world_time），`tests/quest/test_quest_system.gd` 全绿。
