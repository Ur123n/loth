# Story 架构（规划）

## 当前状态

- 已有人物与世界观设定文档（docs/story/setting/）。
- NPC 数据含 interaction / dialogue 字段（NpcDB 已加载）。
- 对话系统（DialogueSystem）尚未实现：无对话 UI、无条件判断、无剧情 Flag 持久化。

## 规划结构（遵循依赖方向）

```
World（NPC 交互）
  ↓
DialogueSystem（core/dialogue/）
  ├── 对话节点 / 选项 / 条件判断
  └── 剧情 Flag（读/写接口）
  ↓
StorySystem（上层，消费结果驱动剧情推进）
```

## 数据建议

- 对话树：content/dialogue/ 或并入 content/npcs/ 的 dialogue 字段（JSON 数组）。
- Flag：由 SaveSystem 统一持久化（user://savegame.json），禁止散落在各脚本。

## 实施顺序

1. DialogueSystem 核心（节点/选项/条件/结果）+ UI（ui/dialogue/）。
2. 剧情 Flag 接入 SaveSystem。
3. 首个 NPC 对话垂直切片。