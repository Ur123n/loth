# 城市重构模型素材

内置image_gen分别生成stone_house、timber_house与urban_pavers；完整提示词在prompts.json，原图在source/。未用代码绘制住宅或替代模型生图。

- stone_house：8×8m基准，384×480 PNG，完整二层石屋Pattern。
- timber_house：6×6m基准，288×336 PNG，完整木构小屋Pattern。
- urban_pavers：48×48 PNG，1m²；TileSet中深色院地与正常亮度道路共享原图，使用TileData调制区别。

build_assets.gd使用alpha≥5%边界测量裁切（保留框内alpha）、最近邻缩放、map_env色板映射。manifest.json保留源图SHA与裁切信息。近透明边缘造成的空白已在GPU验收后修正。

register_assets.gd生成两种MapPatternInstance场景和maps/godot/tilesets/urban_rework_v1.tres。Pattern以南侧脚点为根，完整Sprite位于脚点上方，独立StaticBody2D表示地基，入口Marker供后续交互使用；未连接室内。地图通过map_object_placer.gd按占地放置，不将住宅拆成Tile。

重建顺序：build_assets.gd → Godot --editor --import → register_assets.gd。源图加载是开发期文件操作，不在导出游戏中执行。游戏只读取导入PNG/场景/TileSet。
