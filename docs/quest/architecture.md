# Quest 架构（规划）

## 当前状态

- QuestSystem 尚未实现；content/quests/ 目录已预留（空）。
- 无任务 UI（ui/quest/ 预留）。

## 规划结构

```
core/quest/
├── quest_data.gd      任务数据资源（阶段/条件/奖励）
├── quest_database.gd  QuestDB（Autoload）：content/quests/*.json
├── quest_system.gd    状态机：接取/推进/完成/失败，Flag 读写
└── quest_condition.gd 条件求值（复用卡牌条件系统模式）
```

## 与外部模块接口

- 上层：World（接取/交付）、Dialogue（对话选项挂任务）、Story（剧情 Flag）。
- 下层：Character/Progression（奖励）、Battle（BattleResult 驱动战斗类任务）。
- 存档：任务状态写入 GameState（save_game），不自行实现持久化。

## 实施顺序

1. QuestData/QuestDB + 状态机核心。
2. 条件与奖励接口。
3. 首个任务垂直切片（接取 → 战斗 → 交付）。