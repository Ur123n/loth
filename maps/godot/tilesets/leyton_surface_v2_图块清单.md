# 图块清单：莱顿城低重复地表与水岸

- 生成源：`maps/godot/tools/build_tileset.gd` + `leyton_surface_v2.spec.json`（**手改本文件无效：改 spec 后重跑工具**）
- 图集（生成物）：`res://maps/godot/tilesets/atlas/leyton_surface_v2_<来源>.png`
- 坐标 = 图集第 (col,row) 格；Godot 的 TileSet 面板按同一坐标选块（对照表 html 看得更直观）。
- 每块图块的 `tag`（语义）与 `solid`（是否阻挡）存在 TileSet 自定义数据里。
- 地形集（Godot terrain set，模式 = 四边匹配）：dirt_over_grass, road_over_dirt —— 用 TileMap 面板的「地形」模式刷图会自动选对边缘块。

## materials（res://maps/godot/tilesets/atlas/leyton_surface_v2_materials.png，11 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | grass | `grass` | 否 |  |
| (1,0) | grass_variant_1 | `grass_variant_1` | 否 |  |
| (2,0) | grass_variant_2 | `grass_variant_2` | 否 |  |
| (3,0) | grass_variant_3 | `grass_variant_3` | 否 |  |
| (4,0) | dirt | `dirt` | 否 |  |
| (5,0) | road_stone | `road_stone` | 否 |  |
| (6,0) | road_stone_variant_1 | `road_stone_variant_1` | 否 |  |
| (7,0) | road_stone_variant_2 | `road_stone_variant_2` | 否 |  |
| (0,1) | road_stone_variant_3 | `road_stone_variant_3` | 否 |  |
| (1,1) | water_deep | `water_deep` | 是 |  |
| (2,1) | wall_top | `wall_top` | 是 |  |

