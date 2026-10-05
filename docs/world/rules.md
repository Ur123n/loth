# World 规则

## 地图制作与发布门禁（2026-10-04）

- 新地图先声明 Tile / Pattern / Prop / Building 类别，固定 48px/m、投影、占地和目标场景；先验收可玩灰盒，再制作精细美术。
- 建筑转换通过 `make_building_spec.py --config` 读取项目内 JSON 配置和同一份房间/门平面；不要求编辑 Python 的建筑列表。
- 建筑发布批次包含贴图、spec、metadata、掩码和 Prefab；统一由 agent_assets 捕获不可变快照并执行审批、发布与回滚。
- 新地图/建筑批次声明 `required_reviews: ["visual", "engine"]`。复核记录绑定当前 run、contract、QA 与产物哈希；缺复核或审批后篡改禁止发布。技术测试不代替美术批准。
- 灰盒开发场景可独立加载进行验证；未获得正式美术审批的灰盒不能标记为最终交付素材。
- Building 根原点为地基底部中心。Collision、Doors、Interaction 子容器统一偏移 `-anchor_local_px`，其子节点仍使用地基左上角局部坐标；视觉独立使用 visual offset。验收必须包括真实物理阻挡和门洞通过。
- 操作入口和验收清单见 `docs/world/map_production_workflow.md`。

## 1. 大世界移动与操作

- WASD 四向移动；地图上只有一个实体：当前选中的角色代表整个队伍。
- ↑/↓ 切换队伍角色（PartyManager）；Tab 打开角色面板；B 打开背包。
- 面板/背包打开时暂停移动与事件触发。

## 2. 战斗触发

- 大世界配置一个战斗触发点（battle_trigger_position + radius）。
- 角色进入半径即触发：保存当前世界位置 → 切换到 `world/encounters/BattleMap.tscn`。
- 触发点消耗后，离开一定距离才重新武装（避免返回时立即再次触发）。

## 3. 技能光点

- 光点位置/是否已学习由 GameState 持久化（skill_light_position / skill_light_consumed）。
- 靠近光点弹窗询问是否学习“冲锋”（当前演示技能）；选择“否”后 2 秒冷却不再触发。
- 确认后技能加入当前角色技能库并写档。

## 4. 场景切换

- 大世界 → 战斗：main.gd 保存位置并切换场景。
- 战斗结束 → 大世界：battle_map.gd 切回 `res://world/map/Main.tscn`；Demo 模式切回 `res://demo/DemoHub.tscn`。

## 5. NPC

