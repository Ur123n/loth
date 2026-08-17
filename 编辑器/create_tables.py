# -*- coding: utf-8 -*-
"""初始化编辑器 Excel 表格（已存在的表格不会被覆盖）。"""

from pathlib import Path
from openpyxl import Workbook

BASE = Path(__file__).resolve().parent


def write_sheet(path: Path, headers, rows):
    if path.exists():
        print("已存在，跳过：%s" % path.name)
        return
    wb = Workbook()
    ws = wb.active
    ws.append(headers)
    for row in rows:
        ws.append(row)
    for i in range(1, len(headers) + 1):
        ws.column_dimensions[chr(64 + i)].width = 16
    wb.save(path)
    print("已创建：%s" % path.name)


def main():
    write_sheet(BASE / "角色数据.xlsx", ["姓名", "道途", "等级", "力量", "敏捷", "耐力", "意志力", "基础生命", "耐力生命收益", "色块颜色", "力量伤害补正"], [
        ["艾莉丝", "", 0, 8, 10, 10, 10, 100, 5, "#6b99e6", 0.0],
        ["鲍德温", "", 0, 10, 10, 10, 10, 100, 5, "#d96b5c", 0.0],
        ["迪马斯", "", 0, 10, 10, 10, 10, 100, 5, "#66c76b", 0.0],
        ["卡莎", "", 0, 10, 10, 10, 10, 100, 5, "#b87ad9", 0.0],
    ])

    write_sheet(BASE / "NPC创建.xlsx", ["名称", "描述", "色块颜色"], [
        ["村长", "村庄的守望者，知晓许多旧事。", "#5c7aa0"],
    ])

    write_sheet(BASE / "装备创建.xlsx", ["名称", "部位", "描述"], [
        ["铁剑", "左手武器", "基础铁剑。"],
        ["铁头盔", "头部", "基础头盔，防御+1。"],
        ["皮甲", "身体", "基础皮甲，防御+2。"],
        ["草鞋", "足部", "轻便草鞋。"],
        ["铜戒指", "首饰1", "朴素铜戒。"],
    ])

    write_sheet(BASE / "buff创建.xlsx", ["名称", "数值", "持续时间", "触发时机", "描述"], [
        ["攻击提升", 2, 2, "回合开始", "攻击力提升（占位效果）。"],
        ["中毒", 3, 3, "回合结束", "每回合受到伤害（占位效果）。"],
    ])


if __name__ == "__main__":
    main()
