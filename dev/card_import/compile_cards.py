from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path


HERE = Path(__file__).parent
CATALOG = HERE / "catalog.json"
OUT = HERE / "generated"
ART_DIR = HERE.parents[1] / "content" / "cards" / "card_faces"
CHARACTERS = {"A": ("艾莉丝", "梦魇行者"), "D": ("迪马斯", "侠盗"),
              "K": ("卡莎", "解剖学者"), "B": ("鲍德温", "孢子卫士")}
TYPE_MAP = {"Attack": "攻击", "Skill": "行动", "Power": "能力"}


def range_info(raw: str) -> tuple[int, int]:
    if "自身" in raw or raw == "—":
        return 0, 0
    span = re.search(r"(?<!\d)(\d+)\s*[–—-]\s*(\d+)", raw)
    if span:
        return int(span.group(1)), int(span.group(2))
    maximum = re.search(r"≤\s*(\d+)", raw)
    if maximum:
        return 1, int(maximum.group(1))
    numbers = [int(x) for x in re.findall(r"\d+", raw)]
    return (1, numbers[0]) if numbers else (0, 0)


def target_info(raw: str, card_type: str) -> str:
    if "地面" in raw or "区域" in raw:
        return "Area"
    if "友军" in raw:
        return "Ally"
    if "敌" in raw or card_type == "Attack":
        return "Enemy"
    return "Self"


def compile_effects(text: str, target_type: str, card_range: int) -> list[dict] | None:
    match = re.fullmatch(r"造成\s*(\d+)\s*伤害。", text)
    if match:
        return [{"logic": "attack", "value": int(match.group(1)), "attack_range": card_range}]
    match = re.fullmatch(r"获得\s*(\d+)\s*格挡。", text)
    if match and target_type == "Self":
        return [{"logic": "defense", "value": int(match.group(1))}]
    match = re.fullmatch(r"移动最多\s*(\d+)\s*格。", text)
    if match:
        return [{"logic": "move", "distance": int(match.group(1))}]
    match = re.fullmatch(r"造成\s*(\d+)\s*伤害\s*(\d+)\s*次。", text)
    if match:
        return [{"logic": "attack", "value": int(match.group(1)),
                 "attack_range": card_range} for _ in range(int(match.group(2)))]
    match = re.fullmatch(r"造成\s*(\d+)\s*伤害；之后移动最多\s*(\d+)\s*格。", text)
    if match:
        return [{"logic": "attack", "value": int(match.group(1)), "attack_range": card_range},
                {"logic": "move", "distance": int(match.group(2))}]
    match = re.fullmatch(r"移动最多\s*(\d+)\s*格；获得\s*(\d+)\s*格挡。", text)
    if match and target_type == "Self":
        return [{"logic": "move", "distance": int(match.group(1))},
                {"logic": "defense", "value": int(match.group(2))}]
    match = re.fullmatch(r"获得\s*(\d+)\s*格挡；抽\s*(\d+)\s*张。", text)
    if match and target_type == "Self":
        return [{"logic": "defense", "value": int(match.group(1))},
                {"logic": "draw", "value": int(match.group(2))}]
    match = re.fullmatch(r"抽\s*(\d+)\s*张。", text)
    if match:
        return [{"logic": "draw", "value": int(match.group(1))}]
    match = re.fullmatch(r"获得\s*(\d+)\s*费。", text)
    if match:
        return [{"logic": "gain_energy", "value": int(match.group(1))}]
    match = re.fullmatch(r"施加\s*(\d+)\s*毒。", text)
    if match and target_type == "Enemy":
        return [{"logic": "buff", "target": "enemy", "buff_type": "中毒",
                 "stacks": int(match.group(1))}]
    match = re.fullmatch(r"施加\s*(\d+)\s*毒和\s*(\d+)\s*虚弱。", text)
    if match and target_type == "Enemy":
        return [{"logic": "buff", "target": "enemy", "buff_type": "中毒",
                 "stacks": int(match.group(1))},
                {"logic": "buff", "target": "enemy", "buff_type": "虚弱",
                 "stacks": int(match.group(2))}]
    match = re.fullmatch(r"获得\s*(\d+)\s*层疗愈。", text)
    if match and target_type == "Self":
        return [{"logic": "buff", "target": "self", "buff_type": "疗愈",
                 "stacks": int(match.group(1))}]
    match = re.fullmatch(r"获得\s*(\d+)\s*格挡和\s*(\d+)\s*层疗愈。", text)
    if match and target_type == "Self":
        return [{"logic": "defense", "value": int(match.group(1))},
                {"logic": "buff", "target": "self", "buff_type": "疗愈",
                 "stacks": int(match.group(2))}]
    return None


def compile_card(raw: dict) -> dict:
    prefix = raw["character"]
    character_name, path_name = CHARACTERS[prefix]
    cost = raw["费"].strip()
    load = raw.get("Load", raw.get("负载", "")).strip()
    if not cost.isdigit() or not load.isdigit():
        raise ValueError(f"{raw['id']}: nonnumeric cost/load: {cost!r}/{load!r}")
    card_type = raw["类型"].strip()
    if card_type not in TYPE_MAP:
        raise ValueError(f"{raw['id']}: unknown type: {card_type}")
    target_raw = raw.get("射程/目标", raw.get("目标", ""))
    target_type = target_info(target_raw, card_type)
    min_range, max_range = range_info(target_raw)
    tags = raw.get("标签", "")
    keywords = [keyword for keyword in ("沉梦", "幻梦", "灾梦") if keyword in tags]
    if raw["消耗"] == "是":
        keywords.append("消耗")
    condition = raw.get("条件", "")
    description = raw["效果"]
    if condition and condition != "—":
        description = f"条件：{condition}。{description}"
    effects = None if condition and condition != "—" else compile_effects(
        raw["效果"], target_type, max_range)
    card = {
        "id": raw["id"], "name": raw["名称"], "character": character_name,
        "rarity": raw["rarity"], "category": "道途专属卡牌", "path": path_name,
        "card_type": TYPE_MAP[card_type], "cost": int(cost), "load": int(load),
        "target_type": target_type, "min_range": min_range, "range": max_range,
        "target_spec": target_raw, "area": 0, "keywords": keywords,
        "tags": [tag.strip() for tag in tags.split(",") if tag.strip()],
        "description": description, "source_effect": raw["效果"],
        "source_file": raw["source"], "source_line": raw["source_line"],
        "icon": "", "art": f"card_faces/{raw['id']}.png" if (ART_DIR / f"{raw['id']}.png").is_file() else "",
        "animation": "", "effects": effects or [],
        "implementation_status": "supported" if effects is not None else "pending",
    }
    return card


def main() -> None:
    raws = json.loads(CATALOG.read_text(encoding="utf-8"))
    cards = [compile_card(raw) for raw in raws]
    if len(cards) != 300 or len({card["name"] for card in cards}) != 300:
        raise ValueError("Expected 300 uniquely named cards")
    OUT.mkdir(exist_ok=True)
    for card in cards:
        (OUT / f"{card['id']}.json").write_text(
            json.dumps(card, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("cards:", len(cards))
    print("effect compiler:", dict(Counter(card["implementation_status"] for card in cards)))
    print("supported IDs:", " ".join(card["id"] for card in cards if card["implementation_status"] == "supported"))


if __name__ == "__main__":
    main()
