# 变更日志

## 2026-10-05 顶牌可选弃置

- `inspect_top_cards` 支持“至多弃置”与主动结束弃置，A042 完整接入；其他必选阶段不显示跳过按钮。顶牌选择测试 33 项、目录 123/300 及战斗、存档回归均 `failed=0`。

## 2026-10-05 顶牌查看与排序事务

- 新增 `inspect_top_cards` 共用机制，以实体牌完成查看牌顶、选牌入手/弃置和玩家指定剩余顺序；A006、A029、A036、A068 完整接入，可运行牌增至 122/300。
- 定向顺序测试 21 项、目录、旧卡逻辑、战斗和存档回归均 `failed=0`。

## 2026-10-05 卡牌实体牌序与选择费用

- A019、B071、D034 使用共用选择机制接入完整规则：展示全部 Basic、仅本行动费用修正、手牌保留及选择后格挡续行。
- 核实有序实体抽牌堆，修复同名多张卡共享 Resource 和随机转移按对象删除的问题；开战与生成牌逐张实例化，普通抽牌仍按牌顶固定顺序。实体牌序测试 6 项、重制逻辑 201 项及目录 118/300 均 `failed=0`。

## 2026-10-05 重制卡牌选择事务

- 扩展实体牌选择的候选过滤、手牌目的地与选中实体的下次打出消耗；K060、D059、A063 接入，目录达到 115/300 可运行。
- 出牌在玩家选择时暂停，提交后续行剩余效果，再记录出牌与离场；修正连续选择的弹窗显示顺序。重制逻辑 183 项及相关目录、界面、战斗、存档测试均 `failed=0`，主场景与战斗场景无头加载无脚本错误。

## 2026-10-05 修道院与莱顿城Codex更迭指南

- 新增两份地图专用指南、通用版本流程、任务模板与当前源哈希快照。
- 明确修道院贴图可更换；区分活动八区、街坊v3样段、材质替换和室内功能升级。
- 核对共享依赖、生成器覆盖行为、测试与回退步骤；本轮只交付指南，不执行地图改版。

## 2026-10-04 新版美术制作指导手册

- 以已确认的会堂样板统一制作方法，明确灰盒逻辑与分层材质的职责。
- 移除现行文档里的旧技术路线，保留美术风格、世界观、尺寸、修道院设计及资产需求；旧原文按哈希备份。
- 更新游戏/美术入口和Agent规则；仅文档变更，现有运行程序与资产未修改。

## 2026-10-04 地图样板BAT启动路径修复

- 修复会堂美术、地图灰盒两个启动器的末尾反斜杠引号解析问题；失败保留报错，支持诊断参数。通过BAT实际图形启动验证。

## 2026-10-04 会堂分层美术审验样板

- 新增独立会堂美术场景与启动器，支持C键对照灰盒；复用现有几何、门、碰撞和屋顶隐藏。
- 三层生成原图用作材质，运行时保留灰盒alpha并映射地图色板；目前为候选，未正式发布。
- 17项样板、85项地图、296项建筑检查通过；GPU逐像素alpha差异为0。
- 来源、提示词和验证记录见dev/hall_art_v1/WORKLOG.md。

## 2026-10-04 地图制作闭环与建筑灰盒

- 新增配置驱动建筑转换和统一构建入口，复用 Godot 原生成器；完整建筑包进入既有 agent_assets 审核、发布和回滚流程。
- 复核记录绑定批次及产物哈希；新建筑要求 visual/engine 两项复核，旧图片批次兼容。
- 新增12×10米独立灰盒实验场和实际物理/门/屋顶/语义排序测试。
- 修复 Building 碰撞、门和交互子节点未减去底部中心锚点的问题；运行时幂等修正旧Prefab，新Prefab写入正确偏移。
- 详细操作与验证结果见 docs/world/map_production_workflow.md 和 docs/art/map_workflow_20261004/WORKLOG.md。

## 2026-10-04 牌堆随机展示与玩家选择

- 增加可复用的 `choose_from_pile` 机制：按实体牌无放回抽取候选，玩家选一张置于抽牌堆顶，未选中的牌保留原顺序；选择期间冻结战斗输入。
- A017、A054、D027、K026 接入该机制，卡面资源继续留空。

## 2026-10-04 牌区事务与出牌前条件

- 机制数据库新增随机转移实体牌、其他手牌洗回重抽、出牌前硬性条件；A024、D071、K067 改为可运行，可用卡池升至 108 / 300。
- 验证无合法候选、Power 排除、重抽数量、生命 25% 边界以及拒绝出牌不扣资源；剩余卡机制索引同步更新为 192 张。
- 机制、卡牌、战斗、存档九项无头测试通过，两个主场景无头加载通过。

## 2026-10-04 共用机制模板组合卡牌

- 复用已验收机制，批量接入 A012/A022/A047/A052、D056/D057、K027/K034/K048、B031 十张重制牌；可用卡池升至 105 / 300。
- 出牌前 Armor 快照机制用于 A022/A047/K034；其余卡牌组合出牌历史、直接失血、移动、推动与三梦状态链。
- 重制逻辑 143 项断言通过；机制、卡牌、战斗、存档九项无头测试及两个场景加载均通过。

## 2026-10-04 重制卡牌机制优先整理

- 盘点剩余 205 张设计牌，生成逐牌候选机制索引，并按 12 个可重叠家族制定实施依赖顺序。
- 机制库新增“出牌前目标格挡不少于/不高于阈值”两个可调用条件；结算开始时固定目标格挡快照，避免同牌前段攻击改变后段判断。
- 本轮先完成机制与测试，卡池仍为 95 / 300；卡牌接入将在机制依赖完备后进行。

## 2026-10-04 友军移动与梦态切换

- 新增 K006、K022、K033、A032 四张可用牌，重制卡池升至 91 / 300。
- `move` 效果可将额外移动距离给予所选友军；`set_dream_state` 可立即切换重制梦态，并用结算前梦态快照决定同牌后续条件。
- 真实战斗测试验证移动力归属、Drug 条件两侧与幻梦回沉梦；新增机制登记到数据库。

## 2026-10-04 出牌历史、毒层数与状态正常结算

- 新增 D016、D018、D052、B045、K050、K042、K063、K039、A031 九张可用牌，重制卡池升至 87 / 300。
- 出牌者记录本行动此前成功打出的牌，支持 Dagger/Pistol Attack 条件；目标生命百分比、目标毒层数条件与按毒层数直接失血均登记到机制数据库。
- `trigger_buff` 复用既有状态触发与衰减流程，使 K039 可立即正常结算目标毒一次；K063 仅读取毒层数，不触发毒或减少层数。
- 卡牌、战斗、存档回归均 `failed=0`，主场景和战斗场景无头加载通过。

## 2026-10-03 卡牌机制数据库与友军条件

- 新增 `content/cards/mechanics.json`，登记 8 类可参数化效果、14 类条件、放血攻击修正与 2 类出牌规则；导入器按模板实例化新牌效果，为 78 张已启用重制牌写入 `mechanism_ids`。
- 编辑器条件清单与预览文案补齐梦态、目标状态、目标移动、相邻和生命门槛；目录测试校验机制引用与实际效果一致。
- 新增 A004、A015、A016、A027、B054 五张可用牌，运行时升至 78 / 300；真实战斗测试覆盖目标格挡、双目标格挡、友军移动与相邻人数两侧。

