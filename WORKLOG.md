> 2026-10-04：当前任务是卡牌重制逻辑，进度、验证、剩余机制与下一步见 [dev/card_redesign_v1/WORKLOG.md](dev/card_redesign_v1/WORKLOG.md)。根日志下方的地图记录是历史项目交接，不代表当前卡牌任务状态。

> 2026-09-27: Leyton shared props batch 01: six generated assets, candidate FreeProp scenes and GPU review sheet; 131 relevant checks passed. See [maps/leyton/WORKLOG.md](maps/leyton/WORKLOG.md).

# Work Log

Updated: 2026-09-27 Asia/Shanghai
Status: complete

## Objective

Complete the map architecture plan's phase-one vertical slice without changing the production map: terrain/road, reusable house pattern, independent large-building scene, free prop, player collision/Y-sort, roof behavior, scene door/interior, and large-building ghost/anchor preview.

## Canonical source and runtime target

- Canonical source: `C:\游戏`
- Runtime/deployed copy: `C:\游戏` (Godot `--path C:\游戏`)
- Other copies or caches: `C:\Users\njw\game_stage` is a temporary patch staging area only; `.godot/` is generated cache and will not be edited.

## Definition of done

- [x] New and changed files parse or compile: 134/134 scripts.
- [x] Phase-one map test passes: 33/33, `failed=0`.
- [x] Existing map pipeline baseline passes: 85/85.
- [x] Existing building pipeline baseline passes: 296/296.
- [x] Runtime loads `res://dev/map_pipeline_test/map_pipeline_test.tscn` from `C:\游戏` without script errors.
- [x] Actual OpenGL render captured at 1280×720 and a low-resolution overview was visually checked; controls and remaining manual playthrough are documented.

## Completed

- Located canonical/runtime project and read project/world/building instructions.
- Confirmed Godot `4.7.1.stable.official` at `C:\1\Godot_v4.7.1-stable_win64_console.exe`.
- Audited existing implementation: large-building data/prefab/collision/roof/CLI placement exist; phase-one unified lab, house pattern, free prop, interior door, and building ghost do not.
- Recorded clean baselines for both existing map tests.
- Added reusable `BuildingGhost`, pattern library/instance, `FreeProp`, and `SceneDoor` components.
- Added `house_a`, `roadside_rock`, phase-one exterior/interior scenes, player controller, and focused acceptance test.
- Updated root/world/test documentation and changelog without changing the production main scene.

## Validation

- Command/check: `tests/map/test_building_pipeline.gd`
- Result: `passed=296 failed=0`
- Command/check: `tests/map/test_godot_map_pipeline.gd`
- Result: `passed=85 failed=0`
- Command/check: `tests/map/test_map_pipeline_phase_one.gd`
- Result: `passed=33 failed=0`
- Command/check: `tests/dev/test_script_compile.gd`
- Result: `scripts=134 failed=0`
- Command/check: run lab for 3 frames and hidden OpenGL screenshot capture.
- Result: scene exit 0; NVIDIA/OpenGL render produced 1280×720 PNG; low-resolution overview shows terrain/road, graybox house, player/prop and large-building composition without blank/missing layers.
- Limitations: automated input proves structural behavior; a detailed hands-on GUI playthrough remains optional user acceptance.

## Pending

- Optional: open the lab in Godot and manually exercise WASD/E/F/G/left-click before promoting any part into a production map.
- Phase two (Pattern Palette, World Editor, chunks/export) remains intentionally out of scope until phase one is accepted.

## Blockers and warnings

- The codebase-memory MCP transport closed at session start, so graph queries were unavailable. Discovery fell back to bounded reads/`rg` in the world/building/map/test scopes.
- The canonical project has many pre-existing modified/untracked files. New work must not overwrite unrelated changes.

## Next exact action

Open `res://dev/map_pipeline_test/map_pipeline_test.tscn` for optional manual acceptance; do not migrate the production map until accepted.

## Changed paths

- `core/building/building_ghost.gd` - validated large-building preview and runtime-only placement.
- `core/world/{map_pattern_library,map_pattern_instance,free_prop,scene_door}.gd` - reusable map-object components.
- `content/map_patterns/house_a.json`, `world/patterns/house_a.tscn`, `world/props/roadside_rock.tscn` - first content examples.
- `dev/map_pipeline_test/` - exterior/interior phase-one lab and player.
- `tests/map/test_map_pipeline_phase_one.gd` - 33 focused assertions.
- `README.md`, `docs/world/*`, `tests/README.md`, `docs/development/changelog.md` - behavior and validation docs.

## Runtime state

- Process/PID: no Godot process remains after baseline tests.
- Port/health: not applicable.
- Active instance/world/workflow: no running instance; canonical files are under `C:\游戏`.
- Restart or cache refresh required: none for headless use; opening the project may generate normal `.uid` editor metadata.

## Latest handoff — 2026-09-28

修道院—莱顿移动Demo及基础灰盒材质已完成本轮验收。当前任务详情见dev/leyton_world_demo/WORKLOG.md；四张image_gen原图与提示词见assets/maps/leyton/basic_materials_v1/。入口：启动莱顿大世界审验.bat。原地图一期记录保留为历史。


## Latest handoff — 2026-10-04 map workflow

地图制作闭环、12×10m灰盒、哈希复核门禁和碰撞锚点修复已完成。验证与独立战斗AI冒烟问题见 [docs/art/map_workflow_20261004/WORKLOG.md](docs/art/map_workflow_20261004/WORKLOG.md)。正式美术尚未批准；样板入口在游戏根目录。

## Latest handoff — 2026-10-04 hall art v1

会堂三层美术候选已完成运行验证，398项检查通过，GPU轮廓差异为0；未正式发布。详见[dev/hall_art_v1/WORKLOG.md](dev/hall_art_v1/WORKLOG.md)。

## Latest handoff — 2026-10-04 art manual v2

新版制作指导手册已按用户确认的会堂路线完成，旧技术正文退出现行入口，非技术设计与需求保留；29份文档验证通过。规范源：C:/美术素材制作/docs/地图与大型建筑制作指导手册.md；详情见docs/art_manual_v2_20261004/WORKLOG.md。

## Latest handoff — 2026-10-05 map version guides

Codex版伊瑟拉修道院与莱顿城更迭指南已完成：C:/游戏/docs/world/version_guides/README.md。修道院贴图更换已获用户授权；本轮仅交付文档，未改地图。12个新增链接/11个命令路径校验通过，43个运行源哈希不变。详见该目录WORKLOG.md。

## Latest handoff — 2026-10-05 map rework candidates

伊瑟拉修道院与莱顿 M02 的视觉重制候选经用户确认后已发布到活动入口。默认主场景和九图 Demo 修道院、活动 M02 的发布检查 17/17 通过；发布后完整地图回归 13/13、160 个脚本编译及实际 GPU 截图均通过。23 个基线源保持不变，2 个活动场景按清单切换；发布前备份、哈希、回退路径见 `dev/map_versions/map_rework_20261005_r01/release_manifest.json` 和该目录 `WORKLOG.md`。
