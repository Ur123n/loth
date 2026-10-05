# maps/godot/ —— Godot 编辑器地图管线

用 **`assets/dark48/` 本地 48px 素材**在 **Godot 自带的 TileMap/TileSet 编辑器**里画地图，
产出原生 `.tscn`，带图块语义（`tag`/`solid`）与关键点标记（`spawn`/`battle_trigger`/…）。

完整说明见 **[docs/world/map_pipeline.md](../../docs/world/map_pipeline.md)**；缺素材见 [docs/art/asset_request.md](../../docs/art/asset_request.md)。

> **大型建筑不走这条管线**：它是一整张视觉大图 + 一套独立逻辑（占用/可通行/门/碰撞/战术），
> 封成 Building Prefab 放进地图，见 **[docs/world/building_pipeline.md](../../docs/world/building_pipeline.md)**。
> 两条管线共用同一套网格口径（正方形，48 px = 1 米）与同一批素材，互不干扰。

## 速查

```bat
:: 1) 素材/spec 改动后重建图块集（产出 .tres + 图块清单 md + 对照表 html）
C:\1\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\游戏 --script maps/godot/tools/build_tileset.gd

:: 2) 重建 48px 空白模板 + 示例地图（新地图脚手架：-- --name my_place --size 40x30）
… --script maps/godot/tools/make_map.gd

:: 3) 把地图合成预览图（不看编辑器也能过目；可传场景路径）
… --script maps/godot/tools/preview_map.gd
… --script maps/godot/tools/preview_map.gd -- res://maps/godot/scenes/<地图>.tscn

:: 4) 打开编辑器画图（双击项目根目录的 启动地图编辑器.bat，然后打开下面的模板）
::    maps/godot/scenes/dark48_map_template.tscn  → 另存为你的地图 → 刷图 → 摆标记 → Ctrl+S

:: 5) 自检
… --script tests\map\test_godot_map_pipeline.gd
```

## 大型建筑（另有一条管线，速查）

```bat
:: 1) spec + 美术原图 → 建筑资产包（掩码 / metadata / 碰撞 / 视觉 / 预览 / Prefab）
::    新建筑首次要先 import 一次才能引用贴图，工具会提示
… --headless --path C:\游戏 --import
… --script maps/godot/tools/build_building.gd -- --id <building_id>
… --headless --path C:\游戏 --import
… --script maps/godot/tools/build_building.gd -- --id <building_id> --phase prefab

:: 2) 手改过掩码想回灌 metadata（视觉不动）
… --script maps/godot/tools/build_building.gd -- --from-masks --id <building_id>

:: 3) Agent 高层工具（list / inspect / validate / place / remove / move / validate-map / demo；输出单行 JSON）
… --script maps/godot/tools/building_tool.gd -- list
… --script maps/godot/tools/building_tool.gd -- inspect --id iserra_monastery
… --script maps/godot/tools/building_tool.gd -- place --id iserra_monastery --map res://maps/godot/scenes/<地图>.tscn --at 6,6
… --script maps/godot/tools/building_tool.gd -- demo --id iserra_monastery --map res://maps/godot/scenes/monastery_grounds.tscn --at 6,6
… --script maps/godot/tools/building_tool.gd -- validate-map --map res://maps/godot/scenes/monastery_grounds.tscn

:: 4) 在引擎里逐格查验（鼠标指哪格就报哪格：占用/可走/门/房间）
… --path C:\游戏 res://world/map/BuildingViewer.tscn      （或双击 启动建筑查验.bat）

:: 5) 自检
… --script tests\map\test_building_pipeline.gd
```

（`…` = `C:\1\Godot_v4.7.1-stable_win64_console.exe`）

## 目录

| 路径 | 说明 |
| --- | --- |
| `tilesets/<名>.spec.json` | **手写**：图块语义表（坐标 → tag / 是否阻挡） |
| `tilesets/<名>.tres` | 生成：TileSet，编辑器选块用的就是它 |
| `tilesets/<名>_图块清单.md` | 生成：语义清单 + 新图块可用的空白格 |
| `tilesets/<名>_图块对照表.html` | 生成：4 倍放大带坐标的对照表（浏览器打开，刷图时对着看） |
| `tools/build_tileset.gd` | 第 1 步：素材 + spec → TileSet |
| `tools/make_map.gd` | 第 2 步：生成空白模板 / 示例地图 / 新地图脚手架 |
| `tools/preview_map.gd` | 附件：把地图（**含大型建筑**）合成成预览 PNG（碰撞层不画） |
| `tools/build_building.gd` | **建筑管线第 1 步**：building.spec.json + 美术原图 → 建筑资产包 |
| `tools/building_tool.gd` | **建筑高层工具**（Agent 接口，输出单行 JSON） |
| `scenes/dark48_map_template.tscn` | 48px 空白模板（六图层 + 九标记，未刷图） |
| `scenes/abbey_outskirts.tscn` | 48px 示例地图「修道院外围」，可直接在编辑器里改 |
| `scenes/monastery_grounds.tscn` | **示例地图「修道院」**：地形 + 伊瑟拉修道院（57×66 格）+ 标记 |
| `scenes/<地图>_preview.png` | 示例地图预览（由 preview_map.gd 生成） |

## 两条约定（改之前先读文档）

1. **图层名与顺序固定**：`地形 / 高差 / 建筑 / 装饰 / 植被 / 碰撞`（`碰撞` 层不显示，只放隐形阻挡）。
2. **素材只追加、不挪位**：新图块画在空白格上，已用过的坐标不能动 —— `.tscn` 记住的是图块坐标。

## 第三条约定（有了大型建筑之后）

大型建筑挂在名为 **`建筑对象`** 的 Node2D 容器下（`MapScene.BUILDING_ROOT`），
**不要把它们拆成图块**，也不要手工去改它们的子节点 —— 用 `building_tool.gd` 放/搬/删，
几何以 `assets/buildings/<id>/metadata/building.json` 为准。
地图里没有这个容器时，`MapScene` 的行为与之前完全一致（旧地图零影响）。
