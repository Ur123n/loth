# 地图制作管线（本地素材 + Godot 地图编辑器）

从任务单、灰盒到复核发布的完整流程见 [地图制作工作流](map_production_workflow.md)；已确认美术样板入口为项目根目录 `启动会堂美术审验.bat`。

本文件说明**怎么用项目里的本地素材，在 Godot 编辑器里画出一张能直接进游戏的 48×48 地图**。
关心的核心问题：素材怎么变成图块集、图块怎么被编辑器认识、地形边缘怎么自动拼、地图里的关键点怎么被代码读到、画完怎么验、缺素材怎么提需求。

- **当前规格：俯视 2D · 48×48 像素 · 黑暗奇幻** → 风格与规格见 **[docs/art/style_guide.md](../art/style_guide.md)**
- 素材入库与现状：`assets/dark48/README.md`（48px 当前规格）
- 缺素材提需求：**[docs/art/asset_request.md](../art/asset_request.md)**
- 地图运行时接口：`core/world/map_scene.gd`（`MapScene`）
- 管线自检：`tests/map/test_godot_map_pipeline.gd`

## 1. 唯一地图管线

项目只支持 Godot 自带 TileMap/TileSet 编辑器：地图保存为 `maps/godot/scenes/*.tscn`，
统一使用 **48×48（1 格 = 1 米）** 图块、`solid`/`tag` 语义、Godot 地形集自动拼接和 `Marker2D` 关键点。
Tiled、TMX、YATI 与旧 16px 兼容层已移除。

## 2. 目录与产物

```
assets/dark48/                           ← 48px 素材（美术线交付，见其 README）
maps/godot/
├── tilesets/
│   ├── dark48.spec.json                 ← 手写：素材清单 + 语义 + 自动拼接集声明
│   ├── dark48.tres                      ← 生成：TileSet（含 solid/tag、地形集、pipeline 元数据）
│   ├── dark48_图块清单.md                ← 生成：语义清单（坐标/名称/tag/阻挡）
│   ├── dark48_图块对照表.html            ← 生成：放大带坐标的对照表（刷图时对着看）
│   ├── atlas/dark48_*.png               ← 生成：由单张素材打包出的图集
│   └── atlas/…_*.pack.json              ← 生成：图集指纹（素材没变就不重打包，避免反复重新导入）
├── tools/
│   ├── build_tileset.gd                 ← 第 1 步：素材 + spec → TileSet
│   ├── make_map.gd                      ← 第 2 步：模板 / 示例地图 / 新地图脚手架
│   ├── map_palette.gd                   ← 制图库：材质 → 图块、自动拼接重算
│   ├── autotile_fixup.gd                ← 附件：把随手铺的材质修成正确的边缘块
│   └── preview_map.gd                   ← 附件：合成预览图 + 打印画面占比（75/20/5）
└── scenes/
    ├── dark48_map_template.tscn         ← 空白模板（26×15，六图层 + 九标记）
    ├── abbey_outskirts.tscn             ← 示例地图「修道院外的荒院」
    ├── abbey_outskirts_preview.png      ← 示例地图预览

core/world/map_scene.gd                  ← 地图场景运行时接口（挂在场景根节点）
                                          ↑ 已接入大型建筑：占用区内由建筑裁定通行（见 building_pipeline.md）
assets/buildings/<building_id>/           ← **大型建筑资产包**（视觉 + 掩码 + metadata + Prefab）★
buildings 管线工具：
  maps/godot/tools/build_building.gd     ← 建筑管线第 1 步：spec + 美术原图 → 资产包
  maps/godot/tools/building_tool.gd      ← Agent 高层工具：list/inspect/place/remove/move/validate
  core/building/                         ← Building / BuildingData / BuildingLibrary / BuildingPlacer / BuildingValidator / BuildingMask
  world/map/BuildingViewer.tscn          ← 建筑查验器（鼠标逐格查看占用/可走/门/房间）
  tests/map/test_building_pipeline.gd    ← 建筑管线自检
core/world/main.gd                       ← 大世界：读地图尺寸/倍率/标记，按视口居中摆位
world/map/MainGodotMap.tscn              ← 接入演示入口（大世界底图 = 管线地图）
tests/map/test_godot_map_pipeline.gd     ← 管线自检（129 条断言）
```

## 3. 六步流程

### 第 1 步：素材（`assets/dark48/`）

当前用美术线交付的 48px 素材：5 张地面材质 + 4 个道具 + 4 组自动拼接集（128 张）+ 图标/UI/角色。
规格（尺寸、无缝、色板、视角、语义）见 [style_guide.md](../art/style_guide.md)；缺素材按 [asset_request.md](../art/asset_request.md) 提需求。

### 第 2 步：生成图块集（素材 + spec → TileSet）