- NPC 数据（content/npcs/*.json）由 NpcDB 加载：name/description/color/ai/interaction/dialogue/美术接口。
- 互动选项与对话树字段已存在；NPC 场景交互与对话系统尚未实现（规划见 docs/story/ 与 docs/quest/）。

## 6. 存档

- 大世界位置、触发点状态、光点状态统一由 GameState 保存（user://savegame.json）。
- 进入战斗前保存位置；战斗结算/面板修改即时写档。

## 7. 地图与关键点来源（Godot 地图管线）

- 底图由 `main.gd` 的 `overworld_map_scene` 指定。若底图是 Godot 编辑器管线做的地图
  （`maps/godot/scenes/*.tscn`，根节点挂 `core/world/map_scene.gd`），则**地图自己声明**：
  - 地图矩形（`get_map_rect()`，决定角色移动边界与越界判定）；
  - 出生点（标记 `spawn`，替代默认南门坐标）；
  - `battle_trigger` / `story_trigger` / `skill_light` 三个触发点位置（未消耗光点时以地图为准）。
- 所有正式地图必须实现 `MapScene` 接口并通过地图管线测试；运行时常量只作为资源损坏时的防御性兜底。
- 通行性：`MapScene.is_walkable()` 已按图块 `solid` 自定义数据与「碰撞」层给出判定，但**移动系统尚未接入**
  （当前仅按矩形边界限制），接墙停下属于后续工作。

## 8. 地图对象分类

- Terrain Tile 与可连续延伸的模块化结构进入 TileMapLayer。
- 完整且会重复的小型建筑使用 Pattern；当前 `map_pattern/1` 以 PackedScene Stamp 落地，一次调用放置整栋，不逐 Tile 重建。
- 城堡、修道院等大型结构使用 `Building` PackedScene；视觉尺寸不受 48px 网格限制，位置由 Anchor 定义，碰撞/遮挡/屋顶与视觉分离。
- 桌椅、路牌、岩石等默认作为 `FreeProp` 自由对象；只有明显需要大量重复或自动拼接时才进入 TileSet。
- 新对象先按上述四类归档；不得把完整大型建筑强制切成大量 Tile。

## 9. Door 与 Interior

- 普通小屋可用 `SceneDoor` 进入独立 Interior Scene；大型建筑也可按关卡需求选择独立 Interior、同图无缝 Interior 或不可进入。
- 门只保存目标场景/标记并发起切换，不把室内内容硬编码进建筑脚本。
- 独立 Interior 必须提供返回路径；同图 Interior 的 Roof 显隐由建筑 `occlusion` 数据控制。
- `dev/map_pipeline_test/` 只用于第一阶段验收，不替换正式大地图。

## 10. Leyton bridge layers (2026-09-27)

- M04 bridge keeps its 12x11 footprint, 18 blocked parapet cells and both open aprons.
- Deck is drawn below actors. West/east parapets use the existing Building semantic bands in the same YSort parent as the player.
- Map switching reparents the player before freeing the old map. Cart graphics belong to the player so they share actor sorting.
- Registered art uses a 672x624 canvas, origin (48,48); source alpha never defines collision.

## 11. Leyton gatehouse elevation (2026-09-27)

- M07 gatehouse is a single Building with an 11x6 ground passage and an independent three-cell wall walk above it.
- Closed gate state overrides Building ground passability and enables a matching dynamic collision body; wall-level movement is unaffected.
- Ground actors render below the upper walk, wall actors above it. Only stairs switch elevation; map changes reset elevation.
- Ground masks never include wall-level walkability. The water gate and non-navigable river remain independent.

- Map transitions validate the destination footprint before freeing the source map; blocked arrivals keep the actor at a safe source-side entry.

- Gatehouse art retains the full three-meter upper lane; visual parapets extend 24px outside it. The same registered texture strip continues outside the independent gatehouse. Static art separates Base/Floor/Roof/WallWalk and leaves all navigation unchanged.

## 12. Leyton eight-map graybox

- Eight districts share the existing MapScene harness and slice.json source. North/south arrivals are four cells inside the destination. Residential abstraction is explicit in both directions.
- All four gates share the harness city-wide gate state. Upper lanes can run horizontally or vertically, remain separate from ground navigation, and are reached only at stairs.
- External world exits remain visibly blocked. New district colors, building footprints and NPC/event anchors are graybox reservations, not final assets or live NPCs.

## 13. Monastery to Leyton review demo

- The independent dev/leyton_world_demo starts on the production highland monastery map and connects its south edge to M05 north. Only the demo instance opens that external exit.
- City adjacency continues to use the planned district graph, with M01/M08 linked through explicit abstract residential travel. This is edge-based scene travel, not a geographic compression of the omitted district.
- Shared movement, gates and stairs reuse the Leyton viewer. Its default start remains M01; production main scene, original monastery and slice.json remain unchanged.


## 2026-09-28 城市与修道院制图规则

城内M01–M04以砖石铺装为底，城门图仅城墙内侧沿用城市铺装；草地/农地仅用于城外。M02采用转折主路、回环支巷和连续街坊，建筑占地目标不低于40%，保持6m主车道和所有出口连通。装饰、完整住宅Pattern、大型建筑分别独立摆放；脚点共享YSort，碰撞独立。修道院以现有最新版完整建筑为基础，重构地表、道具和服务区，不回退旧建筑。

## 2026-09-28 连续街坊样段

M02下一版先在street_sample_v3独立验收32×32米街坊。先画连续街面、院落和生活动线，再制作完整共墙街屋Pattern。指定车路验收2×3车体，其余支巷允许仅步行；全图占地率不能替代间距、门口和遮挡检查。保留48px正方形坐标与统一投影。旧地图仍为候选，样段通过后才扩展。

## 2026-10-04 地图美术制作v2

现行制作方法见[新版手册入口](map_production_workflow.md)：先平面、灰盒和独立玩法逻辑，再制作分层材质，以Godot约束轮廓、逻辑画布及色板。以用户确认的会堂为基准；大型建筑完整设计，保留语义遮挡、独立屋顶和碰撞。世界观、风格、比例与地图功能要求继续适用。