## 2026-10-03 梦态与生命门槛卡

- 新增 A011、A013、B017、B033、B042、B055 六张可用牌，重制卡池运行时数量升至 73 / 300。
- 沉梦条件格挡读取结算时的梦态；未移动条件分别控制格挡替换与额外疗愈；放血换费先支付生命再获得费用。
- 真实战斗测试覆盖条件两侧、35% 生命边界和致死生命支付拒绝；卡牌、战斗、存档回归通过。

## 2026-10-03 目标条件施毒

- 新增 K015、K036、K041 三张可用牌，重制卡池运行时数量升至 67 / 300。
- 效果条件可读取本张牌结算前的目标状态；K036 前段新施加的毒不会触发后段追加毒。K041 按出牌者本回合对指定目标造成的直接失血判断。
- 卡牌、战斗、存档回归均通过，主场景和战斗场景无头加载无脚本错误。

## 2026-10-03 移动格挡与疗愈

- 新增 A021、B018、B019、B020、B043、B044 六张可用牌，重制卡池运行时数量升至 64 / 300。
- 复用现有移动、格挡、疗愈与生命支付逻辑；放血牌先支付生命，再按文字顺序获得状态。
- 战斗测试逐张验证移动力、格挡、疗愈层数和生命支付。

## 2026-10-03 多段攻击与复合状态

- 新增 A030、D015、D063 三张多段攻击牌和 K012、K016、K037 三张毒/虚弱复合状态牌，重制卡池运行时数量升至 58 / 300。
- 多段攻击逐段处理格挡和生命；目标在某段倒下后停止后续段，避免重复触发击败。
- 真实战斗测试覆盖分段格挡、五段攻击、中途击败和两种状态同时落到所选敌人。

## 2026-10-03 放血条件伤害

- 新增 B005、B022 两张可用牌，重制卡池运行时数量升至 52 / 300。
- 成功支付放血牌生命后记录本行动已放血；两张攻击牌分别从 11→14、12→16 面板伤害，普通失血不触发，行动结束清空。
- 条件替换伤害复用现有 `AttackEffect.alt_value`，并以 `alt_condition` 区分放血与旧版移动条件。

## 2026-10-03 同回合直接失血精密牌

- 新增 K030、K031、K044 三张可用牌，重制卡池运行时数量升至 50 / 300。
- 出牌者按目标记录本回合卡牌效果实际造成的直接生命损失；普通攻击伤害、毒结算与自身生命支付不计入，行动结束清空。
- `caster_moved_this_turn` 与 `target_lost_direct_hp_this_turn` 两类降费条件接入现有费用规则；真实战斗测试验证格挡、不同目标与回合边界。

## 2026-10-03 精密条件降费第一批

- 新增卡莎 K009、K010、K028、K029 四张可用牌，重制卡池运行时数量升至 47 / 300。
- 出牌时依据所选目标的中毒/虚弱状态、毒层数以及本回合对同一目标使用过的 Drug 标签计算实际费用；合法降费可叠加，最低 0，不消耗目标状态。
- 手牌显示基础费用与可能的最低费用；战斗测试覆盖条件成立/不成立、不同目标隔离、回合清理和费用不足时不扣资源。
- 具体批次与验收标准见 `dev/card_redesign_v1/IMPLEMENTATION_PLAN.md`。

## 2026-10-03 卡牌逻辑第一批

- 重制卡牌运行时数量由 27 增至 43（艾莉丝 7、迪马斯 12、卡莎 10、鲍德温 14）；其余 257 张继续保留设计稿状态。
- 新增友军格挡、直接治疗、生命支付与致死支付拦截、低血量条件；接入艾莉丝重制三梦切换和沉梦结束行动格挡。
- 用真实战斗测试验证新牌的目标、结算顺序、格挡穿透与费用/生命支付；卡牌、战斗、存档回归及主场景/战斗场景无头加载通过。
- 旧版卡面预览测试改为核对旧版生成物，不再要求本轮重制牌带卡面。

## 2026-10-03 四角色卡牌重制 v1.0 数据导入

- 按根目录四份重制文档生成 300 张卡牌 JSON，包含完整规则原文、费用、Load、目标、标签、来源位置；卡面字段留空。
- 当前 27 张纯基础效果牌可完整结算并进入 CardDB；其余 273 张标为 `design_only`，CardDB 不加载，避免空效果牌进入战斗。
- 导入脚本为 `dev/import_card_redesign_v1.py`；测试 `tests/card/test_redesign_catalog.gd` 核对 300 张及运行时筛选。

## 2026-09-28 四角色卡组接入（进行中）

- 根目录四套设计稿已解析为 300 张唯一卡牌数据；当前 35 张效果可由战斗引擎准确结算，其余保留待实现状态，不进入正式牌库。
- 已将 9 张具备完整效果和卡面的卡牌发布到正式牌库；卡面使用角色参考图和素材生成管线制作，按项目色板输出 144×216 像素，并经过人工视觉复核与 QA。
- 扩展卡牌 ID、角色、稀有度、标签、原文说明、最小射程与战斗目标校验；中毒现在于回合结束按当前层数失去生命后再衰减。
- 后续卡面与复杂效果持续分批接入，详见 `dev/card_import/WORKLOG.md`。

## 2026-09-28 修道院—莱顿移动审验与基础材质

- 完成独立九图移动Demo：修道院出生向南进入北门城外，16条有向连接、门禁安全到达、M路线图；东侧住宅区保留抽象路程。入口为根目录启动莱顿大世界审验.bat。
- 内置image_gen生成暗瓦、耕土、旧木板、踩实泥地，转换为48px项目色板，替换16,734格基础色块；完整建筑、细节和区域边界美术后续补。
- 地表atlas采用独立source1001和深拷贝metadata，保留灰盒切换、原碰撞及完整建筑Prefab。新增51项全格三态通行/资源隔离检查并纳入地图回归。
- 当前版本相关回归与GPU截图完成，详细数字、限制和产物见dev/leyton_world_demo/WORKLOG.md。



## 2026-09-27　地图架构第一阶段实验场

- 新增 `dev/map_pipeline_test/`，在不迁移正式地图的前提下统一验证 Terrain/道路、完整小屋 Pattern、大型建筑 PackedScene、自由 Prop、玩家 YSort、Roof、SceneDoor 与独立 Interior。
- 新增 `BuildingGhost`：复用大型建筑 metadata/Prefab 与 `BuildingValidator`，显示完整半透明视觉、Footprint 网格、Anchor、Entrances 和放置合法性；运行时左键放置不写盘，持久化仍走 `BuildingPlacer`。
- 新增数据驱动 `map_pattern/1` 与 `MapPatternLibrary`，`house_a` 可一次调用完成整栋 Stamp；新增 `FreeProp` 与通用 `SceneDoor`，避免把所有对象塞进 TileSet。
- 新增 `test_map_pipeline_phase_one.gd`：33/33；全脚本编译 134/134，既有建筑管线 296/296、地图管线 85/85，实验场无头运行加载无错误。

## 2026-09-14　移除旧地图管线并建立自动化质量门禁

