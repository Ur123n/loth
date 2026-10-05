"""Build a reproducible planning index for redesign cards still marked design_only.

Family tags are triage labels, not executable effect declarations. A card can
belong to multiple families; exact rules must be reviewed before activation.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


FAMILIES = {
    "player_choice": ("玩家选择与随机展示", r"选择|展示|查看|二选一|可令"),
    "pile_operations": ("抽牌堆、弃牌堆、牌库与复制品", r"抽牌堆|弃牌堆|牌库|牌堆|洗牌|复制品"),
    "hand_operations": ("抽牌、主动弃牌、保留", r"手牌|抽\d+张|弃\d+张|主动弃|保留"),
    "battlefield_movement": ("主动与强制位移", r"移动|推动|拉近|后退|交换位置|合法空格"),
    "multi_target_geometry": ("区域、直线与多目标选择", r"区域|友军群|全体友军|至多\d+[名敌友]|所有相邻敌人|直线|敌群|邻接敌人"),
    "counterattack": ("反击窗口与层数", r"反击|CounterDamage"),
    "status_layers": ("状态施加、移除及层数", r"标记|迟缓|脆弱|破绽|鼓舞|DOT|虚弱|中毒|毒|疗愈|Debuff"),
    "turn_triggers": ("跨回合、下次与能力牌触发", r"每回合|每轮|下回合|下一次|下一张|本轮|本场战斗第一次"),
    "cost_rules": ("条件费用与费用返还", r"费用|\d+费|返还"),
    "damage_block_conditions": ("伤害、格挡与 Armor 条件", r"伤害|格挡|Armor|护甲|Attack"),
    "dream_cycle": ("三梦状态及切换", r"沉梦|幻梦|灾梦"),
    "hp_events": ("生命支付、直接失血与生命阈值", r"生命|放血"),
}


def main() -> None:
    root = Path(sys.argv[1])
    destination = Path(sys.argv[2])
    cards = []
    for path in (root / "content/cards").glob("*.json"):
        if not re.fullmatch(r"[ADKB]\d{3}", path.stem):
            continue
        card = json.loads(path.read_text(encoding="utf-8"))
        if card["implementation_status"] == "design_only":
            cards.append(card)
    cards.sort(key=lambda card: card["id"])
    assert len({card["id"] for card in cards}) == len(cards)
    family_ids = {key: [] for key in FAMILIES}
    inventory = []
    for card in cards:
        text = " | ".join((card["description"], card["target_spec"]))
        tags = [key for key, (_, pattern) in FAMILIES.items() if re.search(pattern, text)]
        if card["card_type"] == "能力" and "turn_triggers" not in tags:
            tags.append("turn_triggers")
        if not tags:
            raise ValueError(f"Unclassified card: {card['id']}")
        for tag in tags:
            family_ids[tag].append(card["id"])
        inventory.append({"id": card["id"], "families": tags,
                          "description": card["description"],
                          "source_file": card["source_file"], "source_line": card["source_line"]})
    result = {
        "schema_version": 1,
        "purpose": "design_only mechanism planning; family matches are candidates, not runtime support",
        "total": len(inventory),
        "families": {key: {"name": name, "count": len(family_ids[key]), "card_ids": family_ids[key]}
                     for key, (name, _) in FAMILIES.items()},
        "cards": inventory,
    }
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"total": result["total"], "family_counts":
                      {key: value["count"] for key, value in result["families"].items()}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
