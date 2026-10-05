#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""任务编辑器（人类与 AI 通用）。

任务系统没有任务 UI / 任务栏 / 任务提示：任务状态只记录在角色/存档
（GameState.quest_state），完成条件满足后由 QuestSystem 自动推进到下一任务；
分支任务按完成时的前置条件不同进入不同后续任务；奖励与线索由 NPC 对话与文本提供。

本工具直接读写 content/quests/*.json（人类可在任意文本编辑器手工编辑，AI 可直接
写 JSON 后运行 validate，两边用的是同一套格式与校验）。

用法：
  python quest_editor.py help                      # 打印任务 JSON 格式说明
  python quest_editor.py list                      # 列出全部任务
  python quest_editor.py validate                  # 校验全部任务（0=通过，1=有问题）
  python quest_editor.py new <id> --name <名> [--desc <线索/说明>]
  python quest_editor.py set <id> --start '<条件JSON>' --complete '<条件JSON>' --next <后续任务id>
  python quest_editor.py reward <id> add '<奖励JSON>' | clear | list
  python quest_editor.py branch <id> add --when '<条件JSON>' --next <任务id> | clear | list
  python quest_editor.py delete <id>

条件 JSON 类型：always / flag(key,value) / quest_done(quest) / item_count(item,count)
  / coin(min) / npc_talked(npc) / battle_won(count) / world_time(gte) /
  and / or / not（可组合）。
奖励 JSON 类型：coin(amount) / item(item,count) / xp(amount) / flag(key,value)
  / card(card) / equipment(equipment) / text(text 线索文案)。

退出码：0 = 全部通过；1 = 存在至少一个问题（供 CI / AI 脚本判断）。
"""

from __future__ import annotations

import json
import pathlib
import shutil
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parent.parent
QUESTS_DIR = ROOT / "content" / "quests"

CONDITION_TYPES: dict[str, list[str]] = {
    "always": [],
    "flag": ["key"],
    "quest_done": ["quest"],
    "item_count": ["item", "count"],
    "coin": ["min"],
    "npc_talked": ["npc"],
    "battle_won": ["count"],
    "world_time": ["gte"],
    "and": ["and"],
    "or": ["or"],
    "not": ["not"],
}
REWARD_TYPES = {"coin", "item", "xp", "flag", "card", "equipment", "text"}


# ---------------- 数据读写 ----------------

def load_all() -> dict[str, dict]:
    quests: dict[str, dict] = {}
    QUESTS_DIR.mkdir(parents=True, exist_ok=True)
    for f in sorted(QUESTS_DIR.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"解析失败：{f.name}：{e}")
            continue
        if isinstance(data, dict):
            qid = str(data.get("id", ""))
            if qid:
                quests[qid] = data
    return quests


def load_one(qid: str) -> dict | None:
    f = QUESTS_DIR / f"{qid}.json"
    if not f.exists():
        return None
    try:
        data = json.loads(f.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else None
    except Exception as e:
        print(f"解析失败：{f.name}：{e}")
        return None


def save_one(data: dict) -> None:
    QUESTS_DIR.mkdir(parents=True, exist_ok=True)
    qid = str(data.get("id", ""))
    (QUESTS_DIR / f"{qid}.json").write_text(
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

def validate_condition(cond, problems: list[str], prefix: str = "") -> None:
    if isinstance(cond, bool):
        return
    if not isinstance(cond, dict):
        problems.append(f"{prefix} 条件不是对象")
        return
    ctype = cond.get("type")
    if ctype not in CONDITION_TYPES:
        problems.append(f"{prefix} 未知条件类型：{ctype}")
        return
    for f in CONDITION_TYPES[ctype]:
        if f not in cond:
            problems.append(f"{prefix} 条件 {ctype} 缺少字段 {f}")
    if ctype in ("and", "or"):
        items = cond.get(ctype, [])
        if not isinstance(items, list):
            problems.append(f"{prefix} 条件 {ctype} 需要数组")
        else:
            for i, c in enumerate(items):
                validate_condition(c, problems, f"{prefix}.{ctype}[{i}]")
    elif ctype == "not":
        validate_condition(cond.get("not", {}), problems, f"{prefix}.not")


def validate_quest(qid: str, data: dict, all_ids: set[str], problems: list[str]) -> None:
    if not data.get("id"):
        problems.append(f"{qid}：缺少 id")
    if not data.get("name"):
        problems.append(f"{qid}：缺少 name")
    complete = data.get("complete")
    if not isinstance(complete, dict):
        problems.append(f"{qid}：缺少 complete 条件（任务必须有完成条件）")
    else:
        validate_condition(complete, problems, f"{qid}.complete")
    start = data.get("start")
    if isinstance(start, dict) and start:
        validate_condition(start, problems, f"{qid}.start")
    rewards = data.get("rewards", [])
    if not isinstance(rewards, list):
        problems.append(f"{qid}：rewards 应为数组")
    else:
        for i, r in enumerate(rewards):
            if not isinstance(r, dict):
                problems.append(f"{qid}.rewards[{i}] 不是对象")
                continue
            if r.get("type") not in REWARD_TYPES:
                problems.append(f"{qid}.rewards[{i}] 未知奖励类型：{r.get('type')}")
    branches = data.get("branches", [])
    if not isinstance(branches, list):
        problems.append(f"{qid}：branches 应为数组")
    else:
        for i, b in enumerate(branches):
            if not isinstance(b, dict):
                problems.append(f"{qid}.branches[{i}] 不是对象")
                continue
            nxt = str(b.get("next", ""))
            if not nxt:
                problems.append(f"{qid}.branches[{i}] 缺少 next")
            elif nxt not in all_ids:
                problems.append(f"{qid}.branches[{i}] 引用的任务不存在：{nxt}")
            if "when" in b:
                validate_condition(b.get("when", {}), problems, f"{qid}.branches[{i}].when")
    nxt = str(data.get("next", ""))
    if nxt and nxt not in all_ids:
        problems.append(f"{qid}：next 引用的任务不存在：{nxt}")


def cmd_validate() -> int:
    quests = load_all()
    if not quests:
        print("content/quests/ 下没有任务 JSON")
        return 1
    all_ids = set(quests.keys())
    problems: list[str] = []
    for qid, data in sorted(quests.items()):
        validate_quest(qid, data, all_ids, problems)
    if problems:
        print(f"任务校验失败：{len(problems)} 个问题")
        for p in problems:
            print("  -", p)
        return 1
    print(f"任务校验通过：{len(quests)} 个任务")
    return 0


# ---------------- 子命令 ----------------

def cmd_list() -> int:
    quests = load_all()
    if not quests:
        print("（无任务）")
        return 0
    for qid, data in sorted(quests.items()):
        print(f"{qid}　{data.get('name','')}")
        if data.get("next"):
            print(f"    next: {data['next']}")
        for b in data.get("branches", []):
            if isinstance(b, dict):
                print(f"    branch -> {b.get('next','')}（when: {json.dumps(b.get('when',{}), ensure_ascii=False)}）")
    return 0


def cmd_new(args: list[str]) -> int:
    if not args:
        print("用法：quest_editor.py new <id> --name <名> [--desc <线索/说明>]")
        return 1
    qid = args[0]
    name = ""
    desc = ""
    i = 1
    while i < len(args):
        if args[i] == "--name" and i + 1 < len(args):
            name = args[i + 1]; i += 2
        elif args[i] == "--desc" and i + 1 < len(args):
            desc = args[i + 1]; i += 2
        else:
            i += 1
    if not name:
        print("缺少 --name（任务名）")
        return 1
    data = {"id": qid, "name": name, "description": desc}
    save_one(data)
    print(f"已创建任务 {qid}（complete 条件为空，请用 set 补上）")
    return 0


def cmd_set(args: list[str]) -> int:
    if len(args) < 1:
        print("用法：quest_editor.py set <id> [--start 条件JSON] [--complete 条件JSON] [--next id] [--name 名] [--desc 文本]")
        return 1
    qid = args[0]
    data = load_one(qid)
    if data is None:
        print(f"任务不存在：{qid}")
        return 1
    i = 1
    while i < len(args):
        key = args[i]
        if key in ("--start", "--complete") and i + 1 < len(args):
            cond = _parse_json(args[i + 1], key)
            if cond is None:
                return 1
            field = "complete" if key == "--complete" else "start_condition"
            data["complete" if key == "--complete" else "start"] = cond
            i += 2
        elif key == "--next" and i + 1 < len(args):
            data["next"] = args[i + 1]; i += 2
        elif key == "--name" and i + 1 < len(args):
            data["name"] = args[i + 1]; i += 2
        elif key == "--desc" and i + 1 < len(args):
            data["description"] = args[i + 1]; i += 2
        else:
            i += 1
    save_one(data)
    print(f"已更新任务 {qid}")
    return 0


def cmd_reward(args: list[str]) -> int:
    if len(args) < 1:
        print("用法：quest_editor.py reward <id> add <奖励JSON> | clear | list")
        return 1
    qid = args[0]
    data = load_one(qid)
    if data is None:
        print(f"任务不存在：{qid}")
        return 1
    op = args[1] if len(args) > 1 else "list"
    rewards = data.setdefault("rewards", [])
    if not isinstance(rewards, list):
        rewards = []; data["rewards"] = rewards
    if op == "clear":
        data["rewards"] = []
        save_one(data)
        print(f"已清空 {qid} 的奖励")
    elif op == "list":
        for i, r in enumerate(rewards):
            print(f"  [{i}] {json.dumps(r, ensure_ascii=False)}")
        print(f"共 {len(rewards)} 条奖励")
    elif op == "add":
        r = _parse_json(args[2], "奖励")
        if r is None:
            return 1
        rewards.append(r)
        save_one(data)
        print(f"已添加奖励：{json.dumps(r, ensure_ascii=False)}")
    else:
        print(f"未知操作：{op}")
        return 1
    return 0


def cmd_branch(args: list[str]) -> int:
    if len(args) < 1:
        print("用法：quest_editor.py branch <id> add --when <条件JSON> --next <任务id> | clear | list")
        return 1
    qid = args[0]
    data = load_one(qid)
    if data is None:
        print(f"任务不存在：{qid}")
        return 1
    op = args[1] if len(args) > 1 else "list"
    branches = data.setdefault("branches", [])
    if not isinstance(branches, list):
        branches = []; data["branches"] = branches
    if op == "clear":
        data["branches"] = []
        save_one(data)
        print(f"已清空 {qid} 的分支")
    elif op == "list":
        for i, b in enumerate(branches):
            print(f"  [{i}] when={json.dumps(b.get('when',{}), ensure_ascii=False)} -> {b.get('next','')}")
        print(f"共 {len(branches)} 条分支")
    elif op == "add":
        when = None
        nxt = ""
        i = 2
        while i < len(args):
            if args[i] == "--when" and i + 1 < len(args):
                when = _parse_json(args[i + 1], "--when")
                if when is None:
                    return 1
                i += 2
            elif args[i] == "--next" and i + 1 < len(args):
                nxt = args[i + 1]; i += 2
            else:
                i += 1
        if nxt is None or nxt == "":
            print("缺少 --next <任务id>")
            return 1
        branches.append({"when": when if when is not None else {"type": "always"}, "next": nxt})
        save_one(data)
        print(f"已添加分支：when={json.dumps(when, ensure_ascii=False) if when else 'always'} -> {nxt}")
    else:
        print(f"未知操作：{op}")
        return 1
    return 0


def cmd_delete(args: list[str]) -> int:
    if not args:
        print("用法：quest_editor.py delete <id>")
        return 1
    qid = args[0]
    f = QUESTS_DIR / f"{qid}.json"
    if not f.exists():
        print(f"任务不存在：{qid}")
        return 1
    trash = QUESTS_DIR / ".trash"
    trash.mkdir(exist_ok=True)
    shutil.move(str(f), str(trash / f.name))
    print(f"已移入回收站：{qid}（.trash/ 内可手动恢复）")
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
    if cmd == "set":
        return cmd_set(rest)
    if cmd == "reward":
        return cmd_reward(rest)
    if cmd == "branch":
        return cmd_branch(rest)
    if cmd == "delete":
        return cmd_delete(rest)
    print(f"未知命令：{cmd}（python quest_editor.py help 查看用法）")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