- 删除 Tiled/YATI、TMX 测试、旧 16px TileSet/样例场景以及 v1 spec 兼容代码；地图统一为 Godot 48×48 TileMap/TileSet 管线。
- `core/world/main.gd` 默认底图改为高原修道院，地图尺寸与关键点统一由 `MapScene` 提供；项目不再启用 YATI 编辑器插件。
- 地图测试移除旧管线断言并保留 48px 图块、自动拼接、场景、运行时接口和画面构成校验。
- `tests/dev/test_script_compile.gd` 改为递归发现全项目 GDScript；新增 `tests/run_all.ps1` 与 GitHub Actions CI，统一运行导入、测试、内容校验和场景冒烟。

## 2026-09-14　高原修道院正交无透视重制

- 推翻带近大远小和远端收窄的旧修道院原画，按 `orthogonal_3q_48_v1` 重做为无消失点的正交斜投影：矩形中庭、平行主轴、前后等宽、重复构件等比例。
- 新图使用内置图像生成流程产出洋红底结构稿，经标准去色键、50×60 格整数放大和大型建筑分层脚本生成 Structure / Shadow / WarmLight；碰撞、占地、门和语义切带继续独立维护。
- 更新建筑预览与 4032×4224 地图整图预览；Godot 实机 1280×720 目检无切带接缝，角色与水井遮挡正确。建筑管线 296/296、地图管线 129/129，建筑与地图结构化校验均为 0 error / 0 warning。

## 2026-09-14　战斗六边格与尸骸状态统一

- 战斗六边形以边长 20 px 为唯一几何基准，`BattleMap`、`BattleMapData`、`BattleMapView` 共用 `HexGrid.DEFAULT_SIDE_LENGTH`。
- 玩家与敌怪统一为“首次死亡转尸骸、尸骸再次归零后移除”；回合、目标选择和胜负判断均排除尸骸。
- 角色/敌怪数据新增 `corpse_art_a`、`corpse_art_b`，按单位稳定种子选择尸骸贴图；素材缺失时使用独立骨堆占位，不再把存活形象染灰。
- 表格同步器支持“尸骸美术A / 尸骸美术B”列，并在表格缺列时保留敌怪 JSON 已配置的尸骸路径。

## 2026-09-14　大型建筑 3/4 投影嵌图实验

- 固化 `orthogonal_3q_48_v1`：48×48 正交逻辑地表 + 高角度 3/4 立件；明确禁止把现有地图旋转/压缩成伪等距视角。
- 明确大型建筑的完整源图与绘制切带是两回事：资产和逻辑仍是一座完整建筑，运行时可对 Base 作 region 分段，让角色与各遮挡带在同一 YSort 域排序。
- 新增 `BuildingProjectionLab.tscn` 验证高原修道院的统一排序、水平遮挡带与投影元数据；生产地图与 Prefab 不改绘制行为。
- 建筑查看器新增可移动探针、自动收顶和投影读数，旧修道院可继续验证独立 Roof + `occlusion` 收顶。
- 高原修道院加入按建筑语义划分的正式 `sorting.bands[]`；`Building` 运行时从完整 Base 纹理生成底边锚定的 Region 绘制带，资产仍保持一个 Prefab、一张完整源图和一套逻辑。
- Godot 地图运行时把玩家与 NPC 放进地图「建筑对象」YSort 域，角色根节点统一改为脚点；所有触发、存档和交互位置改用世界坐标，旧 Tiled 地图继续走兼容分支。
- 建筑校验新增切带 id、边界、重叠和完整覆盖检查，投影实验场优先复用生产语义带。
- 新增 `MainHighlandMap.tscn` 作为可移动角色的生产验收入口，不再只靠静态预览或实验探针判断嵌图效果。
- 验证：`test_building_pipeline.gd` 296/296、`test_godot_map_pipeline.gd` 129/129；高原建筑与地图结构化校验均为 0 error / 0 warning，1280×720 实际渲染无切带接缝或错位。
- Godot 默认启动场景由旧 `Main.tscn` 切换为 `MainHighlandMap.tscn`，启动项目即进入整理后的高原修道院地图，同时保留完整玩法外壳。

## 2026-09-14　伊瑟拉修道院·西南高原边境地图

- 按设定集把修道院定位为“边境庇护所兼焚尸节点”：教堂、钟塔、回廊中庭、水井、医舍/收容翼、后勤与焚化烟道组成一座完整院落，南门楼与双圆塔提供克制的边境防御感。
- 美术在 `C:\美术素材制作` 内完成：Image 2.5 以完整结构稿为参考生成一座统一建筑，随后由修道院专用管线完成洋红键控、透明清理、32 色量化和像素后处理；`package_large_building.py` 继续导出 Shadow / Structure / WarmLight 三层。
- 新增大型建筑包 `assets/buildings/iserra_monastery_highland/`：视觉画布 50×60 格（2400×2880 px），逻辑占地 48×58 格；视觉允许越出碰撞，碰撞由 5 个矩形、独立掩码与 2 格宽南门定义，不从贴图像素反推。
- `build_building.gd` 新增可选 `solid` 结构体块和 `visual.clip_to_logic=false`，支持不可进入的大型外观建筑，同时保持旧建筑默认行为不变。
- 新增 `maps/godot/tools/make_iserra_monastery_map.gd` 与 `maps/godot/scenes/iserra_monastery_highlands.tscn`：84×88 格、全部使用现有 dark48 地表/树木/岩石，深山林缘包围修院，南侧石路连接高原隘口；修道院以单个 `IserraMonasteryHighland.tscn` 实例放入地图。
- 验证：新建筑与地图结构化校验 0 问题；`test_godot_map_pipeline.gd` 129/129、`test_building_pipeline.gd` 271/271 通过；整图预览 4032×4224，画面深/浅/亮占比 66.3/32.0/1.8。

## 2026-09-14　大型建筑资产管线（Building Asset Pipeline）与首个测试建筑

- **网格口径澄清**：**除战斗地图（六边形，`core/grid/hex_grid.gd`）外，游戏地图一律正方形网格**
  （48 px = 1 米，`MapScene` + `TileMapLayer`）。建筑管线只服务正方形网格的地图，
  与战斗的衔接方式是数据（`tactical` / `collision`）而不是几何。
- **核心主张落地：视觉与逻辑彻底分离**。大型建筑不再拆成几十上百个 Tile，而是一个独立视觉对象 + 一套逻辑数据：
  `Building → Visual / Collision / Occupancy / WalkableArea / Doors / Interaction / TacticalData`。
  示例：伊瑟拉修道院**视觉 2832×3264 像素、逻辑只占 57×66 格**，两者故意不绑定。
- **标准建筑资产包** `assets/buildings/<building_id>/`：`visual/`（原图 + 生成的主视觉/屋顶层）、
  `masks/`（5 张逻辑掩码 + `legend.json` 规范）、`collision/`、`metadata/`（机器可读 `building.json`）、
  `preview/`（预览 + 掩码叠查图）、`source/`（美术线平面图留档）、`building.spec.json`（唯一手写输入）、
  `<PascalCaseId>.tscn`（Building Prefab）。
- **掩码工作流（1 像素 = 1 格，只认 alpha）**：`occupancy` / `walkable` / `collision` / `occlusion` / `doors`，
  子集关系与尺寸被校验器强制检查；`doors.png` 用颜色编码朝向。掩码是生成物（改 spec 重跑），
  也支持反过来：手改掩码后 `build_building.gd --from-masks` 回灌 metadata（视觉一个字节都不动）。
