# 莱顿城地图集工作日志

Updated: 2026-09-27 Asia/Shanghai
Status: surface_v1_preview_verified

## Objective

在 M01→M04→M07 可玩灰盒基础上接入首批地表，保持通行行为一致。

## Canonical source and runtime target

- 规范源/运行工程：`C:\游戏`。
- 地图数据：`maps/leyton/slice.json`；地表规范：`maps/godot/tilesets/leyton_surface_v1.spec.json`。
- 新资产：`assets/maps/leyton/surface_v1/`，raw/tiles/palette/prompts/manifest 齐全。
- 处理器复用 `C:\美术素材制作\tools\pixelize.py`；未覆盖旧 Codex 适配器。
- 旧规范来源与20文件哈希保留于 archive/source_manifest；本轮前脚本保留于 archive/pre_surface_v1。

## Definition of done

- [x] 用户继续推进，沿用三图灰盒布局进入首批地表。
- [x] 深水/墙顶48px与对边/色板/alpha QA通过。
- [x] 独立TileSet 139块、4地形集接入三图。
- [x] 三图三门状态69,120格次通行性一致。
- [x] 莱顿城/地表/既有地图/建筑/一期/编译回归通过。
- [x] 实际OpenGL三图总览及近景6张已检查。

## Completed

- 保留此前三图可玩灰盒全部内容及历史归档。
- 内置 image_gen 生成不可通航深水与深青石墙顶，完整提示词/源图/处理器哈希可追溯。
- 显式 tileable=True 调用已存在的像素后处理器：深水5色/L31.45，墙顶7色/L60.48。
- 复用原有dark48地面与自动拼接；道路两格土质缓冲；T可切回灰盒。
- 不改变出口、出生点、碰撞、门洞、桥梁、墙梯与生产主场景。

## Validation

- LEYTON passed=61 failed=0
- LEYTON_SURFACE passed=37 failed=0
- RESULT: passed=85 failed=0
- RESULT: passed=296 failed=0
- RESULT: passed=33 failed=0
- RESULT: scripts=136 failed=0
- 运行与PNG证据：`qa/SURFACE_QA.md`、`qa/surface_runtime_sources.json`、`qa/surface_v1_*`。
- 图谱：游戏generation=2026-09-14，目标新文件missing；美术generation=2026-09-13且tools排除，均已精确读取当前源文件。

## Pending

- 旧草地与道路平铺重复感明显，先制作兼容变体及水岸过渡。
- 桥/城墙南立面、门楼、神像、完整建筑与Prop尚未制作。
- 马车转向/会车/NPC拥堵、其余五图、NPC状态差异与生产接入待后续。
- 完整地图交付仍为0/8；本轮是首批地表预览版。

## Blockers and warnings

- 无技术阻塞。数值无缝不等于整图视觉合格；已记录真实截图中的重复感与硬水岸。
- 六项旧材质未作为整批发布，不覆盖当前美术管线的旧暂存版。

## Next exact action

先基于 qa/surface_v1_m01_detail.png 与 m04_detail.png 制作低重复草地/道路变体及水岸过渡，再更新TileSet并复用地表通行一致性测试。不要直接扩展其余五图或宣称正式美术完成。

## Runtime state

- 测试与截图进程已退出；入口 `res://maps/leyton/scenes/slice_test.tscn`。
- 原控制键保留，新增T切换地表/灰盒；生产主场景未改变。
