# -*- coding: utf-8 -*-
"""重建 敌怪创建.xlsx（若已存在则覆盖为新结构）。"""

from pathlib import Path

from openpyxl import Workbook

PATH = Path(__file__).resolve().parent / "敌怪创建.xlsx"

HEADERS = [
    "名称", "最小血量", "最大血量", "最小攻击", "最大攻击",
    "攻击距离", "移动力", "敏捷", "AI（无/靠近/远离）", "色块颜色", "描述",
]

ROWS = [
    ["木桩", 100, 100, 0, 0, 0, 0, 5, "无", "#b8854a", "训练用木桩，无 AI。"],
    ["骷髅", 19, 24, 5, 7, 1, 1, 5, "靠近", "#b8b8c0", "近战骷髅，靠近玩家攻击。"],
    ["骷髅弓箭手", 17, 21, 4, 6, 3, 1, 6, "远离", "#8fa8c8", "远程弓箭手，优先远离玩家。"],
]


def main():
    wb = Workbook()
    ws = wb.active
    ws.append(HEADERS)
    for row in ROWS:
        ws.append(row)
    for i in range(1, len(HEADERS) + 1):
        ws.column_dimensions[chr(64 + i)].width = 16
    wb.save(PATH)
    print("ENEMY_TABLE_UPDATED")


if __name__ == "__main__":
    main()
