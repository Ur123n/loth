# Four Character Decks Work Log

Updated: 2026-09-28 19:11 Asia/Shanghai
Status: in progress

## Objective

Import all 300 cards from the four root deck documents, make their effects playable in battle, and produce card faces that include the relevant character using the project's art pipeline.

## Canonical source and runtime

- Card design source: the four `*_完整卡组_*.md` files in `C:\游戏`.
- Game runtime: `C:\游戏` loaded by Godot `--path C:\游戏`.
- Art pipeline: `C:\美术素材制作`; published assets land in `C:\游戏`.
- Existing character art: Alice and Baldwin production card art; Dismas and Kasha portrait candidates in the art pipeline.

## Acceptance

- 75 Basic/Common/Uncommon/Rare cards per character; 300 unique IDs.
- Every card loads with its intended owner, cost, load, target, rarity, description, and artwork.
- Every card's costs, conditions, targeting, effects, and relevant character rules work in battle.
- Card face source assets pass pipeline QA, are visually reviewed, published, and load in the running game.
- Card, battle, effect, and editor checks pass with `failed=0`; key battle interactions have targeted tests.

## Completed

- Confirmed source documents and current card/effect/editor schema.
- Confirmed codebase-memory MCP transport is closed; used bounded source reads.
- Located project art pipeline and character references.
- Added `import_card_designs.py` and verified exactly 75 cards in each of four rarity distributions, 300 unique IDs.
- Added `compile_cards.py`: 300 source-faithful staged JSON files in `generated/`; 35 effects currently compile, 265 remain pending and are not loaded into live CardDB.
- Added guarded `publish_supported.py`; nine fully implemented cards with reviewed art are now in `content/cards/` and load into CardDB.
- Added card identity/rarity/tags/description/minimum range parsing; card target validation and minimum-range check. Updated corresponding card/battle rules and the existing targetless play test.
- Generated, pixelized, QA checked, visually reviewed, and published A001 art through `C:\美术素材制作` agent_assets run `cards-a001-20260928-v1` to `content/cards/card_faces/A001.png`.
- Built Qwen 2.1 card-art job generator with 300 distinct prompt files and per-character references. Background batch PID 9736 started 18:52 local; latest observed 28 complete, 0 failures. Thirty card faces (A001–A027 and D001/K001/B001) have been published through pixelization, QA and visual review. A006 pseudo text was repaired with imagegen; rejected original is retained.
- Added 300-card art publication spec generator and published visual-review waves `cards-wave1-reviewed-20260928-v1`, `cards-a006-fixed-20260928-v1`, and `cards-wave2-20260928-v1`.
- Changed poison to tick at turn end before losing one stack through data-driven `decay_after_trigger`; K004 applies five poison and correctly ticks for five before decaying.
- ComfyUI/Qwen runtime preflight passed on `127.0.0.1:8188`; no model or node missing.

## Validation

- Godot script compile: `scripts=145 failed=0` before latest buff patch; rerun broad suite. Targeted imported-card test 17/0, battle fixes 17/0. Earlier card logics 27/0, rebalance 47/0, conditions 15/0, demo 12/0, equipment battle 13/0.
- Art pipeline unit tests: 5 passed. A001 plus 29 later faces published; each QA wave had 0 failures and 0 warnings, contact sheets visually checked.
- Runtime CardDB, battle play, poison tick, and hand UI art load verified for published/staged examples. Full running GUI visual inspection remains pending.

## Next exact action

Continue implementing character mechanics and exact card effects, starting with Kasha poison/bleed and Baldwin self-blood/heal; keep image generator PID 9736 running. Pixelize and visually review completed image waves, then publish. Re-run full compile and targeted tests after each mechanic; only release cards with reviewed art and supported effects.

## Warnings

- Existing project has extensive unrelated modified/untracked files; preserve them.
- Existing card engine lacks many effects in these designs; a JSON-only import would create nonfunctional cards.
- Art source and game runtime are separate; file output alone does not prove a card face loaded.
- The art project `C:\美术素材制作` is not a Git repo; `backups/asset_pipeline_cards_20260928.py` is the preserved pre-change script copy.
- A003's first near-duplicate draft is retained under `build/card_faces_v1/rejected/`; the revised version has a distinct movement pose.