## auto_dirt_over_grass（res://maps/godot/tilesets/atlas/leyton_surface_v2_auto_dirt_over_grass.png，32 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | 自动拼接 dirt_over_grass：四邻都（v1） | `edge_dirt_over_grass_none_v1` | 否 | 底材=grass；掩码 none(0) |
| (1,0) | 自动拼接 dirt_over_grass：四邻都（v2） | `edge_dirt_over_grass_none_v2` | 否 | 底材=grass；掩码 none(0) |
| (2,0) | 自动拼接 dirt_over_grass：北（v1） | `edge_dirt_over_grass_n_v1` | 否 | 底材=grass；掩码 n(1) |
| (3,0) | 自动拼接 dirt_over_grass：北（v2） | `edge_dirt_over_grass_n_v2` | 否 | 底材=grass；掩码 n(1) |
| (4,0) | 自动拼接 dirt_over_grass：东（v1） | `edge_dirt_over_grass_e_v1` | 否 | 底材=grass；掩码 e(2) |
| (5,0) | 自动拼接 dirt_over_grass：东（v2） | `edge_dirt_over_grass_e_v2` | 否 | 底材=grass；掩码 e(2) |
| (6,0) | 自动拼接 dirt_over_grass：北、东（v1） | `edge_dirt_over_grass_ne_v1` | 否 | 底材=grass；掩码 ne(3) |
| (7,0) | 自动拼接 dirt_over_grass：北、东（v2） | `edge_dirt_over_grass_ne_v2` | 否 | 底材=grass；掩码 ne(3) |
| (0,1) | 自动拼接 dirt_over_grass：南（v1） | `edge_dirt_over_grass_s_v1` | 否 | 底材=grass；掩码 s(4) |
| (1,1) | 自动拼接 dirt_over_grass：南（v2） | `edge_dirt_over_grass_s_v2` | 否 | 底材=grass；掩码 s(4) |
| (2,1) | 自动拼接 dirt_over_grass：北、南（v1） | `edge_dirt_over_grass_ns_v1` | 否 | 底材=grass；掩码 ns(5) |
| (3,1) | 自动拼接 dirt_over_grass：北、南（v2） | `edge_dirt_over_grass_ns_v2` | 否 | 底材=grass；掩码 ns(5) |
| (4,1) | 自动拼接 dirt_over_grass：东、南（v1） | `edge_dirt_over_grass_es_v1` | 否 | 底材=grass；掩码 es(6) |
| (5,1) | 自动拼接 dirt_over_grass：东、南（v2） | `edge_dirt_over_grass_es_v2` | 否 | 底材=grass；掩码 es(6) |
| (6,1) | 自动拼接 dirt_over_grass：北、东、南（v1） | `edge_dirt_over_grass_nes_v1` | 否 | 底材=grass；掩码 nes(7) |
| (7,1) | 自动拼接 dirt_over_grass：北、东、南（v2） | `edge_dirt_over_grass_nes_v2` | 否 | 底材=grass；掩码 nes(7) |
| (0,2) | 自动拼接 dirt_over_grass：西（v1） | `edge_dirt_over_grass_w_v1` | 否 | 底材=grass；掩码 w(8) |
| (1,2) | 自动拼接 dirt_over_grass：西（v2） | `edge_dirt_over_grass_w_v2` | 否 | 底材=grass；掩码 w(8) |
| (2,2) | 自动拼接 dirt_over_grass：北、西（v1） | `edge_dirt_over_grass_nw_v1` | 否 | 底材=grass；掩码 nw(9) |
| (3,2) | 自动拼接 dirt_over_grass：北、西（v2） | `edge_dirt_over_grass_nw_v2` | 否 | 底材=grass；掩码 nw(9) |
| (4,2) | 自动拼接 dirt_over_grass：东、西（v1） | `edge_dirt_over_grass_ew_v1` | 否 | 底材=grass；掩码 ew(10) |
| (5,2) | 自动拼接 dirt_over_grass：东、西（v2） | `edge_dirt_over_grass_ew_v2` | 否 | 底材=grass；掩码 ew(10) |
| (6,2) | 自动拼接 dirt_over_grass：北、东、西（v1） | `edge_dirt_over_grass_new_v1` | 否 | 底材=grass；掩码 new(11) |
| (7,2) | 自动拼接 dirt_over_grass：北、东、西（v2） | `edge_dirt_over_grass_new_v2` | 否 | 底材=grass；掩码 new(11) |
| (0,3) | 自动拼接 dirt_over_grass：南、西（v1） | `edge_dirt_over_grass_sw_v1` | 否 | 底材=grass；掩码 sw(12) |
| (1,3) | 自动拼接 dirt_over_grass：南、西（v2） | `edge_dirt_over_grass_sw_v2` | 否 | 底材=grass；掩码 sw(12) |
| (2,3) | 自动拼接 dirt_over_grass：北、南、西（v1） | `edge_dirt_over_grass_nsw_v1` | 否 | 底材=grass；掩码 nsw(13) |
| (3,3) | 自动拼接 dirt_over_grass：北、南、西（v2） | `edge_dirt_over_grass_nsw_v2` | 否 | 底材=grass；掩码 nsw(13) |
| (4,3) | 自动拼接 dirt_over_grass：东、南、西（v1） | `edge_dirt_over_grass_esw_v1` | 否 | 底材=grass；掩码 esw(14) |
| (5,3) | 自动拼接 dirt_over_grass：东、南、西（v2） | `edge_dirt_over_grass_esw_v2` | 否 | 底材=grass；掩码 esw(14) |
| (6,3) | 自动拼接 dirt_over_grass：北、东、南、西（v1） | `edge_dirt_over_grass_nesw_v1` | 否 | 底材=grass；掩码 nesw(15) |
| (7,3) | 自动拼接 dirt_over_grass：北、东、南、西（v2） | `edge_dirt_over_grass_nesw_v2` | 否 | 底材=grass；掩码 nesw(15) |

