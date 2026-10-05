from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).with_name("catalog.json")
SOURCES = {
    "A": "艾莉丝_完整卡组_v0.1.md",
    "D": "迪马斯_完整卡组_v0.3.md",
    "K": "卡莎_完整卡组_v0.2.md",
    "B": "鲍德温_完整卡组_v0.1.md",
}


def parse_source(prefix: str, filename: str) -> list[dict]:
    source = (ROOT / filename).read_text(encoding="utf-8")
    cards: list[dict] = []
    rarity = ""
    header: list[str] = []
    for line_number, line in enumerate(source.splitlines(), 1):
        heading = re.match(r"^#{1,3}\s+(?:\d+\.\s+)?(Basic|Common|Uncommon|Rare)\b", line)
        if heading:
            rarity = heading.group(1)
            continue
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells and cells[0] == "ID":
            header = cells
            continue
        if not cells or not re.fullmatch(prefix + r"\d{3}", cells[0]):
            continue
        if not header or len(cells) != len(header):
            raise ValueError(f"Malformed row {filename}:{line_number}: {line}")
        card = {"id": cells[0], "character": prefix, "rarity": rarity,
                "source": filename, "source_line": line_number}
        card.update({key: re.sub(r"\*\*(.*?)\*\*", r"\1", value)
                     for key, value in zip(header, cells)})
        cards.append(card)
    if len(cards) != 75:
        raise ValueError(f"{filename}: expected 75 cards, found {len(cards)}")
    return cards


def main() -> None:
    cards = [card for prefix, filename in SOURCES.items()
             for card in parse_source(prefix, filename)]
    if len({card["id"] for card in cards}) != 300:
        raise ValueError("Duplicate card ID")
    OUT.write_text(json.dumps(cards, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for prefix in SOURCES:
        subset = [card for card in cards if card["character"] == prefix]
        print(prefix, len(subset), dict(Counter(card["rarity"] for card in subset)))
    print("output:", OUT)


if __name__ == "__main__":
    main()
