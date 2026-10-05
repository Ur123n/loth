# World 架构

## 场景结构

```
world/map/Main.tscn（根脚本 core/world/main.gd）
├── Background（ColorRect）
├── MonasteryMap（overworld_map_scene 指定的 48px Godot 地图）
│   └── maps/godot/scenes/*.tscn（六图层 + 标记，根节点挂 core/world/map_scene.gd）
├── PartyEntity（Character：core/character/character.gd + CharacterVisual）
├── BattleTrigger（ColorRect + Label，脚本内构建）
├── SkillLight（core/world/skill_light.gd，未消耗时构建）
├── CharacterPanel（ui/character/character_panel.gd）
├── PartyBar（ui/character/party_bar.gd）
├── SkillPrompt（ui/character/skill_prompt.gd）
└── InventoryPanel（ui/inventory/inventory_panel.gd）
```

场景通过 `party_characters` 导出数组注入 4 名角色（ExtResource 引用 content/characters/*.tres）；
`overworld_map_scene` 导出底图路径（默认 `res://maps/godot/scenes/iserra_monastery_highlands.tscn`，
演示入口 `world/map/MainGodotMap.tscn` 指向 `maps/godot/scenes/abbey_outskirts.tscn`）。

## 数据流

1. `_ready()`：GameState.setup_party → load_game → apply_path_system → ensure_basic_deck_cards；随后构建 PartyManager、实体、面板。
2. `_build_world_map()` 实例化底图后调用 `_apply_map_metadata()`：地图（Godot 管线）若提供
   `get_map_rect()` / `get_marker_position()`，则用它的尺寸与 `spawn`/`battle_trigger`/`story_trigger`/`skill_light`
   标记覆盖 `_map_rect`、`_spawn_position` 与触发点；缺少接口时使用防御性常量兜底并由测试阻止不完整地图交付。
   坐标换算：`主场景坐标 = MAP_POSITION + 地图局部像素 × MAP_SCALE`。
3. 输入分发：_input 处理面板/背包/切换；_physics_process 检测战斗触发与技能光点。
4. 状态变化（面板数据、学习技能、位置）→ GameState.save_game()。

## 与战斗的边界

- main.gd 不参与战斗规则：只负责“靠近触发点 → 保存 → 切场景”。
- BattleMap 结束后自行返回；若将来需要剧情/任务响应，应通过 BattleResult 由上层处理（见 docs/architecture.md 依赖方向）。

## NPC 现状

- NpcDB 已加载数据；尚无 NPC 场景节点与对话 UI。
- 规划：对话数据不硬编码在 NPC 脚本中（见 docs/story/architecture.md），NPC 交互走 DialogueSystem。

## 地图对象架构与第一阶段实验场

地图内容分为四条互补管线：

1. Terrain/Modular Architecture：固定 TileMapLayer 与 48px TileSet。
2. Building Pattern：`content/map_patterns/*.json` → `MapPatternLibrary` → 完整 PackedScene Stamp。
3. Large Building：`assets/buildings/<id>/metadata/building.json` + Prefab → `BuildingPlacer`/`BuildingGhost`。
4. Free Prop：带底部 Anchor 和独立碰撞的 Node2D，不强制写入 TileMap。

`dev/map_pipeline_test/map_pipeline_test.tscn` 是独立的端到端实验场。它保留现有六层 TileMap/标记约定，`建筑对象` 作为统一 YSort 域，直接容纳大型建筑、Pattern、Prop 与玩家；`Gameplay` 保存 SceneDoor，`Navigation` 独立预留。Ghost 只做运行时预览和临时放置，持久化编辑继续走 `BuildingPlacer`/`building_tool.gd`，因此不会绕开资产包校验或误写正式地图。


## 2026-09-28 莱顿基础材质与移动审验

独立入口为 dev/leyton_world_demo/world_demo.tscn，出生于修道院并按原规划贯通九图；东侧住宅区保留抽象路程。maps/leyton/graybox_map.gd 在地表模式将未完成色块映射到 basic_materials_v1 的 image_gen 材质，诊断灰盒仍由 T 键切回。纹理只改变 Terrain；cells、Collision、占地和完整 Building Prefab 保持原语义。新 atlas 注册为运行时 source 1001，深拷贝 pipeline metadata 后添加，避免污染共享 TileSet。


## 2026-09-28 城市密度与修道院环境重构

城市布局仍以maps/leyton/slice.json为唯一运行数据。urban_ground决定城内砖石基底，主街使用urban_road、院地urban_pavers；城门图按城墙内外分区。完整重复住宅通过MapPatternInstance场景放置，props通过FreeProp，二者由maps/godot/tools/map_object_placer.gd挂入现有共同YSort域；独立碰撞形状配合地图逻辑碰撞格，避免仅视觉遮挡却可穿行。

修道院最新地图继续供MainHighlandMap及继承Demo共用。refactor_iserra_map.gd读当前完整Building和全部标记，重建环境并暂存验证后发布；旧make_iserra_monastery_map.gd委托它执行。六图层接口保留，植被/小物件视觉迁入共享YSort，Gameplay/Navigation单独标明职责；仍使用MapScene查询导航语义，不引入平行世界或新存档格式。

新资源source1002/1003注册在独立urban_rework_v1.tres，原surface_v2.tres保持。模型原图、提示词和资产生成代码在assets/maps/leyton/urban_rework_v1。验收与限制见maps/leyton/rework_v2/README.md。

### 城北街坊样段 v3

GrayboxMap.layout_document默认指向slice.json；street_sample_v3子类指定layout.json并复用地形/通行层。样段Viewer复用原角色、摄像机、移动，新增V素材对照和屋顶淡化；不改变正式城镇入口。
