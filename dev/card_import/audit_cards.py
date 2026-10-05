from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
import sys


cards = json.loads(Path(__file__).with_name("catalog.json").read_text(encoding="utf-8"))
if len(sys.argv) > 1:
    prefix = sys.argv[1].upper()
    generated = Path(__file__).with_name("generated")
    for card in cards:
        if card["character"] != prefix:
            continue
        compiled = json.loads((generated / f"{card['id']}.json").read_text(encoding="utf-8"))
        if compiled["implementation_status"] == "pending":
            print(card["id"], card["名称"], "|", card.get("条件", ""), "|", card["效果"])
    raise SystemExit(0)
for prefix in "ADKB":
    subset = [card for card in cards if card["character"] == prefix]
    print(prefix, list(subset[0].keys()))
    print(" types:", Counter(card.get("类型", "") for card in subset))
    print(" exhaust:", Counter(card.get("消耗", "") for card in subset))
    print(" samples:")
    for card in subset[:5]:
        print(" ", card["id"], card["名称"], card.get("效果", ""))
