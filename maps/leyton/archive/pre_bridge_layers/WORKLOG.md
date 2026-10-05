# 莱顿城地图集工作日志

Updated: 2026-09-27 Asia/Shanghai
Status: bridge_concept_v2_reviewed; registered_layers_and_occlusion_pending

## 本次续作：2026-09-27 修订稿 v2

- 已交付：`assets/buildings/leyton_cargo_bridge/source/concept_v2.png`、完整提示词 `exact_bridge_prompt_v2.txt`、像素检查脚本 `inspect_bridge_art.ps1`、`ART_REVIEW_V2.md`。
- 内置 image_gen 以 v1 和灰盒双参考修图；北端开放桥头恢复、桥面改为错缝石板，已直接查看生成结果。
- 像素检查：1301×1209、真实透明通道；alpha>=128 包围框 [91,95,1210,1110]。目标画布为672×624，不能直接认定与碰撞对齐。报告：`qa/bridge_concept_v2.json`。
- 规范源与运行路径仍为 `C:\游戏`。此次仅添加候选源稿和检查材料；spec / Prefab / base.png 未替换，当前运行资源仍是灰盒桥。
- 当前 viewer 的地图根 z=-1、玩家在独立父节点；正式护栏接入需统一排序域。此项来自当前源文件读取，图谱 generation 仍为2026-09-14，相关 freshness 缺失。
- 本增量验收：源稿保存、提示词溯源、透明度/尺寸检查、视觉检查；不代表正式建筑美术或角色遮挡完成。
- 本次复测 `maps/leyton/tools/validate.ps1` 全部通过：61+68+60+85+296+33=603项断言，137个脚本编译检查，failed=0。当前场景在测试中实际实例化；本次未重新截图，旧灰盒截图不能作为v2运行验收。
- 检查脚本初次运行遇到 Windows PowerShell 中文字面路径解码问题，已改为从脚本位置解析工程根目录，复测成功。
- 下一步：按 `ART_REVIEW_V2.md` 注册导出桥面/护栏，验证像素合成和桥头，再接入 Building 与玩家共同排序域。

以下为此前已完成的灰盒增量记录；上述本次复测已确认其测试基线仍然通过。

## Objective

继续地图集结构开发，先以 M04 石桥验证完整 Building 资产接入，再推进正式视觉与西门楼。

## Canonical source and runtime target

- 规范源 / 运行工程：`C:\游戏`；入口 `maps/leyton/scenes/slice_test.tscn`。
- 布局 `maps/leyton/slice.json`；M04 bridge 新增 prefab 引用。
- 结构规范 `assets/buildings/leyton_cargo_bridge/building.spec.json`；场景 `LeytonCargoBridge.tscn`。
- 当前运行贴图 `visual/base.png` 来自 `visual/source_graybox.png`；概念 `source/concept_v1.png` 没有接入运行。
- 内置 image_gen 原图和准确提示词保存在上述 source 目录。
- 当前地表仍为 leyton_surface_v2；历史20文件、v1/v2资产与截图保留。
- 本次改动前脚本 / slice / 日志位于 `archive/pre_bridge/`；暂存目录不是规范源。

## Definition of done for this increment

- [x] 建筑分类、需求与测量概念先落实；详见 BRIDGE_PLAN.md。
- [x] 完整 Building 包通过既有生成器输出，未修改核心建筑系统。
- [x] M04 实际实例化，12×11占地、114可走、18阻挡、2入口、2碰撞矩形。
- [x] 玩家与2×3马车通行、护栏阻挡、切图和换肤检查通过。
- [x] 实际 OpenGL 玩家 / 马车截图已检查。
- [ ] 正式桥梁美术尺寸、分层、遮挡验收（后续增量）。

## Completed

- 新增 generic prefab 装载支持：仅加载 slice 中显式声明的独立结构。
- M04左上 (42,59)，护栏局部 x=0/11、y=1..9；18格由旧桥面可走改为阻挡。
- 两端整行桥头开放，中央10格净宽；原6格引道与2×3马车路线通过。
- 地表切换不重复实例化、不改变结构碰撞；M01/M07不加载石桥。
- 一张完整桥梁概念生成并保存；北端护栏侵入预留桥头、铺装重复，保持概念状态。
- M07六格门洞、三格墙顶、墙梯及水闸约束记录在 BRIDGE_PLAN.md。

## Validation

- LEYTON passed=61 failed=0
- LEYTON_BRIDGE passed=68 failed=0
- LEYTON_SURFACE passed=60 failed=0
- Map pipeline passed=85 failed=0
- Building pipeline passed=296 failed=0
- Phase one passed=33 failed=0
- Script compile scripts=137 failed=0
- 共603项断言通过；验证命令 `maps/leyton/tools/validate.ps1` 已加入石桥测试。
- 实际 NVIDIA OpenGL 1280×720：qa/bridge_graybox_player.png、bridge_graybox_cart.png；截图错误日志为空。
- 图谱 generation 2026-09-14，相关路径 freshness missing；已回读当前源文件，未以旧索引代替实际验证。

## Pending / limitations

- 桥仍为精确灰盒；生成图未被当作合格贴图。当前没有正式立面、前景分层和角色遮挡。
- 首图虽然平行投影正确，但北端护栏越过桥头；后续必须修图并测量，不可直接缩放上线。
- 城墙立面、西门楼、完整建筑、Prop、剩余五图、生产接入仍待开发。
- 马车转向/会车/NPC拥堵未实现；完整地图交付仍0/8。

## Next exact action

v2源稿已经生成并保存。接下来以 source/concept_v2.png 和 visual/source_graybox.png 注册导出672×624共画布桥面/护栏层；核对桥头与18格护栏逻辑，再统一viewer玩家和护栏排序域并验证实际遮挡。不要直接将未注册源稿替换base.png。

## Runtime state

- 验证与截图进程均已退出；当前运行资源是灰盒桥+v2地表。
- 无技术阻塞；用户已授权持续推进，无需重复请求同阶段许可。
