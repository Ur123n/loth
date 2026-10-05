# M07 gatehouse graybox QA — 2026-09-27

Canonical/runtime C:\游戏, Godot 4.7.1, NVIDIA RTX4060Ti / OpenGL compatibility.

## Structure

- Independent Building at (85,32), footprint 11×16, 176 occupied / 66 walkable / 110 blocked ground cells, two six-cell E/W entrances, two static wing collision rectangles.
- Base, Floor and WallWalk share a 624×864 canvas and bottom-center anchor. Full geometry from prepare_gatehouse.gd; collision is never inferred from images.
- Upper three-cell lane remains a separate navigation/elevation state, with the player drawn above it only after climbing stairs.
- Package validation: errors=0, warnings=0.

## Behavior

- test_leyton_gatehouse.gd: 69 assertions, failed=0.
- All 96×80 ground cells and all wall-level player-center positions match the pre-change SHA256 baseline for each of three gate states (gatehouse_before.json).
- Open passage supports player and 2×3 cart; curfew/sealed block it through both map queries and the actual physics body.
- Upper route crosses both gatehouse and water gate in all three states. At water-gate XY, ground is blocked and the upper level is walkable; river navigation unchanged.
- Surface switching preserves structure count and gate state; stairs adjust actor depth, forbid carts and restore ground state on descent.
- Changing maps frees the old structure and resets elevation. A closed destination is rejected before freeing the current map; player/cart return to a safe departure point. Opening the gate restores the transition.
- The earlier M04 bridge regression now expects one distinct Building on both M04 and M07, and none on M01.

## Actual render evidence

- gatehouse_open_ground.png, gatehouse_open_cart.png, gatehouse_curfew.png, gatehouse_sealed.png.
- gatehouse_wall_over_closed_gate.png, gatehouse_wall_over_water_gate.png.
- gatehouse_probe_ground.png / gatehouse_probe_upper.png: same actor and XY, changing only elevation. Ground actor hidden below WallWalk; upper actor visible above it. gatehouse_render.json records passed=true for both, failed=0.
- Four representative scene captures directly inspected; screenshot stderr empty, capture process exited. Flat colors deliberately communicate geometry and levels.

## Scope

This verifies the structural gatehouse slice only. Formal facade, roof, gate-leaf art, heraldry, interiors and NPC traffic remain pending. The water gate remains its existing independent placeholder. No production main-scene migration and no complete eight-map delivery is claimed.
