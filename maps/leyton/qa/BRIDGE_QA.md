# M04 stone bridge graybox QA

2026-09-27. Runtime project: C:\游戏. Godot 4.7.1, NVIDIA OpenGL compatibility renderer.

- Building package loaded at (42,59), footprint 12×11, bottom-center anchor (6,11).
- 132 occupied cells, 114 walkable, 18 parapet cells, two 10-cell N/S entrances, two collision rectangles.
- Exactly one instance on M04; none on M01/M07; repeated map/skin switches checked.
- Continuous 6px-sampled 2×3 cart route through both approaches passes; side parapets and outside water block movement.
- 68 bridge assertions; full suite 603 assertions, 137 scripts, failed=0.
- Actual captures bridge_graybox_player.png and bridge_graybox_cart.png inspected: both ends align with road; visible narrow side blocks correspond to collision; cart scale fits deck.
- Graybox is intentionally flat. These screenshots do not validate finished art, vertical facades or foreground occlusion.
- concept_v1.png is source-only: north parapets overrun reserved apron; paving repeated. Do not deploy before geometry correction and art/layer QA.
