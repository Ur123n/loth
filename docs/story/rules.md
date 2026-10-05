# Story 规则（规划）

剧情系统负责：时间轴指令执行、对话节点/选项/历史、镜头控制、触发器、剧情 Flag。

## 设计约束

- 剧情内容**不得硬编码在 .gd 脚本中**；剧情与触发器数据一律在 content/stories/，
  通过 StoryDB / StoryTrigger 加载。新增剧情只改 JSON，不改核心系统。
- 剧情 Flag 由 GameState 统一管理（set_flag / get_flag / flag_changed），
  随存档持久化；其他模块不得自行写文件。
- 剧情期间必须切断玩家控制：StoryRunner 锁定 player 组节点的 input_enabled 并置
  GameState.story_active，世界场景据此拦截输入与事件判定。
- 指令以 blocking 区分先后/同时：false 立即放行（后台继续），parallel 显式并行组；
  对话、选项、等待、镜头移动等耗时指令默认阻塞。
- 跨模块通信走 Signal：flag_changed、story_finished、input_locked_changed 等。
- 对话树数据格式已预留：content/npcs/*.json 的 interaction 与 dialogue 字段
  （NPC 交互接入 DialogueSystem 是后续工作）。
- 战斗结束若需要改变剧情，由上层系统消费 BattleResult，而不是 BattleManager 直接改 Flag。

## 新增剧情流程

1. 写 content/stories/<id>.json（参考 example_intro.json 与 editor_guide.md）。
2. 需要触发器时在 content/stories/triggers.json 加一条（area/interact/flag/auto/scene）。
3. 运行 启动剧情检查.bat 校验；python 编辑器/剧情检查.py --list 查看指令目录。
4. 运行 tests/story/test_story_data.gd 无头测试确认数据与执行器无回归。
5. 若剧情需要在场景中做交互点，世界脚本调用 StoryTrigger.interact(名字)。

## 设定文档

- 世界设定与角色档案：docs/story/setting/（整理版 .md 在 setting/整理副本/）。
- GDD：docs/game_design_document.md。
