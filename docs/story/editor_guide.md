# 剧情 / 过场编辑器使用手册（人与 AI 通用）

本项目的剧情系统采用 **数据文件 + 时间轴指令** 的编辑方式：剧情内容全部写在
`content/stories/*.json`，指令直接操作**运行中的游戏对象**（对话、镜头、角色、Flag、
场景切换），而不是制作动画文件。因此无论是你手工编辑 JSON，还是让 Codex 直接写剧情，
使用的都是同一套格式与工具，不存在“编辑器里的东西导不出去”的问题。

## 1. 快速开始

1. 复制 `content/stories/example_intro.json` 改名为你的剧情文件（如 `my_story.json`）。
2. 按下面的格式修改 `id` / `title` / `instructions`。
3. 运行 `启动剧情检查.bat`（或 `python 编辑器/剧情检查.py`）校验数据。
4. 在游戏里触发：见第 6 节“触发器”。
5. 编辑器预览：控制台执行 `StoryRunner.run_story_forced("my_story")`。

> 校验工具同时是“指令目录”入口：`python 编辑器/剧情检查.py --list` 会打印全部
> 指令类型、必填字段与说明，写完数据后跑一遍即可发现拼写/缺字段问题。

## 2. 剧情文件格式

```json
{
  "id": "my_story",              // 全局唯一，触发器和 story.start 靠它引用
  "title": "我的剧情",
  "description": "给编辑器/人类看的说明",
  "instructions": [ ... ]        // 时间轴：从上到下依次执行
}
```

每个剧情文件只包含一个剧情对象；`content/stories/` 下所有 `.json` 都会被 `StoryDB`
自动加载（`triggers.json` 除外，它是触发器配置文件）。

## 3. 时间轴与阻塞 / 非阻塞

`instructions` 是时间轴，默认**从上到下依次执行**。每条指令可带：

| 字段 | 类型 | 默认 | 含义 |
| --- | --- | --- | --- |
| `blocking` | bool | `true` | `true`=播放完这条才继续下一条；`false`=立即开始下一条（本条在后台继续） |
| `id` | string | — | 指令标识，调试用，可选 |
| `transition` / `ease` | string | sine / in_out | 缓动（camera.move_to、move_actor 用） |

**非阻塞的典型用途**：镜头移动的同时说话、震屏的同时显示字幕——把耗时指令设为
`"blocking": false`，下一条指令立即开始，二者并行播放。

**`parallel` 指令**：显式并行组，所有子指令**同时开始**，全部完成后才继续时间轴。
注意：并行组内最多放一句对话（文本框同时只能显示一句）。

```json
{
  "type": "parallel",
  "instructions": [
    {"type": "dialogue.line", "speaker": "艾莉丝", "text": "看！"},
    {"type": "camera.shake", "strength": 5, "duration": 0.4}
  ]
}
```

## 4. 指令目录

### 对话（DialogueSystem）

- **dialogue.line** — 必填 `text`；可选 `speaker`（说话人，空=旁白）、`avatar`
  （res:// 头像，空则用角色色块+姓氏占位）、`color`（#rrggbb）、`speed`
  （打字速度，秒/字，默认 0.03）、`auto` / `auto_delay`（自动推进）。
- **dialogue.choice** — 必填 `options`（数组）；可选 `var`（结果变量名，默认 choice）。
  每个选项可带 `value`（写入 var）和 `flag` / `flag_value`（写剧情 Flag，用于分支）。
- **dialogue.history.open** — 打开历史面板；`blocking: true` 时等待玩家关闭。
- **dialogue.history.clear** / **dialogue.end** — 清空历史 / 结束对话。

### 镜头（CameraCtrl，独立摄像机）

- **camera.move_to** — 可选 `target`（[x, y] 或节点名/“player”，默认视口中心）、
  `zoom`（同屏缩放，可选）、`duration`、`transition`、`ease`。
- **camera.follow** — 必填 `target`（默认 player），持续跟随直到 unfollow/reset。
- **camera.unfollow** / **camera.reset** — 停止跟随 / 复位默认画面。
- **camera.zoom_to** — 必填 `zoom`（数字或 [x, y]）、`duration`。
- **camera.shake** — 可选 `strength`（默认 5）、`duration`（默认 0.5）。

### 流程控制

