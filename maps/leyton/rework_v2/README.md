# 城市与修道院重构 v2

本轮对应四项反馈：缺少装饰、城内草地、修道院旧地图架构、贵族区道路与城市建筑密度。

## 当前布局

| 城区 | 建筑占地条目 | 占地图面比例 | 独立装饰 |
| --- | ---: | ---: | ---: |
| M01 中心 | 31 | 33.0% | 17 |
| M02 贵族区 | 34 | 40.3% | 14 |
| M03 贫民区 | 43 | 43.5% | 27 |
| M04 商业区 | 28 | 42.3% | 10 |

比例按逻辑地基面积计算，不把屋檐计入，不等于已完成独特美术建筑的比例。M01保留公共广场与河道。M02主路由8个节点形成7段折线，另有两条回环与两条支巷；主车道宽6米，支路3–4米。已有设施名称与出口保持，NPC/事件预留点移至安全道路。

城内M01–M04铺砖石，院地比主街暗；门区只在城墙内侧铺砖。城外农田和草地保留。68件装饰来自已有image_gen六类FreeProp：箱、桶、粮袋、煤筐、公告栏、手推车。碰撞独立，避开车道与出生点。新小楼使用完整Pattern实例；原有大型地标占地仍留待各自完整美术，不把屋顶纹理当成完工建筑。

## 修道院

直接重构当前 `maps/godot/scenes/iserra_monastery_highlands.tscn`，保留最新版完整Building、位置、投影和全部12个标记。改用当前地表TileSet，砖石院地/前院、山路、侧边服务区明确分开。旧树木/石头从图块层迁出，38个景观/物资FreeProp与2处服务Pattern进入共同YSort域；六层地图接口、碰撞语义保留。Gameplay与Navigation节点声明职责，导航继续使用MapScene通行查询，没有新增NPC自动寻路或导航烘焙系统。

规范生成器为 `maps/godot/tools/refactor_iserra_map.gd`；旧 `make_iserra_monastery_map.gd` 已改为兼容入口，避免再次生成时丢失完整建筑。生成先保存暂存场景、验证结构，再替换正式图。重建保留当前建筑实例并重新生成环境，不能用于保留手工添加的环境道具。

## 素材与证据

- 新模型素材：`assets/maps/leyton/urban_rework_v1/`，两种住宅和砖石地面，原图/提示词/哈希/构建脚本都在目录内。
- 草稿：`layout_draft.png`；最终实机：`maps/leyton/qa/atlas_contact_sheet.png`。
- 贵族区总览/近景：`dev/leyton_world_demo/qa/rework_noble_overview.png`、`rework_noble_street.png`。
- 修道院：同QA目录 `monastery_overview.png`、`rework_monastery_services.png`。
- 原状态备份：`maps/leyton/archive/pre_urban_rework_v1/`，有`.gdignore`。
- 验证：`tests/map/test_urban_rework.gd`；完整入口 `maps/leyton/tools/validate.ps1`。

启动根目录 `启动莱顿大世界审验.bat`，0修道院、2贵族区、M路线、Tab总览、T灰盒对照。

## 后续边界

住宅目前两种外观复用，贵族宅邸仍需独特立面/院门；公共地标专属美术、建筑室内、NPC交通、最终屋顶遮挡反馈、农田作物和真实门扇不属于本次完成项。当前细节与材质重复度仍可继续打磨。