## auto_road_over_dirt（res://maps/godot/tilesets/atlas/leyton_surface_v2_auto_road_over_dirt.png，32 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | 自动拼接 road_over_dirt：四邻都（v1） | `edge_road_over_dirt_none_v1` | 否 | 底材=dirt；掩码 none(0) |
| (1,0) | 自动拼接 road_over_dirt：四邻都（v2） | `edge_road_over_dirt_none_v2` | 否 | 底材=dirt；掩码 none(0) |
| (2,0) | 自动拼接 road_over_dirt：北（v1） | `edge_road_over_dirt_n_v1` | 否 | 底材=dirt；掩码 n(1) |
| (3,0) | 自动拼接 road_over_dirt：北（v2） | `edge_road_over_dirt_n_v2` | 否 | 底材=dirt；掩码 n(1) |
| (4,0) | 自动拼接 road_over_dirt：东（v1） | `edge_road_over_dirt_e_v1` | 否 | 底材=dirt；掩码 e(2) |
| (5,0) | 自动拼接 road_over_dirt：东（v2） | `edge_road_over_dirt_e_v2` | 否 | 底材=dirt；掩码 e(2) |
| (6,0) | 自动拼接 road_over_dirt：北、东（v1） | `edge_road_over_dirt_ne_v1` | 否 | 底材=dirt；掩码 ne(3) |
| (7,0) | 自动拼接 road_over_dirt：北、东（v2） | `edge_road_over_dirt_ne_v2` | 否 | 底材=dirt；掩码 ne(3) |
| (0,1) | 自动拼接 road_over_dirt：南（v1） | `edge_road_over_dirt_s_v1` | 否 | 底材=dirt；掩码 s(4) |
| (1,1) | 自动拼接 road_over_dirt：南（v2） | `edge_road_over_dirt_s_v2` | 否 | 底材=dirt；掩码 s(4) |
| (2,1) | 自动拼接 road_over_dirt：北、南（v1） | `edge_road_over_dirt_ns_v1` | 否 | 底材=dirt；掩码 ns(5) |
| (3,1) | 自动拼接 road_over_dirt：北、南（v2） | `edge_road_over_dirt_ns_v2` | 否 | 底材=dirt；掩码 ns(5) |
| (4,1) | 自动拼接 road_over_dirt：东、南（v1） | `edge_road_over_dirt_es_v1` | 否 | 底材=dirt；掩码 es(6) |
| (5,1) | 自动拼接 road_over_dirt：东、南（v2） | `edge_road_over_dirt_es_v2` | 否 | 底材=dirt；掩码 es(6) |
| (6,1) | 自动拼接 road_over_dirt：北、东、南（v1） | `edge_road_over_dirt_nes_v1` | 否 | 底材=dirt；掩码 nes(7) |
| (7,1) | 自动拼接 road_over_dirt：北、东、南（v2） | `edge_road_over_dirt_nes_v2` | 否 | 底材=dirt；掩码 nes(7) |
| (0,2) | 自动拼接 road_over_dirt：西（v1） | `edge_road_over_dirt_w_v1` | 否 | 底材=dirt；掩码 w(8) |
| (1,2) | 自动拼接 road_over_dirt：西（v2） | `edge_road_over_dirt_w_v2` | 否 | 底材=dirt；掩码 w(8) |
| (2,2) | 自动拼接 road_over_dirt：北、西（v1） | `edge_road_over_dirt_nw_v1` | 否 | 底材=dirt；掩码 nw(9) |
| (3,2) | 自动拼接 road_over_dirt：北、西（v2） | `edge_road_over_dirt_nw_v2` | 否 | 底材=dirt；掩码 nw(9) |
| (4,2) | 自动拼接 road_over_dirt：东、西（v1） | `edge_road_over_dirt_ew_v1` | 否 | 底材=dirt；掩码 ew(10) |
| (5,2) | 自动拼接 road_over_dirt：东、西（v2） | `edge_road_over_dirt_ew_v2` | 否 | 底材=dirt；掩码 ew(10) |
| (6,2) | 自动拼接 road_over_dirt：北、东、西（v1） | `edge_road_over_dirt_new_v1` | 否 | 底材=dirt；掩码 new(11) |
| (7,2) | 自动拼接 road_over_dirt：北、东、西（v2） | `edge_road_over_dirt_new_v2` | 否 | 底材=dirt；掩码 new(11) |
| (0,3) | 自动拼接 road_over_dirt：南、西（v1） | `edge_road_over_dirt_sw_v1` | 否 | 底材=dirt；掩码 sw(12) |
| (1,3) | 自动拼接 road_over_dirt：南、西（v2） | `edge_road_over_dirt_sw_v2` | 否 | 底材=dirt；掩码 sw(12) |
| (2,3) | 自动拼接 road_over_dirt：北、南、西（v1） | `edge_road_over_dirt_nsw_v1` | 否 | 底材=dirt；掩码 nsw(13) |
| (3,3) | 自动拼接 road_over_dirt：北、南、西（v2） | `edge_road_over_dirt_nsw_v2` | 否 | 底材=dirt；掩码 nsw(13) |
| (4,3) | 自动拼接 road_over_dirt：东、南、西（v1） | `edge_road_over_dirt_esw_v1` | 否 | 底材=dirt；掩码 esw(14) |
| (5,3) | 自动拼接 road_over_dirt：东、南、西（v2） | `edge_road_over_dirt_esw_v2` | 否 | 底材=dirt；掩码 esw(14) |
| (6,3) | 自动拼接 road_over_dirt：北、东、南、西（v1） | `edge_road_over_dirt_nesw_v1` | 否 | 底材=dirt；掩码 nesw(15) |
| (7,3) | 自动拼接 road_over_dirt：北、东、南、西（v2） | `edge_road_over_dirt_nesw_v2` | 否 | 底材=dirt；掩码 nesw(15) |