- **确定性逻辑光栅化规则**：`occupied` = 房间并集；`walkable` = 每个房间向内缩 1 格（缩出来的一圈即墙，
  实测与美术画的墙线吻合）；`blocked = occupied − walkable`；`openings` 打开柱廊/敞廊；
  门沿朝向找到墙格后**把整堵墙打穿**（否则两边房间不通）；`occlusion` = 有屋顶的房间 ∩ 可通行区。
- **机器可读 metadata**（`metadata/building.json`）：`building_id` / `display_name` / `asset_path` /
  `visual`（尺寸、出血、锚点偏移、分层）/ `anchor` / `footprint` / `occupied_cells` / `walkable_cells` /
  `blocked_cells` / `occlusion_cells`（游程编码）/ `doors` / `rooms` / `collision.rects` / `tactical` /
  `sorting` / `masks` / `source`。**Agent 用建筑时只读这一个文件，不再从图片理解几何。**
- **运行时**（`core/building/`）：`BuildingData`（metadata 内存形态 + 逐格裁定）、
  `BuildingLibrary`（资产库扫描 / 摘要 / 文件清单）、`Building`（场景节点：`judge_map_cell` /
  `get_occupied_map_cells` / `get_door_map_cells` / `set_roof_visible`）、
  `BuildingPlacer`（高层动作）、`BuildingValidator`（三层结构化校验）、`BuildingMask`（掩码规范与几何工具）、
  `building_viewer.gd`（查验器）。
- **地图系统接入（加法式，旧地图零影响）**：`MapScene` 新增「建筑对象」容器概念与
  `get_buildings()` / `get_building_at()` / `get_door_at()` / `validate_buildings()`；
  `is_cell_walkable()` 现在先问建筑（**只在建筑占用的格上**由建筑裁定，占用区外照旧）；
  `get_map_size_cells()` 把建筑伸出去的范围算进去。没有「建筑对象」容器时行为与接入前一致。
- **结构化校验**（`validate_package` / `validate_prefab` / `validate_placement`）：文件齐不齐、字段完不完整、
  掩码尺寸与子集关系、可通行区是否连通（封死的房间）、门是否落在合理位置且真的通得出去、
  碰撞矩形是否不重不漏、Prefab 能否实例化且节点结构/形状数/门节点数与 metadata 一致、放置是否越界或重叠。
  每条问题是 `{code, severity, path, message, detail}`，Agent 按 `code` 分支。
- **Agent 高层工具** `maps/godot/tools/building_tool.gd`（输出一律单行 JSON）：
  `list` / `inspect` / `validate` / `place` / `remove` / `move` / `validate-map` / `demo`。
  「在当前地图中央放一座伊瑟拉修道院」= `list` → `inspect` → 算中央格 → `place` → `validate-map`，**3 条命令**。
- **首个测试建筑**：`iserra_monastery`（伊瑟拉修道院 / Iserra Monastery），几何直接取自美术线交付的
  `monastery_plan.json`（12 房间 / 8 门）。生成结果：占用 2649 格、可走 2199 格、实体 450 格、
  31 个碰撞矩形、2 层视觉。示例地图 `maps/godot/scenes/monastery_grounds.tscn`（69×78 格）。
- **工具**：`build_building.gd`（spec + 美术原图 → 掩码/metadata/碰撞/视觉/预览/PreFab，分 `--phase`，
  支持 `--from-masks` 回灌）；`preview_map.gd` 扩展为**把建筑一起合成进地图预览**；
  `building_tool.gd -- demo` 一条命令出可跑地图；`启动建筑查验.bat` + `world/map/BuildingViewer.tscn`
  用鼠标逐格查"这一格到底是什么"。
- **测试**：新增 `tests/map/test_building_pipeline.gd`（**265 条断言**，含反向用例：故意造坏 metadata，
  确认校验器给出结构化错误码）。`tests/map/test_godot_map_pipeline.gd` 保持 **129/129 全绿**（无回归）。
- **文档**：新增 `docs/world/building_pipeline.md`（12 节：网格口径 / 资产包 / metadata / 掩码规范 /
  确定性几何规则 / Prefab / 高层 API / 校验 / 一条命令生成 / 怎么加新建筑 / 常见坑）、
  `assets/buildings/README.md`；更新 `docs/world/map_pipeline.md`、`AGENTS.md`、`maps/godot/README.md`。
  后续补充统一资产分类门禁（Tile / 小物件 / 大型结构）与不可颠倒的生产顺序：需求分析 → 概念设计 → 生图 →
  透明处理 → 分层 → 独立占地/碰撞 → Godot 场景封装 → 放入地图；明确城堡等大型结构不得随意切成几十块 Tile。
- **已知限制**：主场景移动仍未接 `is_walkable()`（不会撞墙停下，与接入前一致）；
  69×78 格的大地图在主场景里需要接 `CameraCtrl` 跟随才好看（用建筑查验器不受此限制）。

## 2026-09-13　美术规格切换：俯视 2D · 48×48 · 黑暗奇幻（素材入库 + 管线升级）

- **规格落地**：新增 `docs/art/style_guide.md`（本项目美术唯一规格）—— 48 px = 1 米（1 格 = 1 m²）、
  画面级 **75/20/5**（深/浅/亮）与标定配比「草 60 / 枯草 15 / 泥土 12 / 碎石 6 / 石砖 7」、
  三套互不通用色板（`map_env` 32 / `char` 39 / `souls` 24）、地面正俯视无方向光 vs 道具/角色 3/4 俯视左上主光、
  材质明度阶梯与色相家族、16 配置自动拼接语义、尺寸表与命名规范、验收指标与缺口清单。
- **素材入库**：`assets/dark48/`（279 文件，来源 `C:\美术素材制作\交付素材`）—— 5 张无缝地面、4 个道具（含 2×2 大树/立石）、
  4 组 × 16 配置 × 2 变体自动拼接集、角色/动画/图标/UI/色板，附 `README.md`（映射表 + 引擎使用要点 + 已知问题）。
- **图块集管线升级**（`maps/godot/tools/build_tileset.gd`）：
  - spec v2：多来源、按单张 PNG **自动打包图集**（`tilesets/atlas/`，带指纹缓存，素材没变不重打包）；
  - 支持 **Godot 地形集**（4 组材质对，四边匹配模式，逐边写 peering bit）与 **2×2 大图块**；
  - 把「材料 → 图块坐标、自动拼接集掩码表」写进 TileSet 的 `pipeline` 元数据（制图工具与测试的唯一事实来源）；
  - 保留 v1（单图块表 + id 语义）兼容路径，旧 16px spec 照常可重建。
- **制图库与工具**：`map_palette.gd`（材质 → 图块、按四邻重算边缘块、幂等）、
  `autotile_fixup.gd`（手绘地图边缘块修正 / `--check`）、`preview_map.gd` 增加**画面占比统计**（75/20/5）、
  `make_map.gd` 支持 48px 模板与示例地图「修道院外的荒院」（26×15 = 一屏，材质配比按标定表）。