- **wait** — 必填 `seconds`；阻塞时等待（非阻塞无意义）。
- **if** — 必填 `condition`，可选 `then` / `else`（均为指令数组）。
  条件：`{"flag": "键"}` 或 `{"var": "名"}` + `"equals": 值`；支持
  `{"and": [...]}`、`{"or": [...]}`、`{"not": {...}}`。
- **story.start** — 必填 `story`（另一段剧情的 id），嵌套执行到结束。
- **end** — 提前结束当前剧情。

### 状态与游戏操作（直接操作运行中的游戏）

- **flag.set** — 必填 `key` / `value`，写 `GameState` 剧情 Flag（随存档持久化，
  会触发 flag 型触发器）。
- **var.set** — 必填 `name` / `value`，剧情局部变量（选项结果、分支判断用）。
- **move_actor** — 必填 `node`（节点路径或/root/绝对路径）、`target`；
  可选 `duration`、`transition`、`ease`。
- **set_property** — 必填 `node` / `property` / `value`；`[x, y]` 自动转 Vector2。
- **call_method** — 必填 `node` / `method`；可选 `args`。
- **emit_signal** — 必填 `signal`；可选 `on`（节点路径，缺省 StoryRunner）、`args`。
  这是剧情与游戏其它系统对接的通用钩子（例如通知战斗系统开始战斗）。
- **player.lock** / **player.unlock** — 显式锁定/解锁玩家输入（剧情开始/结束会自动做）。
- **change_scene** — 必填 `scene`（res:// 场景路径）；`blocking: true` 等待场景切换完成。

### 其它

- **message** — 必填 `text`；可选 `duration`，顶部字幕提示。

## 5. 触发器（独立模块）

触发器写在 `content/stories/triggers.json`（数组），把“游戏事件 → 剧情”解耦开。
触发前系统总是检查 `GameState.is_story_played(剧情id)`，**播放过的剧情不会重复触发**；
`once: true` 额外保证本次运行内只触发一次。

| 类型 | 字段 | 说明 |
| --- | --- | --- |
| `area` | `area.position`（[x,y]）、`area.radius` | 玩家（group "player"）进入圆形区域 |
| `interact` | `target`（对象/NPC 名）或 `any: true` | 世界脚本调用 `StoryTrigger.interact(名字)` |
| `flag` | `key`、`value` | `GameState.set_flag()` 使该键变为该值时触发 |
| `auto` | 可选 `scene` | 场景就绪后自动触发 |
| `scene` | `scene`（res:// 路径） | 进入指定场景时触发 |

```json
[
  {
    "id": "trig_gate_area",
    "story": "my_story",
    "type": "area",
    "area": {"position": [520, 470], "radius": 60},
    "once": true,
    "enabled": true
  }
]
```

剧情播放期间的 flag 变化会暂存，等剧情结束后再判定——所以“A 剧情结尾置 flag →
flag 触发器 → B 剧情”的剧情链可以正常工作。

## 6. 在游戏中挂一个触发点

世界脚本（如 `core/world/main.gd`）做两件事：

1. 把可被触发器检测的实体加入 `player` 组：
   `_character.add_to_group("player")`（主场景已做）。
2. 需要交互触发时调用 `StoryTrigger.interact("对象名")`。

区域/flag/auto/scene 触发器无需额外代码，`StoryTrigger`（Autoload）自动判定。

## 7. 防重复触发（GameState）

- 剧情**开始播放时**即写入 `GameState.story_played`（防中断后重复触发），随存档持久化。
- 查询：`GameState.is_story_played(id)`；记录：`GameState.mark_story_played(id)`。
- 剧情 Flag：`GameState.set_flag(key, value)` / `GameState.get_flag(key)`，变化发出
  `flag_changed` 信号供触发器判定。

## 8. 已实现与后续

已实现：时间轴执行器（阻塞/非阻塞/parallel）、对话系统（文本框/头像/打字/选项/历史）、
独立摄像机（移动/跟随/缩放/震屏/复位）、四类触发器、剧情 Flag 与已播放记录、数据校验工具、
无头测试。示例剧情 `example_intro`（走出南门触发）演示了以上全部能力。

后续可扩展：Godot 编辑器面板形式的可视化时间轴（当前 JSON + 校验器已满足人与 AI 共用）、
对话树脚本化（NPC 对话复用 DialogueSystem）、剧情内播放音效、立绘演出指令。
