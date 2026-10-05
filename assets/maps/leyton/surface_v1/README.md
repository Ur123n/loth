# 莱顿城首批地表素材 v1

- 类别：Tile。内置 image_gen 生成两张源图，提示词见 `prompts.md`，源图见 `raw/`。
- 最终 48×48 图块：`tiles/water_deep.png`、`tiles/wall_top.png`。
- 处理器：现有美术工程 `tools/pixelize.py`，显式 tileable=True、fit=False，无抠底/描边/抖动。
- `palette.json` 为现有 layton_env 色板副本；分别使用 cold_water/deep_teal_stone 子集。
- `manifest.json` 保存来源、处理器哈希、图块哈希及尺寸/对边/alpha/色板/明度 QA。
- 深水：5 色、平均亮度31.45；墙顶：7 色、平均亮度60.48。两者亮色比例均0%，四边逐像素匹配。
- 引用：`maps/godot/tilesets/leyton_surface_v1.spec.json`，由原有构建器生成 TileSet。
- 本批仅为地表预览阶段；墙顶不等于完整城墙资产，深水不含水岸过渡。