```bat
:: 新素材/新图集要先让 Godot 导入一次，否则 .tres 引用不到纹理
C:\1\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\游戏 --import
:: 然后（无参数 = 重建 tilesets/ 下全部 spec）
C:\1\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\游戏 --script maps/godot/tools/build_tileset.gd
```

工具做的事：把 spec 里列的单张 PNG **按网格打包成图集**（图集是生成物，别手改）→ 生成 TileSet →
为每块图块写 `solid`/`tag` → 给自动拼接集写 **Godot 地形集**（四边匹配）→ 在 TileSet 里写 **`pipeline` 元数据**
（材料 → 图块坐标、4 组自动拼接集的掩码表）→ 输出图块清单与对照表。

**spec 字段**

| 字段 | 说明 |
| --- | --- |
| `tileset_name` / `display_name` / `tile_size` | 输出名、中文名、网格尺寸（48×48） |
| `custom_data` | **必须**声明 `solid`(bool) 与 `tag`(string)，名字固定 |
| `sources[].name` | 图块来源名（= 一张打包图集） |
| `sources[].columns` | 图集按"网格单元"分几列（2×2 道具占 2 列） |
| `sources[].items[]` | 普通图块：`{tag, name, solid, file[, size:[2,2], note]}` |
| `sources[].extras[]` | 自动拼接集里的"补丁填充块"：`{tag, file, terrain, name}` |
| `sources[].autotile` | 16 配置自动拼接集：`{pair, base_tag, patch_tag, dir, prefix, variants}` |
| `sources[].terrain` | 对应的 Godot 地形集：`{set, base, patch}` |

### 第 3 步：在 Godot 编辑器里画图

1. 双击 `启动地图编辑器.bat` 打开项目。
2. 打开 `maps/godot/scenes/dark48_map_template.tscn`，**先另存为** `maps/godot/scenes/<你的地图名>.tscn`。
3. 选中「地形」层 → 底部 TileMap 面板：
   - **推荐**：切到「地形」模式，直接刷**材质**（草地/泥土/石砖路…），边缘块由引擎按四邻自动选；
   - 或者手动选块 —— 对着 `dark48_图块对照表.html`（左上角数字 = TileSet 面板里的 `(col,row)`）。
4. 铺道具（「植被」放树、「装饰」放石头）；**2×2 的大树/立石按 2 格网格摆，占满 2×2**。
5. 摆标记（第 5 节），`Ctrl+S` 保存。
6. 如果手工铺材质时边缘块选得不放心，跑一次修正（幂等，可反复跑）：
   ```bat
   … --script maps/godot/tools/autotile_fixup.gd -- res://maps/godot/scenes/<地图>.tscn
   ```

### 第 4 步：图层与通行性

| 顺序 | 图层名 | 放什么 |
| --- | --- | --- |
| 1 | `地形` | 地面材质（草地/枯草/泥土/碎石/石砖路 + 自动拼接边缘块）。**必须铺满可通行区域** |
| 2 | `高差` | 崖面/台坎/墙脚阴影 |
| 3 | `建筑` | 墙体、屋顶、门窗（48px 素材线还没出这类构件，见 style_guide 第十一节） |
| 4 | `装饰` | 围栏、垄沟、花圃、岩石/立石 |
| 5 | `植被` | 树（单格枯树 / 2×2 大树）、灌木 |
| 6 | `碰撞` | **不显示**；只放"没有美术的阻挡"（隐形墙） |

#### 3/4 立件如何嵌进正交地表

- 地图根节点声明 `metadata/projection_id = "orthogonal_3q_48_v1"`；建筑 metadata 的 `projection_id` 必须一致。
- `地形`、道路和纯地表层固定在 YSort 域之外；角色、树木、多格道具和建筑视觉遮挡带必须是同一个
  `YSortWorld`（现有地图可复用「建筑对象」容器）的直接或等效排序成员。
- 参与互相遮挡的对象统一 `z_index = 0`，排序节点坐标放在脚点/墙脚/遮挡带底边，可见图像作为子节点向上偏移。屋顶、发光等纯覆盖层才使用更高 z。
- 大型建筑仍以一个 Prefab、一套完整源视觉和一套独立逻辑放置；“遮挡带”只是绘制时对同一纹理作 region 分段，
  不是把建筑切回几十个 Tile。
- 正式建筑优先读取 metadata 的 `sorting.bands[]` 生成语义遮挡带；没有声明时不擅自切图。`BuildingProjectionLab.tscn`
  仍可为旧资产生成等高实验带，用来验证方案，不作为生产数据。
