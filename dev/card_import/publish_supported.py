"""Publish only fully compiled cards whose reviewed art is present."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HERE = Path(__file__).parent
CARDS = HERE.parents[1] / "content/cards"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ids", nargs="+")
    args = parser.parse_args()
    for ident in args.ids:
        source = HERE / "generated" / f"{ident}.json"
        card = json.loads(source.read_text(encoding="utf-8"))
        if card["id"] != ident or card["implementation_status"] != "supported":
            raise ValueError(f"{ident}: effects are not fully supported")
        if not card["art"] or not (CARDS / card["art"]).is_file():
            raise ValueError(f"{ident}: reviewed card art is not published")
        destination = CARDS / f"{ident}.json"
        if destination.exists():
            if destination.read_bytes() == source.read_bytes():
                print(f"Already published {ident}")
                continue
            raise FileExistsError(f"{destination} differs; inspect before replacing")
        destination.write_bytes(source.read_bytes())
        print(f"Published {ident}: {card['name']}")


if __name__ == "__main__":
    main()
