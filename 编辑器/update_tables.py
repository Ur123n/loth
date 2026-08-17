# -*- coding: utf-8 -*-
"""为现有表格追加美术资源 / NPC 新列（保留原有数据，只补列）。"""

import json
from pathlib import Path

from openpyxl import load_workbook

EDITOR = Path(__file__).resolve().parent


def ensure_columns(path: Path, extra_headers):
    if not path.exists():
        print("缺失：%s" % path.name)
        return
    wb = load_workbook(path)
    ws = wb.active
    headers = [c.value for c in ws[1]]
    added = 0
    for header in extra_headers:
        if header not in headers:
            ws.cell(row=1, column=len(headers) + 1, value=header)
            headers.append(header)
            added += 1
    wb.save(path)
    print("%s 新增列 %d" % (path.name, added))


def fill_buff_defaults():
    """为 buff创建.xlsx 回填 数值 / 基础持续（从现有 JSON 读取，保留当前数据）。"""
    path = EDITOR / "buff创建.xlsx"
    if not path.exists():
        return
    wb = load_workbook(path)
    ws = wb.active
    headers = [c.value for c in ws[1]]

    def col_index(name):
        for i, h in enumerate(headers):
            if h and name in str(h):
                return i
        return -1

    value_col = col_index("数值")
    duration_col = col_index("基础持续")
    if value_col < 0 or duration_col < 0:
        wb.close()
        return
    buffs_dir = EDITOR.parent / "content" / "buffs"
    filled = 0
    for row in ws.iter_rows(min_row=2):
        name = row[0].value
        if name is None:
            continue
        json_path = buffs_dir / ("%s.json" % str(name).strip())
        if not json_path.exists():
            continue
        try:
            data = json.loads(json_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        row[value_col].value = int(data.get("value", 0))
        row[duration_col].value = int(data.get("base_duration", 1))
        filled += 1
    wb.save(path)
    wb.close()
    print("buff 数值/基础持续 已回填 %d 行" % filled)


def main():
    ensure_columns(EDITOR / "角色数据.xlsx", ["美术资源", "美术图标", "立绘", "美术动画"])
    ensure_columns(EDITOR / "敌怪创建.xlsx", ["美术资源", "美术图标", "美术动画"])
    ensure_columns(EDITOR / "装备创建.xlsx", ["美术资源", "美术图标", "美术动画"])
    ensure_columns(EDITOR / "buff创建.xlsx", ["美术资源", "美术图标", "美术动画", "数值", "基础持续（回合）"])
    fill_buff_defaults()
    ensure_columns(EDITOR / "NPC创建.xlsx", ["美术资源", "美术图标", "美术动画", "AI", "互动选项", "对话树"])

    # 给 村长 预填示例互动/对话，方便理解格式
    npc_path = EDITOR / "NPC创建.xlsx"
    wb = load_workbook(npc_path)
    ws = wb.active
    headers = [c.value for c in ws[1]]
    if "AI" in headers and "互动选项" in headers and "对话树" in headers:
        ai_col = headers.index("AI") + 1
        inter_col = headers.index("互动选项") + 1
        dial_col = headers.index("对话树") + 1
        for row in ws.iter_rows(min_row=2):
            if row[0].value == "村长":
                row[ai_col - 1].value = "待机"
                row[inter_col - 1].value = "打招呼；询问近况"
                dialogue = [
                    {"id": "start", "text": "年轻人，最近村里不太平。", "options": [
                        {"text": "发生了什么？", "next": "news"},
                        {"text": "告辞。", "next": ""},
                    ]},
                    {"id": "news", "text": "听说山里有骷髅出没。", "options": [
                        {"text": "我去看看。", "next": ""},
                    ]},
                ]
                row[dial_col - 1].value = json.dumps(dialogue, ensure_ascii=False)
                break
    wb.save(npc_path)
    print("NPC 示例数据已填写")


if __name__ == "__main__":
    main()
