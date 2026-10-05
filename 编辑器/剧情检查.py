#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""剧情 / 过场数据检查器（给人类与 AI 共用的“编辑器”入口）。

检查 content/stories/ 下的剧情 JSON 与触发器 JSON：
- 剧情必须有 id / title / instructions
- 每条指令 type 必须是已知类型，required 字段齐全，blocking 必须是 bool
- parallel / if 递归校验子指令
- story.start 引用的剧情必须存在
- avatar 若填写必须是存在的 res:// 资源
- 触发器必须有 id / story / type，引用的剧情必须存在

用法：
  python 剧情检查.py            # 检查全部剧情与触发器
  python 剧情检查.py --list     # 列出指令目录（类型 / 必填字段 / 说明）

退出码：0 = 全部通过；1 = 存在至少一个问题。
"""

from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
STORY_DIR = ROOT / "content" / "stories"
TRIGGER_FILE = STORY_DIR / "triggers.json"

# 指令目录：类型 -> (必填字段, 可选字段, 说明)
INSTRUCTION_CATALOG: dict[str, tuple[list[str], list[str], str]] = {
    "dialogue.line": (
        ["text"],
        ["speaker", "avatar", "color", "speed", "auto", "auto_delay"],
        "显示一句对话台词（打字 + 点击推进）。",
    ),
    "dialogue.choice": (
        ["options"],
        ["var"],
        "显示选项，等待选择；结果写入 var（下标或 value），选项可携带 flag/flag_value。",
    ),
    "dialogue.history.open": ([], ["blocking"], "打开对话历史面板；blocking=true 时等待关闭。"),
    "dialogue.history.clear": ([], [], "清空当前会话的对话历史。"),
    "dialogue.end": ([], [], "关闭对话会话。"),
    "camera.move_to": (
        [],
        ["target", "zoom", "duration", "transition", "ease", "blocking"],
        "镜头移动到 target（坐标或节点名），可选 zoom 同步缩放。",
    ),
    "camera.follow": (["target"], ["offset"], "镜头跟随指定节点（默认 player）。"),
    "camera.unfollow": ([], [], "停止跟随。"),
    "camera.zoom_to": (["zoom"], ["duration", "transition", "ease", "blocking"], "镜头缩放到 zoom。"),
    "camera.shake": ([], ["strength", "duration", "blocking"], "镜头震屏。"),
    "camera.reset": ([], [], "镜头复位到默认位置/缩放。"),
    "wait": (["seconds"], ["blocking"], "等待 seconds 秒（blocking=false 时无效）。"),
    "message": (["text"], ["duration", "blocking"], "顶部字幕提示。"),
    "flag.set": (["key", "value"], [], "设置 GameState 剧情 Flag（持久化）。"),
    "var.set": (["name", "value"], [], "设置剧情局部变量。"),
    "if": (["condition"], ["then", "else"], "条件分支：condition 为 true 执行 then，否则执行 else。"),
    "story.start": (["story"], [], "调用另一段剧情（嵌套执行）。"),
    "end": ([], [], "提前结束当前剧情。"),
    "move_actor": (["node", "target"], ["duration", "transition", "ease", "blocking"], "把节点移动到目标位置。"),
    "set_property": (["node", "property", "value"], [], "直接设置节点属性（[x,y] 自动转 Vector2）。"),
    "call_method": (["node", "method"], ["args"], "调用节点方法。"),
    "emit_signal": (["signal"], ["on", "args"], "发出信号（on 缺省为 StoryRunner，可填 /root/路径）。"),
    "player.lock": ([], [], "锁定玩家输入（剧情默认已锁定）。"),
    "player.unlock": ([], [], "解锁玩家输入（剧情结束自动解锁）。"),
    "change_scene": (["scene"], ["blocking"], "切换到指定场景（res:// 路径）。"),
    "parallel": (["instructions"], [], "并行执行子指令并等待全部完成。"),
}

STRUCTURAL = {"parallel", "if", "story.start", "end"}


def load_json(path: pathlib.Path):
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as exc:
        return ("JSON 语法错误：%s" % exc)
    except OSError as exc:
        return ("无法读取：%s" % exc)


def check_story(data, problems: list[str], file_name: str, all_stories: set[str]) -> None:
    if not isinstance(data, dict):
        problems.append("%s：文件根必须是对象" % file_name)
        return
    story_id = str(data.get("id", ""))
    if not story_id:
        problems.append("%s：缺少 id" % file_name)
    if not str(data.get("title", "")):
        problems.append("%s：缺少 title" % file_name)
    instructions = data.get("instructions", [])
    if not isinstance(instructions, list) or not instructions:
        problems.append("%s：instructions 缺失或为空" % file_name)
        return
    for i, ins in enumerate(instructions):
        check_instruction(ins, problems, "%s.instructions[%d]" % (file_name, i), all_stories)


def check_instruction(ins, problems: list[str], path: str, all_stories: set[str]) -> None:
    if not isinstance(ins, dict):
        problems.append("%s：指令必须是对象" % path)
        return
    kind = str(ins.get("type", ""))
    if not kind:
        problems.append("%s：缺少 type" % path)
        return
    if kind not in INSTRUCTION_CATALOG:
        problems.append("%s：未知指令类型 %s" % (path, kind))
        return
    if "blocking" in ins and not isinstance(ins["blocking"], bool):
        problems.append("%s：blocking 必须是布尔值" % path)
    required, optional, _ = INSTRUCTION_CATALOG[kind]
    for field in required:
        if field not in ins:
            problems.append("%s（%s）：缺少必填字段 %s" % (path, kind, field))
    if kind == "dialogue.choice":
        options = ins.get("options", [])
        if not isinstance(options, list) or not options:
            problems.append("%s：options 必须是数组且非空" % path)
    elif kind == "parallel":
        children = ins.get("instructions", [])
        if not isinstance(children, list) or not children:
            problems.append("%s：parallel 需要 instructions" % path)
        for j, child in enumerate(children):
            check_instruction(child, problems, "%s.instructions[%d]" % (path, j), all_stories)
    elif kind == "if":
        cond = ins.get("condition")
        if not isinstance(cond, dict) or not cond:
            problems.append("%s：if 需要 condition" % path)
        for branch in ("then", "else"):
            branch_list = ins.get(branch, [])
            if isinstance(branch_list, list):
                for j, child in enumerate(branch_list):
                    check_instruction(child, problems, "%s.%s[%d]" % (path, branch, j), all_stories)
    elif kind == "story.start":
        if ins.get("story") not in all_stories:
            problems.append("%s：story.start 引用不存在的剧情 %r" % (path, ins.get("story")))
    elif kind in ("dialogue.line", "camera.move_to"):
        avatar = str(ins.get("avatar", ""))
        if avatar and not (ROOT / avatar.removeprefix("res://")).exists():
            problems.append("%s：avatar 资源不存在 %s" % (path, avatar))


def check_trigger(data, problems: list[str], file_name: str, all_stories: set[str]) -> None:
    if not isinstance(data, list):
        problems.append("%s：触发器文件根必须是数组" % file_name)
        return
    known_types = {"area", "interact", "flag", "auto", "scene"}
    for i, t in enumerate(data):
        if not isinstance(t, dict):
            problems.append("%s[%d]：触发器必须是对象" % (file_name, i))
            continue
        path = "%s[%d]" % (file_name, i)
        if not str(t.get("id", "")):
            problems.append("%s：缺少 id" % path)
        if not str(t.get("story", "")):
            problems.append("%s：缺少 story" % path)
        elif t.get("story") not in all_stories:
            problems.append("%s：引用不存在的剧情 %r" % (path, t.get("story")))
        kind = str(t.get("type", ""))
        if kind not in known_types:
            problems.append("%s：未知触发器类型 %r（应为 %s）" % (path, kind, "/".join(sorted(known_types))))
        if "enabled" in t and not isinstance(t["enabled"], bool):
            problems.append("%s：enabled 必须是布尔值" % path)
        if kind == "area":
            area = t.get("area")
            if not isinstance(area, dict) or "position" not in area or "radius" not in area:
                problems.append("%s：area 触发器需要 area.position 与 area.radius" % path)
        elif kind == "flag" and "key" not in t:
            problems.append("%s：flag 触发器需要 key" % path)
        elif kind in ("scene", "auto") and "scene" in t and t["scene"] and \
                not (ROOT / str(t["scene"]).removeprefix("res://")).exists():
            problems.append("%s：场景不存在 %s" % (path, t["scene"]))


def main() -> int:
    if "--list" in sys.argv:
        print("=== 剧情指令目录 ===")
        for kind, (required, optional, desc) in INSTRUCTION_CATALOG.items():
            req = ", ".join(required) if required else "（无）"
            opt = ", ".join(optional) if optional else "（无）"
            print("%-22s 必填: %-34s 可选: %s\n    %s" % (kind, req, opt, desc))
        print("\n条件（if.condition）：{\"flag\": \"键\"} / {\"var\": \"名\"} + \"equals\"；"
              "支持 and / or / not 组合。")
        return 0

    if not STORY_DIR.is_dir():
        print("错误：剧情目录不存在：%s" % STORY_DIR)
        return 1

    all_stories: set[str] = set()
    story_files = sorted(STORY_DIR.glob("*.json"))
    for path in story_files:
        if path.name == "triggers.json":
            continue
        data = load_json(path)
        if isinstance(data, str):
            print("FAIL  %s：%s" % (path.name, data))
            continue
        problems: list[str] = []
        check_story(data, problems, path.name, all_stories)
        if data.get("id"):
            all_stories.add(str(data["id"]))
        if problems:
            print("FAIL  %s" % path.name)
            for p in problems:
                print("      - %s" % p)
        else:
            print("PASS  %s（%s）" % (path.name, data.get("title", "")))

    problems: list[str] = []
    check_trigger(load_json(TRIGGER_FILE), problems, TRIGGER_FILE.name, all_stories) \
        if TRIGGER_FILE.exists() else problems.append("缺少 %s" % TRIGGER_FILE)
    if problems:
        print("FAIL  %s" % TRIGGER_FILE.name)
        for p in problems:
            print("      - %s" % p)
    else:
        print("PASS  %s" % TRIGGER_FILE.name)

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
