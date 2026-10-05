# NPC 行动轨迹（时间轴）说明

NPC 的 `schedule` 字段是**按小时排列的时间点列表**（行动轨迹）。世界时钟
`GameState.world_time`（小时 0-24，随真实时间推进并随存档持久化）驱动 NPC 在
相邻时间点之间**线性移动**，跨零点自动衔接（如 18 点 → 次日 6 点）。

## 数据格式（content/npcs/*.json）

```json
{
  "name": "赫伯特主教",
  "schedule": [
    { "hour": 6,  "position": [264, 128], "state": "pray"  },
    { "hour": 12, "position": [288, 240], "state": "walk"  },
    { "hour": 18, "position": [264, 128], "state": "pray"  }
  ]
}
```

- `hour`：0-24（不含 24），必须严格递增；
- `position`：**地图内像素坐标**（当前初始地图 640×480；换图需调整
  `core/world/npc_schedule.gd` 的 `MAP_W/MAP_H`）；
- `state`：行为状态（pray/walk/garden/gate/rest 等，供美术/演出扩展）。

## 运行机制

- `core/world/npc_schedule.gd`：`compute_position(schedule, hour)` 纯逻辑（空→INF、
  单点恒在、整点命中、相邻插值、跨零点衔接）；`validate()` 校验。
- 主场景 `core/world/main.gd`：`GameState.advance_world_time(delta, 10)` 推进时钟
  （每秒真实时间 = 10 游戏分钟），`_update_npc_markers()` 每帧移动 NPC 标记
  （色块 + 姓名，`MAP_POSITION + pos * MAP_SCALE`）。
- 交互：E 键与半径内 NPC 交谈 → `StoryTrigger.interact(name)`（触发剧情）+
  `QuestSystem.notify_npc_talked(name)`（记录交谈，供任务条件 `npc_talked`）。

## 编辑器

`python 编辑器/npc_editor.py schedule <名字> add <hour> <x> <y> [state]`
（自动排序与校验）；`clear` / `list` 查看。`validate` 全量校验（hour 越界/未递增/
位置越界/缺字段）。Excel 同步（sync_tables.py）会**保留** JSON 中已有的 schedule。

## 测试

`tests/world/test_npc_schedule.gd`：空/单点/整点/插值/跨零点/校验，必须 failed=0。
