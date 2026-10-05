# M04 bridge layered art QA — 2026-09-27

Canonical/runtime: C:\游戏. Godot 4.7.1, NVIDIA RTX 4060 Ti, OpenGL compatibility.

## Asset and geometry

- Source v2 registered into 672×624 with fixed measured seams; source SHA and all control lines recorded in source/registered_v2/registration.json.
- Deck and rail layers reconstruct every RGBA byte of the registered source. Rail alpha remains inside two 48×432 rectangles; both 48px apron rows and outer padding are rail-free.
- No collision inferred from alpha. Existing masks retained: 132 occupied / 114 walkable / 18 blocked cells, two entrances and two collision rectangles.
- Package + Prefab validation: errors=0, warnings=0.

## Runtime behavior

- Deck at effective z=-1; player/cart and semantic rail bands in the same YSort container at effective z=0.
- Five canvas bands satisfy existing complete-coverage validation; only west/east bands have rail pixels. Both sort at the south parapet foot y=69×48.
- Repeated map switching preserves player identity and active camera, frees the old map, and rebuilds the expected structure count. Skin changes do not duplicate structures.
- Cart remains a 2×3 diagnostic rectangle, now a player child participating in sorting. Both cart and player traverse the bridge and cannot cross side parapets.

## Evidence

- Full regression: 61+138+60+85+296+33 = 673 assertions; 137 script compile checks; all failed=0.
- Four actual 1280×720 screenshots inspected: bridge_art_player.png, bridge_art_cart.png, bridge_art_south_front.png, bridge_art_side_behind.png.
- Two synthetic probe screenshots and bridge_art_render.json prove a fixed rail pixel hides a probe behind the rail and reveals it in front. Behind sampled RGB approximately (0.106,0.141,0.161); front sampled (1,0,1); both passed.
- Probe is intentionally positioned for render isolation and is not evidence of legal player movement; separate collision tests and legal-position screenshots cover movement/placement.
- Screenshot stderr empty. Import clean after adding .gdignore to the recovery backup. Capture process exited.

## Limits

This completes M04 bridge registration, layers and sorting in the Leyton test scene. It does not complete the eight-map atlas, other buildings, NPC traffic, final player/cart art or production-scene migration. Original v2 remains source-only; runtime uses registered exports. The standard generator preview displays the Base rail layer alone; the complete registered composite and runtime screenshots are the visual references.