- `Main` 加载带「建筑对象」YSort 容器的 Godot 地图时，会把玩家和 NPC 根节点迁入该容器并保留世界坐标。
- 角色/NPC 根节点必须是脚点。移动边界换算到其父节点局部坐标；战斗触发、技能光点、交互与存档一律比较世界坐标。
- 可直接打开 `world/map/MainHighlandMap.tscn` 验收高原修道院的生产接入；`BuildingProjectionLab.tscn` 只保留为切带调试场。
- `project.godot` 的默认启动场景使用 `world/map/MainHighlandMap.tscn`；该场景是玩法外壳，内部加载
  `maps/godot/scenes/iserra_monastery_highlands.tscn`，不要把纯地图资源直接设为主场景。

通行性判定（`core/world/map_scene.gd`）：

- 除「地形」外的图块层里，图块 `solid = true` → 该格不可通行；
- 「碰撞」层里放了**任何**图块 → 该格不可通行（放什么图块无所谓，它不显示）；
- 「地形」层没铺的格子 → 不可通行；
- **2×2 大图块占的 4 格全部算阻挡**（引擎只在起始格存 TileData，`MapScene` 会回看四个可能的起始格）。

### 第 5 步：摆标记

标记放在「标记」这个 Node2D 下，**Marker2D 的节点名就是标记 id**：

| 标记 id | 必需 | 用途（谁读它） |
| --- | --- | --- |
| `spawn` | ✅ | 出生点；存档位置越界时回到这里 |
| `battle_trigger` | ✅ | 战斗触发点（进半径切 `BattleMap.tscn`） |
| `story_trigger` | ✅ | 剧情触发点（金色菱形） |
| `skill_light` | ✅ | 技能光点（靠近询问是否学「冲锋」） |
| `gate` / `church` / `bell_tower` / `cloister` / `kitchen_garden` / `herb_garden` | 可选 | 地标点，供剧情/任务/UI 引用 |

### 第 6 步：校验 + 接入

```bat
:: 结构 + 语义 + 材质配比 + 自动拼接 + 画面级 75/20/5（129 条断言）
… --script tests\map\test_godot_map_pipeline.gd
:: 出预览图（不看编辑器也能过目；打印 COMPOSITION 深/浅/亮占比）
… --script maps/godot/tools/preview_map.gd -- res://maps/godot/scenes/<地图>.tscn --scale 2
```

接入方式（任选）：

1. **换主场景底图**：`world/map/Main.tscn` 选中根节点，把导出属性 `overworld_map_scene` 改成你的地图路径。
   地图自带尺寸、显示倍率与标记 → 代码不用改。
2. **看效果**：直接跑 `res://world/map/MainGodotMap.tscn`（演示入口，底图 = `abbey_outskirts.tscn`）。

坐标换算：地图局部像素 → 主场景坐标 = **居中摆位 + 局部像素 × 地图的 `display_scale`**。
`main.gd` 按视口把地图居中：48px 素材 `display_scale = 1.0`（1:1），26×15 格 = 1248×720 正好一屏。

> **已知限制**：`is_walkable()` 与图块 `solid` 已可用并被测试覆盖，但主场景移动目前只受矩形边界限制，
> **还没按 `is_walkable()` 拦截撞墙**；更大的地图还需要把 `CameraCtrl` 的跟随接进 `main.gd`。

## 4. 约定（不要随便改）

1. **图层名与顺序**固定为 地形/高差/建筑/装饰/植被/碰撞（`MapScene.LAYERS`），改名会让 `validate()` 报错。
2. **素材只追加、不挪位**：`.tscn` 记住的是图块坐标；重排素材会让已画好的地图画错。
3. **边 tile 不许翻转**（`自动拼接/` 的错位翻转会把边界条带翻到错误的一侧）；破重复感用多变体交替。
4. **补丁要与正确的底材相邻**：石砖路/碎石的底材是**泥土**，草地是泥土/枯草的底材。
   让石砖路直接贴草地会留下无人负责的硬边（修正工具会报"材质冲突"）。
5. **命名**：地图场景 `maps/godot/scenes/<地图名>.tscn`（ASCII 小写下划线）；标记 id 同规范。

## 5. 命令速查

```bat
:: 新素材导入（改了素材/图集后都要）
… --headless --path C:\游戏 --import
:: 重建全部图块集（素材或 spec 改动后必跑）
… --script maps/godot/tools/build_tileset.gd
:: 重建模板/示例地图（--only dark48 只做 48px 那组）
… --script maps/godot/tools/make_map.gd
:: 新建一张地图的脚手架
… --script maps/godot/tools/make_map.gd -- --name my_place --size 26x15 --scale 1.0
:: 手绘地图的边缘块修正（--check 只检查不改）
… --script maps/godot/tools/autotile_fixup.gd -- res://maps/godot/scenes/<地图>.tscn
:: 预览图 + 画面占比
… --script maps/godot/tools/preview_map.gd -- res://maps/godot/scenes/<地图>.tscn
:: 管线自检
… --script tests\map\test_godot_map_pipeline.gd
:: 打开编辑器画图
启动地图编辑器.bat
```

