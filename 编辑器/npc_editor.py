#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""NPC 编辑器（人类与 AI 通用）。

NPC 由 content/npcs/*.json 描述（NpcDB 读取）。本工具提供行动轨迹（时间轴）编辑：
schedule 为按小时排列的时间点，世界时钟 GameState.world_time 驱动 NPC 在相邻时间点
之间线性移动（跨零点自动衔接），位置为初始地图内的像素坐标（640×480）。

用法：
  python npc_editor.py help                       # 打印 NPC JSON 格式说明
  python npc_editor.py list                       # 列出全部 NPC
  python npc_editor.py validate                   # 校验全部 NPC（0=通过，1=有问题）
  python npc_editor.py new <名字> [--desc <说明>]  # 新建 NPC
  python npc_editor.py schedule <名字> add <hour> <x> <y> [state]   # 添加时间点（0-24，x/y 为地图内像素）
  python npc_editor.py schedule <名字> clear | list
  python npc_editor.py interaction <名字> add <选项> | clear | list
  python npc_editor.py dialogue <名字> '<对话树JSON>'   # 整体替换对话树

退出码：0 = 全部通过；1 = 存在至少一个问题。
"""

from __future__ import annotations

import json
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parent.parent
NPCS_DIR = ROOT / "content" / "npcs"

MAP_W = 640.0
MAP_H = 480.0


# ---------------- 数据读写 ----------------

def load_all() -> dict[str, dict]:
    npcs: dict[str, dict] = {}
    NPCS_DIR.mkdir(parents=True, exist_ok=True)
    for f in sorted(NPCS_DIR.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"解析失败：{f.name}：{e}")
            continue
        if isinstance(data, dict):
            nid = str(data.get("name", "") or data.get("id", ""))
            if nid:
                npcs[nid] = data
    return npcs


def load_one(npc_name: str) -> dict | None:
    f = NPCS_DIR / f"{npc_name}.json"
    if not f.exists():
        return None
    try:
        data = json.loads(f.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else None
    except Exception as e:
        print(f"解析失败：{f.name}：{e}")
        return None


def save_one(data: dict) -> None:
    NPCS_DIR.mkdir(parents=True, exist_ok=True)
    nid = str(data.get("name", "") or data.get("id", ""))
    (NPCS_DIR / f"{nid}.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _parse_json(text: str, label: str):
    """解析 JSON 参数：容忍 Windows 命令行丢引号的情况，支持 @文件路径 读取。"""
    text = text.strip()
    if len(text) >= 2 and text[0] == "'" and text[-1] == "'":
        text = text[1:-1]
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        text = text[1:-1]
    if text.startswith("@"):
        p = pathlib.Path(text[1:])
        text = p.read_text(encoding="utf-8-sig")   # 容忍 Windows 记事本/PowerShell 的 BOM
    try:
        return json.loads(text)
    except Exception as e:
        print(f"{label} 不是合法 JSON：{e}")
        return None


# ---------------- 校验 ----------------

def validate_npc(nid: str, data: dict, problems: list[str]) -> None:
    if not data.get("name"):
        problems.append(f"{nid}：缺少 name")
    if data.get("id") and data.get("id") != data.get("name"):
        problems.append(f"{nid}：id 与 name 不一致（约定两者相同）")
    schedule = data.get("schedule", [])
    if not isinstance(schedule, list):
        problems.append(f"{nid}：schedule 应为数组")
    else:
        prev = -1.0
        for i, e in enumerate(schedule):
            if not isinstance(e, dict):
                problems.append(f"{nid}.schedule[{i}] 不是对象")
                continue
            hour = e.get("hour")
            if not isinstance(hour, (int, float)):
                problems.append(f"{nid}.schedule[{i}] 缺少 hour（数字）")
                continue
            h = float(hour)
            if h < 0 or h >= 24:
                problems.append(f"{nid}.schedule[{i}] hour 越界：{h}（应 0-24）")
            if h <= prev:
                problems.append(f"{nid}.schedule[{i}] hour 未递增（{h} ≤ {prev}）")
            prev = h
            pos = e.get("position")
            if not (isinstance(pos, list) and len(pos) >= 2):
                problems.append(f"{nid}.schedule[{i}] 缺少 position（[x, y]）")
            else:
                px, py = float(pos[0]), float(pos[1])
                if px < 0 or px > MAP_W or py < 0 or py > MAP_H:
                    problems.append(f"{nid}.schedule[{i}] 位置越界：[{px}, {py}]（地图 {MAP_W}×{MAP_H}）")
    dialogue = data.get("dialogue", [])
    if not isinstance(dialogue, list):
        problems.append(f"{nid}：dialogue 应为数组（对话树）")


def cmd_validate() -> int:
    npcs = load_all()
    if not npcs:
        print("content/npcs/ 下没有 NPC JSON")
        return 1
    problems: list[str] = []
    for nid, data in sorted(npcs.items()):
        validate_npc(nid, data, problems)
    if problems:
        print(f"NPC 校验失败：{len(problems)} 个问题")
        for p in problems:
            print("  -", p)
        return 1
    print(f"NPC 校验通过：{len(npcs)} 个 NPC")
    return 0


# ---------------- 子命令 ----------------

def cmd_list() -> int:
    npcs = load_all()
    if not npcs:
        print("（无 NPC）")
        return 0
    for nid, data in sorted(npcs.items()):
        sched = data.get("schedule", [])
        line = f"{nid}　{data.get('description','')}"
        if sched:
            times = ",".join(str(e.get("hour")) for e in sched if isinstance(e, dict))
            line += f"　[轨迹 {times}]"
        print(line)
    return 0


def cmd_new(args: list[str]) -> int:
    if not args:
        print("用法：npc_editor.py new <名字> [--desc <说明>]")
        return 1
    nid = args[0]
    desc = ""
    i = 1
    while i < len(args):
        if args[i] == "--desc" and i + 1 < len(args):
            desc = args[i + 1]; i += 2
        else:
            i += 1
    if load_one(nid) is not None:
        print(f"NPC 已存在：{nid}")
        return 1
    data = {"id": nid, "name": nid, "description": desc,
            "color": "#5c7aa0", "icon": "", "art": "", "animation": "",
            "ai": "待机", "interaction": [], "dialogue": []}
    save_one(data)
    print(f"已创建 NPC：{nid}")
    return 0


def cmd_schedule(args: list[str]) -> int:
    if len(args) < 2:
        print("用法：npc_editor.py schedule <名字> add <hour> <x> <y> [state] | clear | list")
        return 1
    nid = args[0]
    op = args[1]
    data = load_one(nid)
    if data is None:
        print(f"NPC 不存在：{nid}")
        return 1
    schedule = data.setdefault("schedule", [])
    if not isinstance(schedule, list):
        schedule = []; data["schedule"] = schedule
    if op == "clear":
        data["schedule"] = []
        save_one(data)
        print(f"已清空 {nid} 的行动轨迹")
        return 0
    if op == "list":
        for e in schedule:
            pos = e.get("position", [])
            print(f"  {e.get('hour')}:00 @ {pos}  {e.get('state','')}")
        print(f"共 {len(schedule)} 个时间点")
        return 0
    if op == "add":
        if len(args) < 5:
            print("用法：npc_editor.py schedule <名字> add <hour> <x> <y> [state]")
            return 1
        try:
            hour = float(args[2])
            x = float(args[3])
            y = float(args[4])
        except ValueError:
            print("hour/x/y 必须是数字")
            return 1
        # 整数化显示（1.0 → 1）
        if hour.is_integer():
            hour = int(hour)
        if x.is_integer():
            x = int(x)
        if y.is_integer():
            y = int(y)
        if hour < 0 or hour >= 24:
            print(f"hour 越界：{hour}（应 0-24）")
            return 1
        if not (0 <= x <= MAP_W and 0 <= y <= MAP_H):
            print(f"位置越界：[{x}, {y}]（地图 {MAP_W}×{MAP_H}）")
            return 1
        state = args[5] if len(args) > 5 else "stand"
        schedule.append({"hour": hour, "position": [x, y], "state": state})
        schedule.sort(key=lambda e: float(e.get("hour", 0)))
        save_one(data)
        print(f"已添加时间点：{hour}:00 @ [{x}, {y}] {state}（共 {len(schedule)} 个）")
        return 0
    print(f"未知操作：{op}")
    return 1


def cmd_interaction(args: list[str]) -> int:
    if len(args) < 2:
        print("用法：npc_editor.py interaction <名字> add <选项> | clear | list")
        return 1
    nid = args[0]
    op = args[1]
    data = load_one(nid)
    if data is None:
        print(f"NPC 不存在：{nid}")
        return 1
    interactions = data.setdefault("interaction", [])
    if not isinstance(interactions, list):
        interactions = []; data["interaction"] = interactions
    if op == "clear":
        data["interaction"] = []
        save_one(data)
        print(f"已清空 {nid} 的互动选项")
    elif op == "list":
        for s in interactions:
            print("  -", s)
        print(f"共 {len(interactions)} 个互动选项")
    elif op == "add":
        if len(args) < 3:
            print("用法：npc_editor.py interaction <名字> add <选项>")
            return 1
        interactions.append(args[2])
        save_one(data)
        print(f"已添加互动选项：{args[2]}")
    else:
        print(f"未知操作：{op}")
        return 1
    return 0


def cmd_dialogue(args: list[str]) -> int:
    if len(args) < 2:
        print("用法：npc_editor.py dialogue <名字> '<对话树JSON>'")
        return 1
    nid = args[0]
    data = load_one(nid)
    if data is None:
        print(f"NPC 不存在：{nid}")
        return 1
    tree = _parse_json(args[1], "对话树")
    if tree is None:
        return 1
    if not isinstance(tree, list):
        print("对话树应为数组：[{id, text, options:[{text, next}]}]")
        return 1
    data["dialogue"] = tree
    save_one(data)
    print(f"已更新 {nid} 的对话树（{len(tree)} 个节点）")
    return 0


def cmd_help() -> int:
    print(__doc__)
    return 0


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("help", "-h", "--help"):
        return cmd_help()
    cmd, rest = argv[0], argv[1:]
    if cmd == "list":
        return cmd_list()
    if cmd == "validate":
        return cmd_validate()
    if cmd == "new":
        return cmd_new(rest)
    if cmd == "schedule":
        return cmd_schedule(rest)
    if cmd == "interaction":
        return cmd_interaction(rest)
    if cmd == "dialogue":
        return cmd_dialogue(rest)
    print(f"未知命令：{cmd}（python npc_editor.py help 查看用法）")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
