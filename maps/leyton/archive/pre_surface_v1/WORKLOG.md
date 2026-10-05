# 莱顿城地图集工作日志

Updated: 2026-09-27 Asia/Shanghai
Status: graybox_candidate_verified_user_review_pending

## Objective

恢复八区规划规范源，推进 M01→M04→M07 的 48px 可玩逻辑灰盒。

## Canonical source and runtime target

- 规范源/运行工程：`C:\游戏`，地图数据 `maps/leyton/slice.json`。
- 历史来源 `C:\Users\njw\codex-remote-workspace\游戏\美术素材制作`；`archive/` 保持原样，20 文件 SHA256 已核对。
- 暂存区 `C:\Users\njw\leyton_stage` 非运行源。

## Definition of done

- [x] 规划、拓扑、九张灰盒及渲染器迁入，哈希一致。
- [x] 当前规划修订河流不通航，M01 南绕进入当前数据。
- [x] 三图 Godot 场景加载并完成 61 项验收。
- [x] 既有地图/建筑/一期回归及编译通过。
- [x] 实际 OpenGL 三图截图已目视检查。
- [ ] 用户审阅灰盒布局、尺寸、马车规格与桥宽，再开始正式美术。

## Completed

- 新建 `maps/leyton/`，当前规范和历史归档分离；主场景保持现状。
- 基于 MapScene 六层及一期玩家场景实现灰盒验收控制器。
- M01/M04/M07 48px 地形、建筑占地、不可通航河流、桥梁、两格切换带及四格内出生点。
- 西门六格门洞、三种状态、三格墙顶独立通行层及上下墙梯。
- 修正 M01 建筑压河、M07 待检区压路、湖岸压主路及停车区压河；补桥并对齐水门。
- 截图发现的提示层遮挡已修正，重跑莱顿城验收与实际渲染。

## Validation

- `tests/map/test_leyton.gd`：61/61，failed=0。
- 地图 85/85；建筑 296/296；一期 33/33；编译 135/135。
- `qa/` 保存日志、三图实际渲染 PNG 与验收运行源哈希。
- 图谱 generation=2026-09-14T16:04:19Z；相关新文件 freshness=missing，已回退精确源文件读取。

## Pending

- 用户灰盒审阅；马车转向/会车与 NPC 拥堵测试尚未完成。
- 正式 Terrain/TileSet、美术、完整建筑与 Prop、其余五图、NPC、生产接入及最终分层交付。
- 六项旧基础材质未发布；当前美术管线已更新，审核时不能直接覆盖旧暂存修复。

## Blockers and warnings

- 无技术阻塞；灰盒为待审候选，正式地图交付仍为 0/8。
- 保留项目已有改动；未启动正式生图。

## Next exact action

打开 `maps/leyton/scenes/slice_test.tscn`，WASD/C/E/G/Tab 验收三图；审阅 `qa/m01_overview.png`、`m04_overview.png`、`m07_overview.png` 后决定布局调整，再进入美术制作。

## Runtime state

- 验收与截图进程已退出；规范源与加载路径均为 `C:\游戏`。
- 入口：`res://maps/leyton/scenes/slice_test.tscn`；未改生产主场景。