- **运行时**：`MapScene` 新增 `display_scale`（48px 用 1.0 即 1:1）并修好 **2×2 大图块的 4 格阻挡判定**；
  `main.gd` 按地图声明的尺寸/倍率**居中摆位**（旧 Tiled 地图走常量兜底，观感不变）；
  `project.godot` 默认纹理过滤改为 **Nearest**（像素 1:1 不糊）；演示入口 `world/map/MainGodotMap.tscn` 指向 48px 地图。
- **测试**：`tests/map/test_godot_map_pipeline.gd` 扩到 **129 条断言**（新增：48px 图块集与地形集、2×2 道具占格、
  自动拼接掩码与 peering bit、幂等性、材质配比 ±8%、预览图与画面级 75/20/5、两代地图明暗对比）。
- **实测**：示例地图合成预览 **深 74.4% / 浅 25.2% / 亮 0.4%**（规范 75/20/5；旧 16px 样例为 7.2/43.8/49.0）。
- **文档**：新增 `docs/art/style_guide.md`；重写 `docs/world/map_pipeline.md`（六步流程 / 地形集 / 修正工具 / 一屏 1:1）；
  更新 `docs/art/asset_request.md`（规格改 48px + 指向 style_guide）、`assets/README.md`、`tests/README.md`、
  根 `README.md`、`AGENTS.md`、`docs/world/README.md`、`known_issues.md`。
- **已知限制**：主场景移动仍未接 `is_walkable()`（不会撞墙停下）；26×15 以上的地图需要接 `CameraCtrl` 跟随。

## 2026-09-13　地图制作管线（本地素材 + Godot 地图编辑器）与素材需求单

- **新增 Godot 编辑器地图管线**（与 Tiled/YATI 管线并存，`maps/godot/`）：
  - `maps/godot/tools/build_tileset.gd` —— 本地素材 PNG + `<名>.spec.json`（图块语义表）→ `TileSet` 资源，
    空白格自动跳过（当前 isella_abbey 素材 54/192 块），每块图块写入 `solid`(bool) / `tag`(string) 自定义数据；
    同时产出 `*_图块清单.md`（语义清单 + 新图块可用的空白格）与 `*_图块对照表.html`（4 倍放大、带坐标，刷图时对着看）。
  - `maps/godot/tools/make_map.gd` —— 生成空白模板 `scenes/map_template.tscn`、示例地图 `scenes/abbey_yard.tscn`
    （修道院前院：草地/土路/院墙/礼拜堂/钟楼/菜园花圃/林缘，40×30、16px），以及 `--name` 新地图脚手架。
    刷图只认图块 `tag`，不写死坐标；换素材重跑第 1 步即可。
  - `maps/godot/tools/preview_map.gd` —— 把地图按层叠成预览 PNG（`abbey_yard_preview.png`，碰撞层不画），
    不看编辑器也能过目地图效果。
  - `core/world/map_scene.gd`（`MapScene`）—— 地图场景运行时接口：六图层约定（地形/高差/建筑/装饰/植被/碰撞）、
    标记读取（`spawn`/`battle_trigger`/`story_trigger`/`skill_light` + 可选地标）、
    `is_walkable()`（除地形外 solid 图块 + 碰撞层 + 未铺地面 = 不可通行）、`validate()` 结构自检。
  - `world/map/MainGodotMap.tscn` —— 接入演示入口；`main.gd` 新增导出项 `overworld_map_scene`，
    地图自带 `get_map_rect`/`get_marker_position` 时自动读取尺寸与关键点，**Tiled 地图没有这些接口 → 常量兜底，行为不变**。
- **新增素材需求文档** `docs/art/asset_request.md`：提需求前自查、需求单模板、图块类规格（16×16、16 列网格、透明底、
  只追加不改坐标、必须给 tag/solid）、验收清单、退回原因、交付后接入流程；示例填单
  `docs/art/requests/2026-09-13-water-and-bridge-tiles.md`（水面/河岸/木桥）。
- **文档**：新增 `docs/world/map_pipeline.md`、`maps/godot/README.md`；更新 `docs/world/README.md`、
  `maps/README.md`、`assets/README.md`、`tests/README.md`、根 `README.md`；新增 `启动地图编辑器.bat`。
- **测试**：新增 `tests/map/test_godot_map_pipeline.gd`（65 条断言：图块集语义、场景结构与标记、
  通行性判定、预览图、main.gd 接线）。回归全绿：tests/map 5 + 65、tests/save 33、tests/world 19、tests/quest 27、
  tests/dev 编译自检（新增 map_scene 与 3 个管线工具脚本）；`Main.tscn` 与 `MainGodotMap.tscn` 无头加载无脚本错误。
- **已知限制**：碰撞层与 `is_walkable()` 已可用并被测试覆盖，但主场景移动目前仍只受 `move_bounds` 限制，
  尚未按 `is_walkable()` 拦截撞墙（下一步）。

## 2026-08-27　buff 结算统一接入 EffectSystem（易伤/虚弱时机化 + buff 行为函数化）

- **攻击类时机实现**：易伤 / 虚弱 从 `take_damage` / `resolve_attack` 中的硬编码名字检查，
  统一接入 EffectSystem 的时机结算——「受到攻击时」在 `take_damage` 中经伤害修正钩子
  `_apply_damage_modifiers` 结算（易伤 +50%，格挡结算前放大）、「造成攻击伤害时」在
  `resolve_attack` 中结算（虚弱 -25%，被动修正前降低）；`trigger_timing` 数据不变，
  伤害数值与结算顺序与之前完全一致。
- **buff 行为函数化**：`core/effect/effect_system.gd` 新增 buff 行为注册表
  （`_trigger_handlers` / `_damage_modifier_handlers` / `_draw_bonus_handlers` /
  `_energy_bonus_handlers`，在 `_init()` 构建），全部按 buff 名称 → 函数分发：
  中毒 / 预格挡 / 疗愈 → 触发函数；易伤 / 虚弱 → 伤害修正函数；
  预抽牌 / 肾上腺素透支 → 抽牌修正函数；费用预支 → 费用修正函数。
  `resolve_buff_trigger`、`consume_draw_bonus`、`consume_energy_bonus` 不再按
  buff 名称 match，改为注册表分发；未注册的 buff 保留「效果待定义」日志兜底。
- **BattleManager 同步**：效果转发 API 不变（全部转发 EffectSystem），
  文件头触发时机注释补充攻击类时机（受到攻击时 / 造成攻击伤害时）。
- **文档**：docs/battle/rules.md 第 4 节补充统一结算说明；
  docs/battle/architecture.md 更新 EffectSystem 协作描述。
- **测试全绿**（failed=0）：tests/battle/test_battle_fixes.gd（13）、
  tests/card/test_card_rebalance.gd（47）、tests/card/test_card_logics.gd（27）、
  tests/character/test_passives.gd（11）、tests/dev/test_script_compile.gd（10 脚本编译自检）。

## 2026-08-22　NPC 编辑器 + 任务编辑器（人类与 AI 通用，JSON + CLI 模式）

- **任务系统（core/quest/）**：QuestData / QuestDB / QuestSystem / QuestCondition。
  无任务 UI（无任务栏/提示），状态记录在 `GameState.quest_state`（随存档持久化）；
  完成条件满足自动推进下一任务；支持分支（branches 按前置条件进入不同后续任务）；
  奖励与线索由 NPC 对话与文本提供（text 奖励 / description / NPC dialogue）。
  条件类型：flag / quest_done / item_count / coin / npc_talked / battle_won /
  world_time / always / and / or / not；奖励：coin / item / equipment / xp / flag / card / text。
