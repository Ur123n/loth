# 莱顿城地图集工作日志

Updated: 2026-09-27 Asia/Shanghai
Status: M04_bridge_layered_art_runtime_verified

## Objective / 当前完成范围

M04货运石桥：将v2源稿注册到48px网格，分离桥面与护栏，接入角色排序，保持通行和碰撞不变。此增量已完成；完整地图集尚未完成。

## Canonical source and runtime target

- 规范源/运行工程：`C:\游戏`；Godot `C:\1\Godot_v4.7.1-stable_win64_console.exe`，4.7.1。
- 运行入口：`maps/leyton/scenes/slice_test.tscn`，按4进入M04。
- 结构规范：`assets/buildings/leyton_cargo_bridge/building.spec.json`；唯一独立场景 `LeytonCargoBridge.tscn`。
- 原稿：`source/concept_v2.png`；SHA256及注册控制线存于 `source/registered_v2/registration.json`。
- 运行层：`visual/base.png`（护栏）+ `visual/deck.png`（桥面）；由已注册的rails/deck源图经过既有Building生成器输出。
- 可恢复旧版本：`maps/leyton/archive/pre_bridge_layers/`（完整旧资产包、viewer、graybox_map、桥测试、日志），含.gdignore避免备份UID被导入。
- `C:\Users\njw\game_stage\leyton_bridge_layers`仅为补丁暂存，运行不依赖它。更早的archive/pre_bridge和源稿v1/v2均保留。

## Definition of done / Completed

- [x] 672×624共画布、(48,48)原点、四周1格透明留白；北/南各一整行无护栏。
- [x] 源图按桥头/护栏接缝确定性配准；不重画、不从alpha推断碰撞；分层能逐RGBA重建已注册原稿。
- [x] 护栏严格位于x=48..95 / 576..623、y=96..527；桥面在角色下方。
- [x] 沿用Building语义切带：2条非空护栏带和3条透明覆盖带（满足画布完整覆盖校验），仍是整座Prefab，不拆成Tile。
- [x] viewer玩家/马车与护栏同YSort父节点；换图前将玩家移出旧地图，保留相机；马车矩形从viewer绘制移至玩家子节点。
- [x] M04左上(42,59)，12×11占地、132占用、114可走、18阻挡、2入口、2碰撞矩形均不变。
- [x] 独立包校验、通行、换肤、切图生命周期、图层像素、实际GPU遮挡及回归全部通过。
- [x] 已检查实际OpenGL截图：玩家、马车、南端前景站位、侧面站位；另用合成探针验证同像素的前/后遮挡。

## Validation

- LEYTON 61；LEYTON_BRIDGE 138；LEYTON_SURFACE 60；Map pipeline 85；Building pipeline 296；Phase one 33：共673项断言，failed=0。
- `tests/dev/test_script_compile.gd`：137脚本，failed=0；新增注册脚本已实际执行，截图脚本另行check-only并实际执行。
- `building_tool.gd -- validate --id leyton_cargo_bridge`：ok=true，errors=0，warnings=0。
- `prepare_bridge_art.gd`：672×624、exact_layers=true、failed=0。
- NVIDIA RTX4060Ti / OpenGL：`qa/bridge_art_render.json`，front/behind均passed=true，failed=0。
- `qa/bridge_art_player.png`、`bridge_art_cart.png`、`bridge_art_south_front.png`、`bridge_art_side_behind.png`、`bridge_art_probe_{front,behind}.png`。
- 截图错误日志为空；最终导入无ERROR/WARNING。原PNG读取提示已改为PNG字节解码，测试不再产生该警告。
- 图谱generation为2026-09-14、相关freshness缺失；结构查询后已读取当前源文件，未依赖旧索引得出完成结论。

## Pending / limitations

- 城墙立面、M07西门楼、其余完整建筑/Prop、剩余五图和生产主场景接入仍待制作；完整地图交付仍0/8。
- 当前玩家与马车仍是测试占位图形；未实现马车转向、会车和NPC拥堵。
- 原始v2图仍为1301×1209，只允许使用注册导出的图层参与运行。
- 生成器默认preview/preview.png显示Base护栏层；完整桥外观看source/registered_v2/registered.png或本轮运行截图。
- 本次不增加桥下侧拱、立面或航运；完整桥美术的后续风格调整仍可单独迭代。

## Next exact action

推进M07西门楼结构灰盒：先读取BRIDGE_PLAN.md及slice.json，锁定(85,32,11,16)占地、y=37..42六格东西门洞、x=92..94三格墙顶、墙梯与水闸独立通路。先验证地面/墙顶高度与门状态，再做完整建筑概念；不可把门楼拆成图块。

## Changed paths

- `maps/leyton/tools/prepare_bridge_art.gd`、`capture_bridge_art.gd`：可重现注册和实际渲染验收。
- `assets/buildings/leyton_cargo_bridge/`：spec、注册图层/记录、运行视觉、metadata、Prefab、README。
- `maps/leyton/viewer.gd`、`graybox_map.gd`：玩家/马车和建筑共同排序、换图生命周期。
- `tests/map/test_leyton_bridge.gd`：增加70项图层/排序/生命周期断言。
- `docs/world/rules.md`、`docs/development/changelog.md`、石桥README与`qa/BRIDGE_ART_QA.md`：规范及结果。

## Runtime state

- 本轮导入、测试、截图实例均已退出；无遗留后台进程。
- 当前运行资源为分层石桥+v2地表；生产主场景未替换。
