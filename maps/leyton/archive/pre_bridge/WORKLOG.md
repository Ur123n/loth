# 莱顿城地图集工作日志

Updated: 2026-09-27 Asia/Shanghai
Status: surface_v2_preview_verified

## Objective

降低三图草地/道路重复感，补齐草土水岸过渡，保持通行与布局。

## Canonical source and runtime target

- 规范源/运行工程：`C:\游戏`；入口 `maps/leyton/scenes/slice_test.tscn`。
- 数据：`maps/leyton/slice.json`；当前地表清单 `maps/godot/tilesets/leyton_surface_v2.spec.json`。
- 当前新资产 `assets/maps/leyton/surface_v2/`；水体/墙顶仍引用surface_v1。
- 新源图由内置image_gen生成，像素处理复用美术工程pixelize.py；生成/派生脚本 `maps/leyton/tools/prepare_surface_v2.py`。
- 历史20文件归档、v1资产与截图保留；v2前源码及工作日志在archive/pre_surface_v2。

## Definition of done

- [x] 草/土/路新基础图入库，48px/色板/alpha/对边通过。
- [x] 草地/道路各4种共边变体；重建64块过渡；81种混合水岸组合。
- [x] 当前TileSet156块、4来源、2地形集；三图运行加载。
- [x] 水岸阻挡、方向、变体稳定性、三图全格通行及既有回归通过。
- [x] 六张实际渲染截图已查看，与v1比较。

## Completed

- 低对比材质替换：草L46.47/土77.23/路98.50；基础图亮度标准差相对旧图下降约43%/41%/60%。
- 草/道路变体共享3px边缘，以坐标hash稳定选取；未翻转图块。
- 草→土、土→路使用新底材重建；水格按四邻无岸/草岸/土岸三值组合选取湿岸。
- 水岸最多进入原水格约7px，全部仍阻挡；不改布局/门洞/桥梁/出口与生产主场景。
- 构建器地形默认颜色警告已通过清单显示名修正。

## Validation

- LEYTON passed=61 failed=0
- LEYTON_SURFACE passed=60 failed=0
- RESULT: passed=85 failed=0
- RESULT: passed=296 failed=0
- RESULT: passed=33 failed=0
- RESULT: scripts=136 failed=0
- 素材580条边缘检查通过；三图三门状态69,120格次通行保持一致。
- `qa/SURFACE_V2_QA.md`、`surface_v2_results.json`、`surface_v2_runtime_sources.json`保存证据。
- 六张1280×720实际OpenGL截图：`qa/surface_v2_*`；重复草丛与横带明显减弱。
- 图谱仍为旧generation，游戏新增路径missing、美术tools排除；已按要求读当前源文件。

## Pending

- 桥梁与城墙立面、栏杆、门楼、神像、完整建筑、Prop尚未制作；建筑目前仍是占地块。
- 现有岸线沿方格几何，四邻混合交点角像素不是整边无缝承诺；地表还有细节迭代空间。
- 马车转向/会车/NPC拥堵、其余五图、NPC状态差异与生产接入待后续。
- 当前仍为三图地表预览，完整地图交付0/8。

## Blockers and warnings

- 无技术阻塞。用户已多次授权继续推进，不需为相同阶段重复请求许可。
- 完整建筑遵守需求/概念→整图→分层→独立碰撞→场景的既有管线。

## Next exact action

读取docs/world/building_pipeline.md与莱顿规划，先为M04货运石桥、M07城墙/西门楼落实占地、南立面、锚点和遮挡需求，制作小范围结构草稿并接入当前三图；保留原逻辑通路。

## Runtime state

- 测试/截图进程已退出；当前默认地表v2，T切回灰盒。
- 生产主场景未改变；v1资源和历史归档保留。
