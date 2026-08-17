# Story 规则（规划）

剧情系统负责：对话节点、对话选项、条件判断、对话结果、剧情 Flag。

## 设计约束

- 剧情内容与对话数据**不得硬编码在 NPC 脚本中**；对话走 DialogueSystem，数据在 content/。
- 剧情 Flag 由统一系统（规划为 GameState/SaveSystem 的一部分）管理，其他模块读取/设置需通过接口。
- 对话树数据格式已预留：content/npcs/*.json 的 `interaction`（互动选项）与 `dialogue`（对话树字段，JSON 数组）字段。
- 战斗结束若需要改变剧情，由上层系统消费 BattleResult，而不是 BattleManager 直接改 Flag。

## 设定文档

- 世界设定与角色档案：docs/story/setting/（整理版 .md 在 setting/整理副本/）。
- GDD：docs/game_design_document.md。