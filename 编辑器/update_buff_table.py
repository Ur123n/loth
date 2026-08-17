# -*- coding: utf-8 -*-
"""重建 buff创建.xlsx（完善后的完整字段）。"""

from pathlib import Path

from openpyxl import Workbook

PATH = Path(__file__).resolve().parent / "buff创建.xlsx"

HEADERS = [
    "名称", "阵营（正面/负面/中立）", "类型（层数增益/层数持续/持续/即时）",
    "数值（效果强度）", "基础持续时间（回合）", "每层持续加成（回合）",
    "每回合是否衰减（是/否）", "触发后是否消失（是/否）",
    "触发时机", "触发条件", "描述",
]

ROWS = [
    ["攻击提升", "正面", "层数增益", 2, 2, 0, "是", "否", "回合开始", "自身行动开始时", "每层攻击力+2，无上限，每回合衰减1层。"],
    ["铁壁", "正面", "持续", 4, 3, 0, "否", "是", "受到攻击时", "受到攻击前", "获得4点护盾，触发后消失。"],
    ["中毒", "负面", "持续", 3, 3, 0, "否", "否", "回合结束", "行动结束后", "每回合受到3点伤害。"],
    ["脆弱", "负面", "层数持续", 2, 2, 1, "是", "否", "回合开始", "受到攻击时", "每层使受到的伤害+2，层数影响持续时间。"],
    ["再生", "正面", "层数增益", 2, 3, 0, "否", "否", "回合结束", "行动结束后", "每层每回合回复2点生命。"],
]


def main():
    wb = Workbook()
    ws = wb.active
    ws.append(HEADERS)
    for row in ROWS:
        ws.append(row)
    for i in range(1, len(HEADERS) + 1):
        ws.column_dimensions[chr(64 + i)].width = 18
    wb.save(PATH)
    print("BUFF_TABLE_UPDATED")


if __name__ == "__main__":
    main()