（`…` = `C:\1\Godot_v4.7.1-stable_win64_console.exe`）

## 6. 常见坑

- **图集没导入**：新跑 `build_tileset.gd` 打完图集会提示"需要先导入素材"——跑一次 `--import` 再重跑即可（幂等）。
- **改了素材但图集没更新**：工具用"路径+大小+修改时间"指纹判断，素材变了会自动重打包（`PACK` 行），
  没变则复用（不会反复触发重新导入）。
- **`solid` 忘了标**：默认 false（可以走过去）；墙、树、水、巨石要标 true。
- **2×2 道具只挡了一格**：那说明导入时没按 2×2 建块（spec 里 `size` 没写）；测试里有断言。
- **「碰撞」层看不见**：它默认 `visible=false`，在 TileMap 面板图层列表里点眼睛才会显示。
- **材质配比跑偏**：整图会跟着偏离 75/20/5。铺图参考标定配比 **草 60 / 枯草 15 / 泥土 12 / 碎石 6 / 石砖 7**，
  用 `preview_map.gd` 的 COMPOSITION 行核对。
- **别手改生成物**：`*.tres`、`atlas/*.png`、`*_图块清单.md`、`*_图块对照表.html` 都是产物，改 spec 后重跑工具。
- **首次开编辑器会多出 `.uid` 文件**：Godot 会给新增 `.gd` 生成 `.uid`，并要把项目扫一遍才认识全局类名 ——
  工具与测试都用 `preload()` 取脚本，**不依赖类名缓存**，所以没开编辑器也能跑。

## 7. 缺素材怎么办

1. 先看 `assets/dark48/` 有没有现成的（以及 `docs/art/style_guide.md` 第十一节的缺口清单）。
2. 找不到 → 按 [asset_request.md](../art/asset_request.md) 填需求单（规格直接引用 style_guide）。
3. 素材到手：放进 `assets/dark48/<分类>/` → 更新 `assets/dark48/README.md` 与 `来源与许可.md` →
   `--import` → 在 `dark48.spec.json` 追加条目 → 重跑第 2 步 → 在编辑器里刷新地图 → 跑自检。

## 8. 大型建筑制作

统一按[新版指导手册](map_production_workflow.md)：平面/灰盒与独立逻辑 → 分层生成材质 → Godot约束轮廓和色板 → 实际运行验收。

完整建筑使用Building场景，按遮挡语义分区；视觉、占地、碰撞各自明确，方格48px=1米。已确认样板为dev/hall_art_v1，启动器“启动会堂美术审验.bat”。原有地形编辑器步骤仍用于地表，不承担整座建筑制作。

## 9. 地图架构第一阶段实验场

方案的第一阶段不直接迁移正式地图，统一在 `res://dev/map_pipeline_test/map_pipeline_test.tscn` 验证：

- Terrain TileMap 地面和道路；
- `house_a` 完整 Pattern Stamp；
- 大型建筑 PackedScene、Anchor、独立碰撞、YSort 与 Roof；
- 自由 Prop；
- SceneDoor 往返独立 Interior；
- 大型建筑 Ghost（半透明视觉、Footprint 网格、Anchor、Entrances、合法/非法颜色）。

```bat
:: 运行实验场
… --path C:\游戏 res://dev/map_pipeline_test/map_pipeline_test.tscn
:: 自动验收
… --script tests\map\test_map_pipeline_phase_one.gd
```

实验场中的 Ghost 左键放置只影响本次运行；要把建筑持久化写入地图，仍使用 `building_tool.gd place`。Pattern 定义位于 `content/map_patterns/`，自由 Prop 位于 `world/props/`，两者都不修改正式大地图。


## 莱顿城三图逻辑灰盒验收场

入口 `maps/leyton/scenes/slice_test.tscn`；规范数据、规则、操作与限制见 `maps/leyton/README.md`。复用 MapScene 六层语义与一期玩家资源，当前只验证 M01/M04/M07 的通行和往返，不代表正式地图美术交付。验收脚本 `tests/map/test_leyton.gd`。


## 当前重构入口（2026-09-28）

- 城市与修道院四项修正见maps/leyton/rework_v2/README.md。
- 城市在现有数据驱动布局上加入独立Pattern/FreeProp；城内砖石，郊外地貌保留。
- 修道院生成入口make_iserra_monastery_map.gd兼容委托refactor_iserra_map.gd，读取最新版完整建筑，重建环境，不再回到旧dark48全图块道具生成流程。
- 重构器会重新生成环境对象；编辑环境前应修改规范生成器/数据，避免在生成副本独立手改。大型建筑源资产仍由building管线负责。