- **NPC 行动轨迹（时间轴）**：NpcData 增加 `schedule`（hour + 地图内像素坐标 + state），
  `core/world/npc_schedule.gd` 提供纯逻辑位置计算（相邻插值/整点命中/跨零点衔接）；
  世界时钟 `GameState.world_time`（v6，随真实时间推进，主场景每秒=10 游戏分钟）；
  main.gd 按时间轴放置并移动 NPC 标记，E 键交互 → StoryTrigger + notify_npc_talked；
  BattleMap 胜利 → notify_battle_won（battle_won 条件生效）。
- **编辑器（人类 + AI 通用，参照 docs/story/editor_guide.md 模式）**：
  `编辑器/quest_editor.py`（list/validate/new/set/reward/branch/delete，支持 @文件传 JSON、
  容忍 Windows 引号/BOM）与 `编辑器/npc_editor.py`（list/validate/new/schedule add|clear|list/
  interaction/dialogue）；`编辑器/编辑器说明.txt` 更新；sync_tables.py 保留 JSON 中 schedule。
- **示例内容**：content/quests/ 分支链（monastery_errand → garden_task / kitchen_task，
  含 flag 分支、battle_won、world_time 条件）；赫伯特主教/草药师新增 schedule 与线索对话。
- **存档**：SAVE_VERSION 5 → 6（world_time），旧档自动迁移默认 8.0；save_game 自动创建父目录。
- **测试全绿**（failed=0）：tests/quest/test_quest_system.gd（27）、
  tests/world/test_npc_schedule.gd（19）、tests/save 回归（33）、tests/story 回归（36）、
  tests/map（5）；主场景无头启动无脚本错误；tests/dev/test_script_compile.gd 全脚本编译自检。
- **文档**：docs/quest/rules.md、architecture.md 从「规划」改为「已实现」，
  新增 docs/quest/editor_guide.md（人与 AI 通用手册）、docs/world/npc_schedule.md。

## 2026-08-22　初始地图「伊瑟拉修道院」草稿版（Tiled + Pixelorama 素材）

- `maps/Monastery.tmx` 重做为初始地图「伊瑟拉修道院」：40×30、16px，YATI 导入不变，
  主场景 `world/map/Main.tscn` 仍加载同一路径，玩法钩子（出生点/战斗/技能光点/剧情）坐标保持不变。
- 美术：新增图块集 `maps/tilesets/isella_abbey.tsx` + `isella_abbey.png`，取自 `C:\绘画` 素材包
  （Valley Ruin 草地/山崖/围栏/作物/花卉）重着色拼装，并自绘灰白石材（教堂/单座高耸钟楼/回廊/
  城齿防御墙+角楼+南侧门楼/拱窗/大门），统一灰白 + 黄绿枯春草地 + 木色中世纪色调。
- 场景要素：灰白中世纪修道院、高原山腰半山平台（山崖高低差）、单座钟楼、教堂+回廊庭院、
  一片菜园与花园、外围防御工事、树丛掩映（东南角最密）、无墓地。
- 生成工具：`maps/gen_map.py`（由区域定义生成 `.tmx`/`.tsx`）；`maps/preview.ps1` 可合成预览。
- 校验：`tests/map/test_isella_map.gd` 无头自检通过（PackedScene 加载、四图层、tileset 纹理指向
  `isella_abbey.png`，passed=5 failed=0）。

## 2026-08-22　剧情 / 过场系统落地（对话、摄像机、触发器、防重复触发）

- 新增剧情数据与执行器：`core/story/`（StoryData / StoryDB / StoryRunner /
  StoryInstructions / TriggerManager）。剧情以 `content/stories/*.json` 存储，
  时间轴 + 指令模型：指令默认按序阻塞执行，`blocking: false` 立即放行（后台继续），
  `parallel` 并行组；指令直接操作运行中的游戏对象（对话/镜头/角色/Flag/场景/信号），
  而非播放动画。
- Godot 4.7 禁止不 await 的协程调用，执行器改用“同步指令 + 操作句柄（Tween/Timer/令牌）
  + 按帧轮询”模型；剧情启动用队列 + `_process` 内 await，触发器/脚本可安全点火。
- 剧情期间切断玩家控制：锁定 `player` 组输入并置 `GameState.story_active`，
  主场景据此拦截输入与事件判定；支持 `player.lock` / `player.unlock` 指令。
- 独立对话系统：`core/dialogue/` + `ui/dialogue/`（文本框、头像（贴图/色块占位）、
  打字、选项、H 键对话历史面板）；`Dialogue.begin_line()` 令牌轮询完成，无信号竞争。
- 独立摄像机：`core/camera/camera_controller.gd`（Autoload CameraCtrl），
  移动/跟随/缩放/震屏/复位，默认视口中心不改变原画面。
- 独立触发器：`content/stories/triggers.json`（area / interact / flag / auto / scene），
  剧情播放期间的 flag 变化暂存、结束后补触发（支持剧情链）。
- 防重复触发：`GameState.story_played`（开始播放即记录）+ 剧情 Flag API
  （set_flag / get_flag / flag_changed 信号）；存档升 v5（旧档迁移缺省为空）。
- 编辑器工具：`编辑器/剧情检查.py`（校验 + `--list` 指令目录）与 `启动剧情检查.bat`，
  人和 AI 共用同一 JSON 数据格式（docs/story/editor_guide.md）。
- 示例：`content/stories/example_intro.json`（走出南门触发，含镜头/对话/选项/并行/
  Flag/字幕/剧情链）+ `example_flag_story.json` + `example_interact.json`（模板）。
- 测试：新增 tests/story/test_story_data.gd（36 断言）；tests/save 更新 v5
  （31 断言）；全量 15 个无头测试 0 失败；主场景/战斗场景无头加载无脚本错误。

## 2026-08-21　敌怪 AI 按《敌怪ai逻辑.txt》优化与统一

- 重构 `core/ai/` 为文档推荐架构：`ai_profile.gd`（AIProfile 统一 Aggression/Support/
  Caution/Mobility/Defensiveness/TargetPriority/PreferredRange 七参数 + 9 个模板）、
  `goal.gd`（Goal：进攻/集火/保护首领/支援/保持射程/保命）、`action_candidate.gd`
  （Action+Target+Position+Parameters 决策单位）、`condition_evaluator.gd`（条件与 Utility 分离）、
  `target_selector.gd`（动态威胁 + TargetPriority + Kill Potential）、`position_evaluator.gd`
  （PreferredRange + 危险回避 + 护卫阻挡）、`utility_evaluator.gd`
  （Utility = Base+Target+Position+Context+Personality+Urgency+Random）。
- `enemy_ai.gd` 收敛为门面：提供文档第 31 节推荐的 `get_action_candidates` / `evaluate`，
  并保留 `decide` 旧签名与旧静态接口（desired_distance / goal_score / select_target 等）兼容；
  `ai_archetype.gd` 降级为旧名兼容层。
