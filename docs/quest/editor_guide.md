# 任务编辑器使用手册（人与 AI 通用）

任务内容全部写在 `content/quests/*.json`（每份文件一个任务对象）。无论是你手工编辑
JSON，还是让 Codex / 其他 AI 直接写文件，用的都是同一套格式与校验工具
（`编辑器/quest_editor.py`），不存在“编辑器里的东西导不出去”的问题。

## 1. 快速开始

1. `python 编辑器/quest_editor.py new <id> --name <任务名> --desc <线索/说明>`
2. `python 编辑器/quest_editor.py set <id> --start '<条件JSON>' --complete '<条件JSON>' --next <后续id>`
3. `python 编辑器/quest_editor.py reward <id> add '<奖励JSON>'`
4. `python 编辑器/quest_editor.py branch <id> add --when '<条件JSON>' --next <任务id>`
5. `python 编辑器/quest_editor.py validate`（必须 0 问题；退出码 1 = 有问题，供脚本判断）
6. 游戏内：条件满足后 QuestSystem 自动推进（无任务 UI）。

> Windows 命令行传 JSON 时引号可能被吃掉：可直接写 JSON 文件后用 `@文件路径` 传入，
> 例如 `--complete @C:\游戏\my_cond.json`（支持 UTF-8 BOM）。

## 2. 任务 JSON 格式

```json
{
  "id": "quest_id",                // 全局唯一，分支/next 引用它
  "name": "任务名",
  "description": "线索/背景文本（由 NPC 与文本提供）",
  "start": { "type": "npc_talked", "npc": "赫伯特主教" },   // 可选：满足后自动接取
  "complete": { "type": "item_count", "item": "草药", "count": 1 },   // 必填：完成条件
  "rewards": [
    { "type": "text", "text": "线索文案" },
    { "type": "coin", "amount": 30 }
  ],
  "next": "quest_id",              // 可选：默认后续任务
  "branches": [                    // 可选：分支，按顺序取首个 when 满足
    { "when": { "type": "flag", "key": "garden_first", "value": true }, "next": "garden_task" },
    { "when": { "type": "always" }, "next": "kitchen_task" }
  ]
}
```

## 3. 条件 / 奖励目录

- 条件类型：`always` / `flag(key,value)` / `quest_done(quest)` / `item_count(item,count)`
  / `coin(min)` / `npc_talked(npc)` / `battle_won(count)` / `world_time(gte)` /
  `and[...]` / `or[...]` / `not{...}`。
- 奖励类型：`coin(amount)` / `item(item,count)` / `equipment(equipment)` /
  `xp(amount)` / `flag(key,value)` / `card(card)` / `text(text)`。
- 运行期说明见 `docs/quest/rules.md`。

## 4. 分支任务

`branches` 在**任务完成时**求值：按顺序取第一条 `when` 满足的分支进入其 `next`；
都不满足则用 `next`；`next` 为空则任务链结束。分支条件通常用 `flag` /
`quest_done` 表达“完成的前置条件不同 → 进入不同后续任务”。

## 5. 常用命令

```
python 编辑器/quest_editor.py help                      # 格式说明
python 编辑器/quest_editor.py list                      # 列出全部任务与分支
python 编辑器/quest_editor.py validate                  # 校验（0=通过）
python 编辑器/quest_editor.py new <id> --name <名> [--desc <文本>]
python 编辑器/quest_editor.py set <id> --start/--complete/--next/--name/--desc
python 编辑器/quest_editor.py reward <id> add/clear/list
python 编辑器/quest_editor.py branch <id> add --when ... --next ... | clear | list
python 编辑器/quest_editor.py delete <id>               # 移入 .trash（可手动恢复）
```
