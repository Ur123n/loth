# AGENTS.md — Codex 执行规范

本文件面向 Codex 与任何 AI 开发助手：README 回答“项目是什么”，本文件回答“该怎么改代码、哪些事情不能做”。两者不要重复。

## 工作流程

### 第一步：识别模块

判断任务属于哪个模块：

battle / card / character / effect / grid / ai / equipment / items / progression / world / quest / dialogue / ui / save / content / **building（大型建筑）**

凡是地图美术任务，必须先在下列三类中选定一种，不能先画图再倒推用途：

| 资产类别 | 判定 | 进入哪条管线 |
| --- | --- | --- |
| **Tile（图块）** | 地面、道路、水岸、墙段等需要重复铺设或自动拼接的规则单元 | `docs/world/map_pipeline.md` |
| **小物件（Prop）** | 树、岩石、箱子、路牌等可独立摆放的小型对象；通常占 1×1 或 2×2 格 | `docs/world/map_pipeline.md`，作为单张透明贴图接入 TileSet |
| **大型结构（Building / Structure）** | 城堡、修道院、要塞、庄园、巨型遗迹等具有完整轮廓、房间、入口和独立碰撞的整体 | `docs/world/building_pipeline.md`，生成完整建筑资产包与独立 Godot 场景 |

**城堡等大型结构禁止为了迁就 TileSet 而随意切成几十块 Tile。**必须先完成整座建筑的需求分析与概念设计，再制作完整视觉；只有真正需要重复铺设的通用构件才可另立图块需求。

### 第二步：读取局部文档

优先读取 `docs/<模块>/` 下的 README.md → rules.md → architecture.md，而不是扫描整个项目。新建内容优先看 `content/` 目录与 `docs/development/data_guides.md`。

大型建筑（不做成图块、整张图 + 独立逻辑）看 `docs/world/building_pipeline.md`；地块地形/道具看 `docs/world/map_pipeline.md`。

涉及生图的大型建筑任务统一按[新版制作手册](docs/world/map_production_workflow.md)：**需求/概念 → 平面与灰盒、独立碰撞/入口 → 结构试玩 → 内置imagegen分层材质 → Godot灰盒alpha/逻辑像素/色板约束 → 实际画面与玩法验收 → 版本化交付**。非技术的美术风格、世界观、比例和内容需求继续保留。参考已确认的dev/hall_art_v1；不得从生成图推导碰撞，也不得把旧安装/采样/切图方案作为现行路线。

### 第三步：检查依赖

只读取当前模块直接依赖的模块。依赖方向（见 docs/architecture.md）：

World → Quest/Dialogue → Character/Progression → Battle → Card/Effect

底层模块不能反向依赖上层模块（例如 CardSystem 不得调用 WorldManager；战斗结束通过 BattleResult 交给上层处理）。

### 第四步：修改

只修改完成任务所需的最少文件。优先：

- 扩展已有系统，而不是创建平行系统（不要为单张卡牌复制卡牌系统、为单个 NPC 复制任务系统）
- 新增内容通过 `content/` 数据资源完成，而不是修改 `core/`
- 不把具体游戏内容硬编码进核心系统
- 涉及核心系统的修改必须保证现有功能不被破坏

### 第五步：测试

执行对应模块测试（全部必须 `failed=0`）：

```
C:\1\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\游戏 --script tests\<模块>\test_*.gd
```

修改核心系统后还需验证：主场景/战斗场景无头加载无脚本错误、已有卡牌/角色正常、已有存档可读取。

改地图/建筑管线时至少跑：

```
… --script tests\map\test_godot_map_pipeline.gd     （48px 地图管线）
… --script tests\map\test_building_pipeline.gd      （大型建筑管线）
```

### 第六步：更新文档

如果修改改变了系统行为，同步更新对应 `docs/<模块>/rules.md` 或 `architecture.md`，并追加 `docs/development/changelog.md`。

## 规则变化流程

规则变化时：**先更新规则文档，再修改代码**。例如 buff 结算规则变化 → 先改 docs/battle/rules.md，再改 core/effect/。

## 禁止行为

- 未经明确要求：重构整个项目、修改无关模块、删除现有系统、修改核心游戏规则
- 将大量游戏内容硬编码进 .gd 文件
- 创建重复功能
- 模块之间直接侵入对方内部实现（应通过 Signal / Event / Result Data）
- 未测试就交付核心系统修改

## 目录速查

| 目录 | 内容 |
| --- | --- |
| core/ | 规则与通用系统（脚本） |
| core/building/ | **大型建筑**：Building / BuildingData / BuildingLibrary / BuildingPlacer / BuildingValidator / BuildingMask |
| content/ | 具体内容数据（JSON / .tres） |
| world/ | 世界场景 |
| ui/ | 界面逻辑 |
| demo/ | 战斗测试 Demo |
| tests/ | 无头测试 |
| docs/ | 模块文档 |
| assets/ | 美术资源 |
| assets/buildings/ | **大型建筑资产包**（visual + masks + metadata + Prefab；规范见 docs/world/building_pipeline.md） |
| maps/ | 48px Godot TileMap/TileSet 地图管线：见 docs/world/map_pipeline.md，缺素材见 docs/art/asset_request.md |
| docs/art/ | **美术规格**（style_guide.md：48px 俯视黑暗奇幻）+ 素材需求单 |
| docs/world/building_pipeline.md | **大型建筑管线**（标准资产包 / 掩码规范 / 高层 API / 校验） |
| 编辑器/ | Excel 数据源与内容工具 |

## 网格口径（别搞混）

**除战斗地图外，游戏地图一律正方形网格**（48 px = 1 米，1 格 = 1 米）。

| 地图 | 网格 | 代码 |
| --- | --- | --- |
| 大世界 / 地点地图 | 正方形 | `core/world/map_scene.gd` + `TileMapLayer` |
| 战斗地图 | 六边形（尖顶朝上，odd-r） | `core/grid/hex_grid.gd` + `core/battle/battle_map.gd` |

大型建筑只放在正方形网格的地图上；战斗侧只读建筑的 `tactical` / `collision` 数据，不读它的几何。