- 敌怪数据驱动：`EnemyData` 新增 `ai_profile`（按敌怪覆盖行为参数）与 `skills`（ActionSet 预留）；
  `enemy_database.gd` 解析 JSON，`sync_tables.py` 支持「AI参数」「技能集」两列。
- 动态威胁：玩家威胁估值增加装备伤害修正与「易伤」状态；目标选择加入可击杀优先与孤立加成。
- 随机变化：`battle_map` 每场战斗一个 RNG 种子，AI 决策加入 ±6 随机分项；
  必杀机会（Kill Potential）不会被随机覆盖；不传 RNG 时保持确定性（测试用）。
- AI 调试面板（F4 / 点击敌怪）新增 Goal 展示与 Utility 七分项明细。
- 测试：新增 tests/ai/test_ai_unified.gd（50 断言）；全量 14 个无头测试
  443 断言 / 0 失败；主场景与战斗场景无头加载无脚本错误。

## 2026-08-18　修道院 Tiled 地图接入 Godot（初始地图）

- 新建 `maps/Monastery.tmx`（40x30，16px/格）修道院地图：地面/建筑/装饰三层——钟楼（十字尖顶）、主教堂、东配楼、南侧回廊、围栏、庭院树木；素材为 OpenGameArt 的 Overworld - Monastery（CC0）与 Overworld - Grass Biome（CC0），来源登记见 assets/来源与许可.md。
- 接入 YATI 插件（addons/YATI v2.2.7，MIT）：Tiled 的 .tmx 由 Godot 自动导入为 PackedScene；原包下载内旧格式示例地图已用 .gdignore 排除。
- `world/map/Main.tscn`（core/world/main.gd）启动时加载修道院地图作为初始大世界：1.5 倍缩放居中（960x720），角色出生在修道院南门（616,480），战斗触发点移至东南角（976,600），技能光点移至院内花园（496,408）。
- 移动限制：character.gd 新增 move_bounds，主场景把角色限制在地图范围内（旧档越界位置重置到南门）。
- 存档默认值同步：GameState.overworld_position / skill_light_position 更新；tests/save 断言同步更新。
- 验证：主场景/战斗场景无头加载无脚本错误；character 与 save 测试全过（50+11+9+26 断言，failed=0）。

## 2026-08-17　存档扩展设计（待办第 3 项）

- 存档载荷版本化（v4）：新增 battle_trigger_consumed / skill_light_position（触发状态持久化），并预留 flags（剧情 Flag）/ quest_state（任务状态）/ world_state（世界状态）字段，缺省安全。
- load_game() 显式按版本迁移：旧档（<v4）缺失字段自动补默认值，既有字段读取逻辑保留。
- 确认 SaveSystem 唯一入口：全项目仅 game_state.gd 写存档文件；Demo 换档仅改 save_path，不另建持久化通道。
- 新增 tests/save/test_save_roundtrip.gd（26 断言）：v4 保存→加载往返一致；v3 旧档缺省字段可用。
- 更新 docs/architecture.md 的存档模块说明。

## 2026-08-17　拆分 battle_manager.gd（待办第 6 项）

- 新建 core/effect/effect_system.gd（EffectSystem）接管效果结算：卡牌效果（resolve_effects / resolve_attack，含伤害/格挡/pierce/条件）、buff 结算（resolve_buff_* 系列、按触发时机、衰减）、通用伤害（lose_hp / take_damage / heal_unit）、牌堆辅助（抽/弃/消耗/生成/复制/固有牌）。
- battle_manager.gd 瘦身：只保留回合流程、行动顺序、出牌入口、胜负判定、战利品；既有信号与对外接口不变，私有方法保留为转发兼容。
- 全量 13 个无头测试通过（393 断言 / 0 失败）；4 个场景无头加载无错误。
- 更新 docs/battle/architecture.md（类图与数据流）。

## 2026-08-17　装备流程闭环（有舍有得）

- 装备定位落实 GDD 第 14 节：不是单纯的数值提升，而是「有舍有得」的机制修正——每件装备的 mods 既有收益（正修正）也有代价（负修正）。
- 新增 11 种修正类型：属性/生命上限/行动值/荷载容量/移动力/攻击范围/攻击伤害%/防御卡格挡/抽牌/费用/回合开始格挡。
- 6 件装备（铁剑/铁头盔/皮甲/草鞋/铜戒指/长枪）均配置一得一舍；装备创建.xlsx 新增「修正」列并补长枪行，编辑器说明同步。
- 穿脱闭环：背包点击装备穿到当前角色（槽位被占先卸旧装备回背包），装备面板点击卸下回背包；存档 v3 按名称持久化装备，旧档缺省为空。
- 战斗接入：HP/伤害基数/行动顺序/移动力/攻击范围/每回合抽牌与费用/回合开始格挡/防御卡格挡均使用合并后属性与修正。
- 新增 tests/character/test_equipment.gd（50 断言）+ tests/battle/test_equipment_battle.gd（13 断言）；全量 12 个无头测试通过（367 断言 / 0 失败），4 个场景无头加载无错误。

## 2026-08-17　Git 仓库初始化

- 在 `C:\游戏` 初始化 Git 仓库并完成首次提交（630 个文件基线：core/content/ui/world/docs/tests 等）。
- `.gitignore` 确认已忽略 `.godot/`、`android/`，并补充 `__pycache__/`、`*.pyc` 缓存规则；已入库的 pyc 缓存文件移出版本控制。
- docs/development/known_issues.md 的“未初始化 Git 仓库”条目已标记为已处理。

## 2026-08-17　敌人 AI 重构（行为模板 + 评分决策）

- 按《敌人ai重构方案》落地三层决策：行为模板（AiArchetype）→ 战术层（目标选择 + 行动评分）→ 行动层（六边形位置评价）。
- 9 个行为模板：士兵/狂战士/猎人/护卫/刺客/鲁莽/支援/首领/木桩；敌怪数据新增 archetype 字段（Excel“行为模板”列同步）。
- 目标评分 = 威胁（30+力量×2+敏捷+意志）+ 生命/距离/孤立修正 + 可击杀加成；行动评分按性格加权（攻击/接近/追击/撤退/保护/支援/等待）。
- 首领模板（Boss 规则）：不撤退、高威胁/低生命双优先、半血狂暴 +20；使用技能为 SkillSet 预留。
- 新增 AI 调试面板（F4 / 点击敌怪查看目标、候选评分、最终选择与原因）。
- 新增 tests/ai/test_ai_decisions.gd（31 断言）。

## 2026-08-17　模块化重构（core/content/ui/world/docs/tests）

- 将 Godot 工程根目录提升到 `C:\游戏`（原 `战斗系统/`）。
- 目录重组：
  - `scripts/` → `core/`（规则系统）、`ui/`（界面）、`demo/`
  - `data/`、`卡牌/`、`数据/`、`敌怪/` → `content/`（内容数据）
  - `scenes/` → `world/`（地图/遭遇场景）
  - `美术资源/` → `assets/`
  - 根文档 → `docs/`（architecture + 各模块 + development）
- 更新全部 res:// 引用、autoload 配置、编辑器输出路径（sync_tables / card_editor / update_tables）、启动 bat。
- 新增 README.md、AGENTS.md、docs/ 模块文档（battle/card/character/world/story/quest/development）。

