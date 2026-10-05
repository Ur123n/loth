# 莱顿城地图集工作日志

Updated: 2026-09-27 Asia/Shanghai
Status: eight_map_basic_graybox_runtime_verified

## 本轮目标与成果

完整阅读八区整体规划与制作计划后，优先补齐阶段1缺失的全城1:1基础连通验证。新增M02/M03/M05/M06/M08可玩灰盒；当前8/8可加载，14条城区有向连接可往返，四门可上下墙并切换三态。

本轮基础增量已验证；八区完整交付仍为0/8。没有地图达到完整美术首通S3，阶段1的真实马车转向/会车/NPC拥堵门槛仍待实现，未宣称整个地图集完成。

## 规范源与运行入口

- 规范/运行目录：C:\游戏；Godot：C:\1\Godot_v4.7.1-stable_win64_console.exe，4.7.1。
- 运行唯一布局源：maps/leyton/slice.json（0.3-eight-map-graybox）。scenes/m01..m08.tscn共用graybox_map.gd；scenes/slice_test.tscn为八区验收入口。
- 1—8跳图，WASD移动，C玩家/测试车，E上下墙，G全城共享门禁，Tab总览，T地表/灰盒，R复位。
- 整体计划：planning/莱顿城八区地图规划_v0.1.md、莱顿城八区地图制作计划_v0.1.md；当前缺口与顺序：planning/PRODUCTION_BOARD.md。
- 本轮验收边界：ATLAS_PLAYABLE_PLAN.md；证据：qa/ATLAS_PLAYABLE_QA.md。
- prepare_atlas.gd是从三图基线到八图的单次迁移工具，当前八图会触发拒绝覆盖。slice.atlas.staged.json仅保存迁移证据；后续编辑当前slice.json，不能重新用旧候选覆盖。
- C:\Users\njw\game_stage\leyton_atlas是补丁暂存，不参与运行。

## 已完成

- [x] M02 88×80、M03 96×88、M05/M06 88×72、M08 96×72场景及碰撞占位；已有三图96×80和正式结构保留。
- [x] M02三宅邸、会客所、保护水源与私家马厩；M03救济/水井/棚屋/登记/灰烬/焚尸场占位，折线主路与窄巷。
- [x] M03南侧墙让出六格出口；M06难民棚向西退让主路；M08磨坊退出河道、增加南田区检修桥与接近路。
- [x] 北南门水平墙顶、东西门垂直墙顶；未有独立门楼美术的灰盒上层覆盖完整巡逻道。已完成的M07独立WallWalk和纹理延伸保持原行为。
- [x] 四边落点均在边缘内四格，14条双向连接与2×3完整占位体连续走入触发带通过；关闭目的地门洞时留在源图安全位置。
- [x] M01↔M08双向显示经过普通住宅区的抽象路程；四个世界道路出口仍显式阻挡。
- [x] npc_spawns/event_anchors/patrol_routes结构预留；全城主要设施外侧可达接近格输出到QA报告，不作为正式门或已运行NPC。
- [x] 八张GPU总览、六张新门楼近景、一张住宅区到达图和保持宽高比的八图汇总；已直接检查汇总和代表性近景。

## 验证

- 新增全城专项349断言，failed=0；涵盖玩家/测试车路径、设施接近、四门三态、完整上层、上下墙、真实场景切换、连续出口路径和拒绝关闭入口。
- 完整相关回归：LEYTON67、ATLAS349、BRIDGE138、GATEHOUSE69、GATEHOUSE_ART24、SURFACE60、Map85、Building296、Phase one33，共1121断言通过；140脚本编译检查通过。
- 全套先通过旧版专项321断言；随后加强连续出口占位检测，重跑全城专项349通过，其余生产代码未再修改。不是仅把传送到触发带当成通行验收。
- qa/atlas_playable_report.json记录14条有向连接、连通区域和设施接近坐标；qa/test_*.log保存各测试结果。
- qa/atlas_render.json：NVIDIA GeForce RTX4060Ti，15次实际截图，failed=0；最终atlas_capture.err.log为空，导入日志无ERROR/WARNING。
- 截图汇总首次因RGB/RGBA格式不一致失败；已统一格式、加入每块像素比对后重新生成，最终通过。原始八张单图均保留。
- 图谱项目C-e6b8b8e6888f，generation=2026-09-14；本轮相关路径freshness缺失，已按Verify层级回读当前源文件并以测试和GPU运行补证。

## 备份与前序成果

- archive/pre_atlas/保存本轮前slice、graybox_map、viewer、WORKLOG、README和validate；.gdignore避免备份参与导入。
- archive/pre_gatehouse_art/和pre_gatehouse/保留更早资源与日志；未删除旧美术或备份。
- M04独立分层石桥与M07四层静态门楼继续使用原资源。本轮没有重生成或覆盖这些美术源图。
- 门楼原图SHA256与生成提示词、注册步骤见assets/buildings/leyton_west_gatehouse/README.md，前一轮详细日志见archive/pre_atlas/WORKLOG.md。

## 限制与下一步

- 新五区仍有大量建筑和农业占位块；北/南/东门未完成独立建筑美术。四门黄/红门洞仍是状态诊断显示，不是真实门扇。
- 门禁为验收控制器共享状态，正式昼夜/剧情、各门差异、NPC巡逻和事件尚未接入。
- 未完成真实马车转向/会车/拥堵、穷尽全图潜行死角审计、完整八层PNG与逐图独立JSON交付；未修改生产主场景。
- 下一项明确制作任务：按planning/PRODUCTION_BOARD.md进入阶段2的M01太阳神像需求与比例灰稿，保留8×8占地，先检查健硕、低头悲悯与俯视识别，再调用生图封装完整地标。随后推进共享农业/城防套件与西线水门/仓储。

## 变更文件

- maps/leyton/slice.json、graybox_map.gd、viewer.gd、scenes/m02/m03/m05/m06/m08.tscn。
- tools/prepare_atlas.gd、capture_atlas.gd、run_atlas_capture.ps1、validate.ps1；tests/map/test_leyton_atlas.gd。
- ATLAS_PLAYABLE_PLAN.md、planning/PRODUCTION_BOARD.md、qa/ATLAS_PLAYABLE_QA.md、README、两份规划进度附注、本日志及docs/world/rules.md、docs/development/changelog.md。
