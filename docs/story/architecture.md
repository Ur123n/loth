# Story 架构（规划）

## 当前状态

- 人物与世界观设定文档：docs/story/setting/。
- NPC 数据含 interaction / dialogue 字段（NpcDB 已加载，对话树后续接入 DialogueSystem）。
- 剧情 / 过场系统已实现：时间轴 + 指令执行器（阻塞/非阻塞/parallel）、
  独立对话系统（文本框/头像/打字/选项/历史）、独立摄像机、四类触发器、
  剧情 Flag 与已播放记录（GameState v5）。
- 数据文件：content/stories/*.json + content/stories/triggers.json。
- 校验工具：编辑器/剧情检查.py（--list 输出指令目录）。
- 测试：tests/story/test_story_data.gd（36 断言）。

## 结构（遵循依赖方向）

```
World（NPC 交互）
  ↓
DialogueSystem（core/dialogue/ + ui/dialogue/）
  ├── 会话 / 台词 / 选项 / 历史（begin_line / show_options，令牌轮询完成）
  └── 剧情 Flag 读写走 GameState 接口
  ↓
StorySystem（上层，消费结果驱动剧情推进）
  ├── StoryDB（content/stories/*.json 数据）
  ├── StoryRunner（时间轴执行器 + 指令注册表 + 输入锁定）
  ├── StoryInstructions（同步指令实现，返回操作句柄）
  └── StoryTrigger（content/stories/triggers.json 触发器判定）

CameraCtrl（core/camera/，独立摄像机，被 StoryRunner 驱动）
```

## 组件职责

| 组件 | 职责 |
| --- | --- |
| `core/camera/camera_controller.gd` | Autoload CameraCtrl：移动/跟随/缩放/震屏/复位；摄像机挂在 root 下跨场景存活 |
| `core/dialogue/dialogue_system.gd` | Autoload Dialogue：会话状态、台词/选项令牌、历史记录 |
| `ui/dialogue/dialogue_box.gd` | 对话 UI：文本框、头像、打字、选项、历史面板 |
| `core/story/story_data.gd` | 剧情数据对象（JSON 解析 + 格式校验） |
| `core/story/story_database.gd` | Autoload StoryDB：加载 content/stories/*.json |
| `core/story/story_runner.gd` | Autoload StoryRunner：时间轴执行、阻塞/非阻塞/parallel、输入锁定、操作句柄轮询 |
| `core/story/story_instructions.gd` | 指令实现库（同步函数返回 Tween/Timer/令牌/null） |
| `core/story/trigger_manager.gd` | Autoload StoryTrigger：area/interact/flag/auto/scene 触发器 |
| `core/save/game_state.gd` | story_played（防重复触发）+ 剧情 Flag API（v5 存档） |

## 执行模型（Godot 4.7 约束）

Godot 4.7 禁止“调用协程却不 await”，因此：

- 指令处理器全部是**同步函数**，返回“操作句柄”：Tween / SceneTreeTimer /
  对话令牌（Dictionary）/ null。
- StoryRunner 对阻塞指令按帧轮询句柄完成；非阻塞指令丢弃句柄（后台继续）。
- 剧情启动采用队列：run_story() 同步入队，Runner 的 _process 内 await 启动，
  因此触发器、世界脚本、编辑器都能安全地“点火”。
- 对话完成状态用递增令牌：Dialogue.begin_line() 返回 token，
  Runner 用 is_line_done(token) 轮询，避免信号竞争。

## 数据格式

见 [editor_guide.md](editor_guide.md)（完整指令目录、阻塞语义、触发器格式与示例）。

## 防重复触发

- 剧情开始播放即写入 GameState.story_played（持久化，v5 存档）。
- 触发器触发前检查 is_story_played()；once: true 额外限制本次运行。
