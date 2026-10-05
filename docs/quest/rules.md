# Quest 规则（已实现）

任务系统负责：任务状态、任务条件、任务奖励、任务分支、自动推进。

## 核心设计（与 GDD/玩家体验一致）

- **没有任务 UI**：没有任务栏、任务日志、任务提示。任务状态只记录在角色/存档
  （`GameState.quest_state`，随存档持久化），玩家只能通过 NPC 对话与文本获得
  线索与奖励信息。
- **自动推进**：当前任务的完成条件满足后，QuestSystem 自动完成并推进到下一任务，
  玩家不需要手动“交任务”。
- **分支任务**：任务完成时按完成时满足的前置条件（branches 按顺序取首个满足）进入
  不同后续任务；没有分支命中时用默认 `next`。
- **奖励与线索由 NPC 和文本提供**：`rewards` 中的 `text` 与 `description` 承载线索/
  奖励说明；NPC 对话树（content/npcs/*.json）提供剧情线索。

## 状态机

```
无任务 →（start 条件满足）→ 进行中（active）→（complete 条件满足）→ 已完成
                                                    → 分支/next → 下一任务进行中
```

- 一次只推进一个任务（`quest_state.active`）。
- 完成记录在 `quest_state.done`（数组），已完成任务不会重复接取。
- 条件满足由 `check_advance()` 自动检查（见触发点）。

## 条件类型（content/quests/*.json 的 start/complete/branches[].when）

| type | 字段 | 说明 |
| --- | --- | --- |
| `always` | — | 恒真（默认分支） |
| `flag` | key, value | 剧情 Flag 等于 value（宽松比较：bool/数字/字符串） |
| `quest_done` | quest | 某任务已完成 |
| `item_count` | item, count | 背包中某物品数量 ≥ count |
| `coin` | min | 钱币 ≥ min |
| `npc_talked` | npc | 与某 NPC 交谈过（记录在 quest_state.talked） |
| `battle_won` | count | 战斗胜利次数 ≥ count |
| `world_time` | gte | 世界时钟 ≥ 某小时（配合 NPC 行动轨迹/昼夜） |
| `and` / `or` / `not` | 数组/对象 | 组合条件 |

## 奖励类型（rewards[]）

`coin`(amount)、`item`(item, count)、`equipment`(equipment)、`xp`(amount)、
`flag`(key, value)、`card`(card，加入首位角色技能库)、`text`(text，线索文案，不弹 UI)。

## 触发点（谁检查推进）

- `GameState.flag_changed` 信号（剧情/对话置 Flag 即自动检查）；
- `notify_npc_talked()`（世界脚本与 NPC 交谈后调用）；
- `notify_battle_won()`（战斗胜利结算调用，BattleMap 已接入）；
- `check_advance()` 被主场景定时调用（覆盖物品/时间等无信号条件）。

## 校验

`编辑器/quest_editor.py validate` 校验全部任务（条件/奖励/分支引用/重复 id），
Godot 侧 `QuestDB` 启动时同样输出问题警告；新增任务必须通过校验。

## 测试

`tests/quest/test_quest_system.gd`（无头）：接取/完成/奖励/分支/时间/存档往返，必须 failed=0。