- 修复：sync_tables.py 卡牌清理不再误删 conditions.json / card_drops.json（重建了两个被误删的配置）；卡牌编辑器 load_cards() 只加载真卡牌。
- 文档：敌人 AI 重构方案归入 docs/battle/；重构方案归入 docs/development/。
- 验证：10 个无头测试全通过（300 断言 / 0 失败）；4 个场景无头加载无错误。

## 2026-08-12　升级改为自由属性点 + 角色面板加点按钮

- 升级每次获得 1 点自由属性点（不再自动加四项属性）；面板加点点数即时存档。
- 旧档兼容：未消耗属性点随存档保存，旧档缺省为 0。

## 2026-08-12　战斗测试 Demo + 道途系统

- 独立战斗测试 Demo：启动直接进入随机战斗，结算后回修整营地，光点询问是否进入下一场。
- 道途系统：4 道途（梦魇行者/孢子卫士/侠盗/解剖学者）+ 专属初始牌 + 基础被动。
- 敌怪：精英/Boss 分级与战利品表；修复敌怪回合结束 buff 结算。
- 详细记录见 [work_log.md](work_log.md)。


## 2026-09-27 莱顿城三图可玩灰盒候选

- 将旧工作区的规划、拓扑、九张缩略灰盒及渲染器共 20 文件迁入 `maps/leyton/archive/`，记录来源和 SHA256；当前规划修订河流不通航。
- 新增 M01/M04/M07 48px 数据与验收场景：占地碰撞、2×3 马车、桥梁、两格出口/回传保护、西门三状态、独立墙顶层与墙梯。
- 修正河道/建筑/道路占地冲突；保留历史原版。未改生产主场景。
- 验收：莱顿城 61、地图 85、建筑 296、一期 33 项全部通过，编译 135 项通过；实际 OpenGL 三图截图已查看。
- 此阶段为待用户审阅的逻辑灰盒；未完成正式美术、NPC、马车转向/会车，正式交付仍为 0/8。
- 当前接续日志：`maps/leyton/WORKLOG.md`；入口：`maps/leyton/scenes/slice_test.tscn`。


## 2026-09-27 莱顿城首批地表预览

- 新增深水/深青石墙顶48px图块，raw/提示词/专用色板/QA/哈希可追溯；内置image_gen生成，复用像素管线显式tileable=True。
- 独立TileSet含139图块/4地形集，复用dark48素材与自动拼接；接入M01/M04/M07，T切回灰盒。
- 全格通行一致性37项、原莱顿城61项、既有地图85/建筑296/一期33及编译通过；实际六张截图已检查。
- 仍为地表预览：草地重复感、水岸硬边、桥/城墙立面与建筑占地块待后续；完整交付0/8。
- 当前接续日志：maps/leyton/WORKLOG.md；资产提示词：assets/maps/leyton/surface_v1/prompts.md。


## 2026-09-27 莱顿城地表v2：降低重复感与水岸

- 3张image_gen新源图，经原像素管线入库；草/路各4种共边变体，64过渡块与81混合水岸组合。
- 独立TileSet156块/2地形集接入三图；通行/门洞/出口保持，T切回灰盒。
- 莱顿城61、地表60、地图85、建筑296、一期33、编译136全部通过；580条素材边缘检查通过。
- 实际六张截图已查看，与v1比较重复草丛/道路横带明显减弱。水岸可见但仍服从逻辑网格。
- 下一步桥梁/城墙立面与门楼；当前完整交付0/8。接续maps/leyton/WORKLOG.md。

## 2026-09-27 莱顿 M04 石桥独立结构灰盒

- 先记录完整结构需求与测量参考，再调用内置image_gen保存概念原图；图中北端护栏超出桥头，未接入正式视觉。
- 标准Building包接入M04：12×11、114可走、18护栏阻挡、2入口/2碰撞矩形；未改核心建筑逻辑。
- slice显式prefab加载；切图/换肤不重复实例化，玩家与2×3马车过桥通过。
- 石桥68项、全回归603项断言及137脚本编译通过；实际玩家/马车截图已检查。
- 正式视觉分层、立面与遮挡待续，详见maps/leyton/WORKLOG.md。

### 2026-09-27 — 莱顿 M04 石桥注册图层与角色遮挡

- 将v2桥梁源稿按桥头/护栏控制线导出672×624桥面和护栏层；保留原12×11占地、18格阻挡、114格可走及两端入口。
- 复用Building语义排序带，桥面置于角色下方；莱顿测试场景中的玩家、马车和护栏进入同一YSort域，切图前保留玩家及相机。
- 新增可重现配准和OpenGL截图工具，扩展图层、排序域、马车显示与对象生命周期检查。
- 验证：673项断言、137脚本检查全部通过；独立建筑包0错误/0警告；实际GPU前后遮挡探针通过，4张玩家/马车截图已检查。详见maps/leyton/qa/BRIDGE_ART_QA.md。


### 2026-09-27 — 莱顿 M07 西门楼双层灰盒

- 新增独立Building门楼：11×16占地，地面六格东西门洞，上层独立三格南北巡逻道；两翼110格阻挡，66格地面通行。
- 城门三态同步地图通行、物理阻挡和显示；墙顶不受关门影响，墙梯切换角色绘制高度，水闸仍为独立对象。
- 切图先验证目的地完整占位落点，关闭西门时玩家/马车保留在源侧安全位置；防止进入关闭门洞后卡住。
- 验证：门楼69项、总计742项断言及138脚本检查通过；三态整图通行与接入前一致；实际OpenGL地面/墙顶同XY遮挡检查通过。正式门楼美术待续，见maps/leyton/qa/GATEHOUSE_QA.md。


## 2026-09-27 — 莱顿西门楼静态美术

- 接入四层石砌门楼、瓦顶及连续墙顶巡逻道；保持六格地面门洞、三格墙顶通行和全部既有碰撞。
- 766项回归断言、139脚本编译、建筑包校验与实际GPU遮挡检查通过。动态门扇和水门仍待制作。证据见 maps/leyton/WORKLOG.md 和 qa/GATEHOUSE_ART_QA.md。

## 2026-09-27 — 莱顿八区基础可玩灰盒

- 新增五区运行场景，补齐14条城区有向连接、北南到达点、抽象住宅路程提示、水平墙顶与四门三态。修复南门棚屋占路、南区出口墙体和东门磨坊压河。
- 1121项相关断言、140脚本检查通过，实际GPU八图总览与三门近景已验证。NPC、真实车流及完整地图美术仍在后续计划中。见maps/leyton/WORKLOG.md。

## 2026-09-27 批量美术优先

按用户最新要求，先生产共享物件批次01：木箱、木桶、粮袋、煤筐、公告栏、手推车。六件原图、规格化PNG及FreeProp候选场景已完成技术验收，131项相关检查通过；实际GPU验收图和提示词见assets/maps/leyton/props_batch_01。仍为美术验收候选，未改变八区摆放，完整地图交付0/8。

## 2026-09-28 参考图驱动的城北街坊样段

新增独立32×32米连续街坊审验入口preview_street_v3.bat，包含私院、巷道、连续共墙住宅与井台；四件image_gen参考素材入库，屋顶遮挡淡化、人物/车体通行复用原地图体系。GrayboxMap增加可选layout_document路径，原城地图默认来源不变。样段与全城分开验收，细节和全区迁移仍待后续。