## shore（res://maps/godot/tilesets/atlas/leyton_surface_v2_shore.png，81 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | 三材质水岸 0 | `shore_0` | 是 |  |
| (1,0) | 三材质水岸 1 | `shore_1` | 是 |  |
| (2,0) | 三材质水岸 2 | `shore_2` | 是 |  |
| (3,0) | 三材质水岸 3 | `shore_3` | 是 |  |
| (4,0) | 三材质水岸 4 | `shore_4` | 是 |  |
| (5,0) | 三材质水岸 5 | `shore_5` | 是 |  |
| (6,0) | 三材质水岸 6 | `shore_6` | 是 |  |
| (7,0) | 三材质水岸 7 | `shore_7` | 是 |  |
| (8,0) | 三材质水岸 8 | `shore_8` | 是 |  |
| (0,1) | 三材质水岸 9 | `shore_9` | 是 |  |
| (1,1) | 三材质水岸 10 | `shore_10` | 是 |  |
| (2,1) | 三材质水岸 11 | `shore_11` | 是 |  |
| (3,1) | 三材质水岸 12 | `shore_12` | 是 |  |
| (4,1) | 三材质水岸 13 | `shore_13` | 是 |  |
| (5,1) | 三材质水岸 14 | `shore_14` | 是 |  |
| (6,1) | 三材质水岸 15 | `shore_15` | 是 |  |
| (7,1) | 三材质水岸 16 | `shore_16` | 是 |  |
| (8,1) | 三材质水岸 17 | `shore_17` | 是 |  |
| (0,2) | 三材质水岸 18 | `shore_18` | 是 |  |
| (1,2) | 三材质水岸 19 | `shore_19` | 是 |  |
| (2,2) | 三材质水岸 20 | `shore_20` | 是 |  |
| (3,2) | 三材质水岸 21 | `shore_21` | 是 |  |
| (4,2) | 三材质水岸 22 | `shore_22` | 是 |  |
| (5,2) | 三材质水岸 23 | `shore_23` | 是 |  |
| (6,2) | 三材质水岸 24 | `shore_24` | 是 |  |
| (7,2) | 三材质水岸 25 | `shore_25` | 是 |  |
| (8,2) | 三材质水岸 26 | `shore_26` | 是 |  |
| (0,3) | 三材质水岸 27 | `shore_27` | 是 |  |
| (1,3) | 三材质水岸 28 | `shore_28` | 是 |  |
| (2,3) | 三材质水岸 29 | `shore_29` | 是 |  |
| (3,3) | 三材质水岸 30 | `shore_30` | 是 |  |
| (4,3) | 三材质水岸 31 | `shore_31` | 是 |  |
| (5,3) | 三材质水岸 32 | `shore_32` | 是 |  |
| (6,3) | 三材质水岸 33 | `shore_33` | 是 |  |
| (7,3) | 三材质水岸 34 | `shore_34` | 是 |  |
| (8,3) | 三材质水岸 35 | `shore_35` | 是 |  |
| (0,4) | 三材质水岸 36 | `shore_36` | 是 |  |
| (1,4) | 三材质水岸 37 | `shore_37` | 是 |  |
| (2,4) | 三材质水岸 38 | `shore_38` | 是 |  |
| (3,4) | 三材质水岸 39 | `shore_39` | 是 |  |
| (4,4) | 三材质水岸 40 | `shore_40` | 是 |  |
| (5,4) | 三材质水岸 41 | `shore_41` | 是 |  |
| (6,4) | 三材质水岸 42 | `shore_42` | 是 |  |
| (7,4) | 三材质水岸 43 | `shore_43` | 是 |  |
| (8,4) | 三材质水岸 44 | `shore_44` | 是 |  |
| (0,5) | 三材质水岸 45 | `shore_45` | 是 |  |
| (1,5) | 三材质水岸 46 | `shore_46` | 是 |  |
| (2,5) | 三材质水岸 47 | `shore_47` | 是 |  |
| (3,5) | 三材质水岸 48 | `shore_48` | 是 |  |
| (4,5) | 三材质水岸 49 | `shore_49` | 是 |  |
| (5,5) | 三材质水岸 50 | `shore_50` | 是 |  |
| (6,5) | 三材质水岸 51 | `shore_51` | 是 |  |
| (7,5) | 三材质水岸 52 | `shore_52` | 是 |  |
| (8,5) | 三材质水岸 53 | `shore_53` | 是 |  |
| (0,6) | 三材质水岸 54 | `shore_54` | 是 |  |
| (1,6) | 三材质水岸 55 | `shore_55` | 是 |  |
| (2,6) | 三材质水岸 56 | `shore_56` | 是 |  |
| (3,6) | 三材质水岸 57 | `shore_57` | 是 |  |
| (4,6) | 三材质水岸 58 | `shore_58` | 是 |  |
| (5,6) | 三材质水岸 59 | `shore_59` | 是 |  |
| (6,6) | 三材质水岸 60 | `shore_60` | 是 |  |
| (7,6) | 三材质水岸 61 | `shore_61` | 是 |  |
| (8,6) | 三材质水岸 62 | `shore_62` | 是 |  |
| (0,7) | 三材质水岸 63 | `shore_63` | 是 |  |
| (1,7) | 三材质水岸 64 | `shore_64` | 是 |  |
| (2,7) | 三材质水岸 65 | `shore_65` | 是 |  |
| (3,7) | 三材质水岸 66 | `shore_66` | 是 |  |
| (4,7) | 三材质水岸 67 | `shore_67` | 是 |  |
| (5,7) | 三材质水岸 68 | `shore_68` | 是 |  |
| (6,7) | 三材质水岸 69 | `shore_69` | 是 |  |
| (7,7) | 三材质水岸 70 | `shore_70` | 是 |  |
| (8,7) | 三材质水岸 71 | `shore_71` | 是 |  |
| (0,8) | 三材质水岸 72 | `shore_72` | 是 |  |
| (1,8) | 三材质水岸 73 | `shore_73` | 是 |  |
| (2,8) | 三材质水岸 74 | `shore_74` | 是 |  |
| (3,8) | 三材质水岸 75 | `shore_75` | 是 |  |
| (4,8) | 三材质水岸 76 | `shore_76` | 是 |  |
| (5,8) | 三材质水岸 77 | `shore_77` | 是 |  |
| (6,8) | 三材质水岸 78 | `shore_78` | 是 |  |
| (7,8) | 三材质水岸 79 | `shore_79` | 是 |  |
| (8,8) | 三材质水岸 80 | `shore_80` | 是 |  |

## 追加新图块 / 新素材

1. 新素材按 `docs/art/style_guide.md` 的规格生产（尺寸、色板、视角、命名），放进 `assets/`。
2. 在 `leyton_surface_v2.spec.json` 里追加条目（单张 PNG 会自动打包进图集）。
3. 重跑本工具（新素材要先 `--import` 导入一次）。
4. 缺什么素材按 `docs/art/asset_request.md` 提需求。

