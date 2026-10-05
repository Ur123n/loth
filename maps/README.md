# 地图目录

项目只保留 **Godot 48×48 正方形网格地图管线**。地图使用 Godot 自带的 TileMap/TileSet 编辑器制作，不再支持 Tiled、TMX、YATI 或旧 16px 图块表。

## 目录

- `godot/tilesets/dark48.spec.json`：48px 图块来源、语义与自动拼接声明。
- `godot/tilesets/dark48.tres`：生成的 TileSet。
- `godot/scenes/`：模板、示例与正式地图场景。
- `godot/tools/`：图块集生成、地图脚手架、自动拼接、预览和建筑工具。

完整制作流程见 [`docs/world/map_pipeline.md`](../docs/world/map_pipeline.md)，大型建筑见 [`docs/world/building_pipeline.md`](../docs/world/building_pipeline.md)。
