# 图块清单：黑暗奇幻 48px 素材集（俯视 2D · 1 格 = 1 米）

- 生成源：`maps/godot/tools/build_tileset.gd` + `dark48.spec.json`（**手改本文件无效：改 spec 后重跑工具**）
- 图集（生成物）：`res://maps/godot/tilesets/atlas/dark48_<来源>.png`
- 坐标 = 图集第 (col,row) 格；Godot 的 TileSet 面板按同一坐标选块（对照表 html 看得更直观）。
- 每块图块的 `tag`（语义）与 `solid`（是否阻挡）存在 TileSet 自定义数据里。
- 地形集（Godot terrain set，模式 = 四边匹配）：泥土压草地, 枯草压草地, 石砖路压泥土, 碎石压泥土 —— 用 TileMap 面板的「地形」模式刷图会自动选对边缘块。

## terrain（res://maps/godot/tilesets/atlas/dark48_terrain.png，5 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | 草地（最暗，明度阶梯 1/5） | `grass` | 否 |  |
| (1,0) | 枯草（2/5） | `grass_dry` | 否 |  |
| (2,0) | 泥土（3/5） | `dirt` | 否 |  |
| (3,0) | 碎石泥地（4/5） | `dirt_rocky` | 否 |  |
| (4,0) | 石砖路（最亮，唯一大块亮区） | `road_stone` | 否 |  |

## autotile_dirt_over_grass（res://maps/godot/tilesets/atlas/dark48_autotile_dirt_over_grass.png，33 块）

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
| (0,4) | 泥土（补丁填充） | `dirt` | 否 | 补丁格的平铺块 |

## autotile_dry_over_grass（res://maps/godot/tilesets/atlas/dark48_autotile_dry_over_grass.png，33 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | 自动拼接 dry_over_grass：四邻都（v1） | `edge_dry_over_grass_none_v1` | 否 | 底材=grass；掩码 none(0) |
| (1,0) | 自动拼接 dry_over_grass：四邻都（v2） | `edge_dry_over_grass_none_v2` | 否 | 底材=grass；掩码 none(0) |
| (2,0) | 自动拼接 dry_over_grass：北（v1） | `edge_dry_over_grass_n_v1` | 否 | 底材=grass；掩码 n(1) |
| (3,0) | 自动拼接 dry_over_grass：北（v2） | `edge_dry_over_grass_n_v2` | 否 | 底材=grass；掩码 n(1) |
| (4,0) | 自动拼接 dry_over_grass：东（v1） | `edge_dry_over_grass_e_v1` | 否 | 底材=grass；掩码 e(2) |
| (5,0) | 自动拼接 dry_over_grass：东（v2） | `edge_dry_over_grass_e_v2` | 否 | 底材=grass；掩码 e(2) |
| (6,0) | 自动拼接 dry_over_grass：北、东（v1） | `edge_dry_over_grass_ne_v1` | 否 | 底材=grass；掩码 ne(3) |
| (7,0) | 自动拼接 dry_over_grass：北、东（v2） | `edge_dry_over_grass_ne_v2` | 否 | 底材=grass；掩码 ne(3) |
| (0,1) | 自动拼接 dry_over_grass：南（v1） | `edge_dry_over_grass_s_v1` | 否 | 底材=grass；掩码 s(4) |
| (1,1) | 自动拼接 dry_over_grass：南（v2） | `edge_dry_over_grass_s_v2` | 否 | 底材=grass；掩码 s(4) |
| (2,1) | 自动拼接 dry_over_grass：北、南（v1） | `edge_dry_over_grass_ns_v1` | 否 | 底材=grass；掩码 ns(5) |
| (3,1) | 自动拼接 dry_over_grass：北、南（v2） | `edge_dry_over_grass_ns_v2` | 否 | 底材=grass；掩码 ns(5) |
| (4,1) | 自动拼接 dry_over_grass：东、南（v1） | `edge_dry_over_grass_es_v1` | 否 | 底材=grass；掩码 es(6) |
| (5,1) | 自动拼接 dry_over_grass：东、南（v2） | `edge_dry_over_grass_es_v2` | 否 | 底材=grass；掩码 es(6) |
| (6,1) | 自动拼接 dry_over_grass：北、东、南（v1） | `edge_dry_over_grass_nes_v1` | 否 | 底材=grass；掩码 nes(7) |
| (7,1) | 自动拼接 dry_over_grass：北、东、南（v2） | `edge_dry_over_grass_nes_v2` | 否 | 底材=grass；掩码 nes(7) |
| (0,2) | 自动拼接 dry_over_grass：西（v1） | `edge_dry_over_grass_w_v1` | 否 | 底材=grass；掩码 w(8) |
| (1,2) | 自动拼接 dry_over_grass：西（v2） | `edge_dry_over_grass_w_v2` | 否 | 底材=grass；掩码 w(8) |
| (2,2) | 自动拼接 dry_over_grass：北、西（v1） | `edge_dry_over_grass_nw_v1` | 否 | 底材=grass；掩码 nw(9) |
| (3,2) | 自动拼接 dry_over_grass：北、西（v2） | `edge_dry_over_grass_nw_v2` | 否 | 底材=grass；掩码 nw(9) |
| (4,2) | 自动拼接 dry_over_grass：东、西（v1） | `edge_dry_over_grass_ew_v1` | 否 | 底材=grass；掩码 ew(10) |
| (5,2) | 自动拼接 dry_over_grass：东、西（v2） | `edge_dry_over_grass_ew_v2` | 否 | 底材=grass；掩码 ew(10) |
| (6,2) | 自动拼接 dry_over_grass：北、东、西（v1） | `edge_dry_over_grass_new_v1` | 否 | 底材=grass；掩码 new(11) |
| (7,2) | 自动拼接 dry_over_grass：北、东、西（v2） | `edge_dry_over_grass_new_v2` | 否 | 底材=grass；掩码 new(11) |
| (0,3) | 自动拼接 dry_over_grass：南、西（v1） | `edge_dry_over_grass_sw_v1` | 否 | 底材=grass；掩码 sw(12) |
| (1,3) | 自动拼接 dry_over_grass：南、西（v2） | `edge_dry_over_grass_sw_v2` | 否 | 底材=grass；掩码 sw(12) |
| (2,3) | 自动拼接 dry_over_grass：北、南、西（v1） | `edge_dry_over_grass_nsw_v1` | 否 | 底材=grass；掩码 nsw(13) |
| (3,3) | 自动拼接 dry_over_grass：北、南、西（v2） | `edge_dry_over_grass_nsw_v2` | 否 | 底材=grass；掩码 nsw(13) |
| (4,3) | 自动拼接 dry_over_grass：东、南、西（v1） | `edge_dry_over_grass_esw_v1` | 否 | 底材=grass；掩码 esw(14) |
| (5,3) | 自动拼接 dry_over_grass：东、南、西（v2） | `edge_dry_over_grass_esw_v2` | 否 | 底材=grass；掩码 esw(14) |
| (6,3) | 自动拼接 dry_over_grass：北、东、南、西（v1） | `edge_dry_over_grass_nesw_v1` | 否 | 底材=grass；掩码 nesw(15) |
| (7,3) | 自动拼接 dry_over_grass：北、东、南、西（v2） | `edge_dry_over_grass_nesw_v2` | 否 | 底材=grass；掩码 nesw(15) |
| (0,4) | 枯草（补丁填充） | `grass_dry` | 否 | 补丁格的平铺块 |

## autotile_road_over_dirt（res://maps/godot/tilesets/atlas/dark48_autotile_road_over_dirt.png，33 块）

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
| (0,4) | 石砖路（补丁填充） | `road_stone` | 否 | 补丁格的平铺块 |

## autotile_rocky_over_dirt（res://maps/godot/tilesets/atlas/dark48_autotile_rocky_over_dirt.png，33 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | 自动拼接 rocky_over_dirt：四邻都（v1） | `edge_rocky_over_dirt_none_v1` | 否 | 底材=dirt；掩码 none(0) |
| (1,0) | 自动拼接 rocky_over_dirt：四邻都（v2） | `edge_rocky_over_dirt_none_v2` | 否 | 底材=dirt；掩码 none(0) |
| (2,0) | 自动拼接 rocky_over_dirt：北（v1） | `edge_rocky_over_dirt_n_v1` | 否 | 底材=dirt；掩码 n(1) |
| (3,0) | 自动拼接 rocky_over_dirt：北（v2） | `edge_rocky_over_dirt_n_v2` | 否 | 底材=dirt；掩码 n(1) |
| (4,0) | 自动拼接 rocky_over_dirt：东（v1） | `edge_rocky_over_dirt_e_v1` | 否 | 底材=dirt；掩码 e(2) |
| (5,0) | 自动拼接 rocky_over_dirt：东（v2） | `edge_rocky_over_dirt_e_v2` | 否 | 底材=dirt；掩码 e(2) |
| (6,0) | 自动拼接 rocky_over_dirt：北、东（v1） | `edge_rocky_over_dirt_ne_v1` | 否 | 底材=dirt；掩码 ne(3) |
| (7,0) | 自动拼接 rocky_over_dirt：北、东（v2） | `edge_rocky_over_dirt_ne_v2` | 否 | 底材=dirt；掩码 ne(3) |
| (0,1) | 自动拼接 rocky_over_dirt：南（v1） | `edge_rocky_over_dirt_s_v1` | 否 | 底材=dirt；掩码 s(4) |
| (1,1) | 自动拼接 rocky_over_dirt：南（v2） | `edge_rocky_over_dirt_s_v2` | 否 | 底材=dirt；掩码 s(4) |
| (2,1) | 自动拼接 rocky_over_dirt：北、南（v1） | `edge_rocky_over_dirt_ns_v1` | 否 | 底材=dirt；掩码 ns(5) |
| (3,1) | 自动拼接 rocky_over_dirt：北、南（v2） | `edge_rocky_over_dirt_ns_v2` | 否 | 底材=dirt；掩码 ns(5) |
| (4,1) | 自动拼接 rocky_over_dirt：东、南（v1） | `edge_rocky_over_dirt_es_v1` | 否 | 底材=dirt；掩码 es(6) |
| (5,1) | 自动拼接 rocky_over_dirt：东、南（v2） | `edge_rocky_over_dirt_es_v2` | 否 | 底材=dirt；掩码 es(6) |
| (6,1) | 自动拼接 rocky_over_dirt：北、东、南（v1） | `edge_rocky_over_dirt_nes_v1` | 否 | 底材=dirt；掩码 nes(7) |
| (7,1) | 自动拼接 rocky_over_dirt：北、东、南（v2） | `edge_rocky_over_dirt_nes_v2` | 否 | 底材=dirt；掩码 nes(7) |
| (0,2) | 自动拼接 rocky_over_dirt：西（v1） | `edge_rocky_over_dirt_w_v1` | 否 | 底材=dirt；掩码 w(8) |
| (1,2) | 自动拼接 rocky_over_dirt：西（v2） | `edge_rocky_over_dirt_w_v2` | 否 | 底材=dirt；掩码 w(8) |
| (2,2) | 自动拼接 rocky_over_dirt：北、西（v1） | `edge_rocky_over_dirt_nw_v1` | 否 | 底材=dirt；掩码 nw(9) |
| (3,2) | 自动拼接 rocky_over_dirt：北、西（v2） | `edge_rocky_over_dirt_nw_v2` | 否 | 底材=dirt；掩码 nw(9) |
| (4,2) | 自动拼接 rocky_over_dirt：东、西（v1） | `edge_rocky_over_dirt_ew_v1` | 否 | 底材=dirt；掩码 ew(10) |
| (5,2) | 自动拼接 rocky_over_dirt：东、西（v2） | `edge_rocky_over_dirt_ew_v2` | 否 | 底材=dirt；掩码 ew(10) |
| (6,2) | 自动拼接 rocky_over_dirt：北、东、西（v1） | `edge_rocky_over_dirt_new_v1` | 否 | 底材=dirt；掩码 new(11) |
| (7,2) | 自动拼接 rocky_over_dirt：北、东、西（v2） | `edge_rocky_over_dirt_new_v2` | 否 | 底材=dirt；掩码 new(11) |
| (0,3) | 自动拼接 rocky_over_dirt：南、西（v1） | `edge_rocky_over_dirt_sw_v1` | 否 | 底材=dirt；掩码 sw(12) |
| (1,3) | 自动拼接 rocky_over_dirt：南、西（v2） | `edge_rocky_over_dirt_sw_v2` | 否 | 底材=dirt；掩码 sw(12) |
| (2,3) | 自动拼接 rocky_over_dirt：北、南、西（v1） | `edge_rocky_over_dirt_nsw_v1` | 否 | 底材=dirt；掩码 nsw(13) |
| (3,3) | 自动拼接 rocky_over_dirt：北、南、西（v2） | `edge_rocky_over_dirt_nsw_v2` | 否 | 底材=dirt；掩码 nsw(13) |
| (4,3) | 自动拼接 rocky_over_dirt：东、南、西（v1） | `edge_rocky_over_dirt_esw_v1` | 否 | 底材=dirt；掩码 esw(14) |
| (5,3) | 自动拼接 rocky_over_dirt：东、南、西（v2） | `edge_rocky_over_dirt_esw_v2` | 否 | 底材=dirt；掩码 esw(14) |
| (6,3) | 自动拼接 rocky_over_dirt：北、东、南、西（v1） | `edge_rocky_over_dirt_nesw_v1` | 否 | 底材=dirt；掩码 nesw(15) |
| (7,3) | 自动拼接 rocky_over_dirt：北、东、南、西（v2） | `edge_rocky_over_dirt_nesw_v2` | 否 | 底材=dirt；掩码 nesw(15) |
| (0,4) | 碎石泥地（补丁填充） | `dirt_rocky` | 否 | 补丁格的平铺块 |

## props48（res://maps/godot/tilesets/atlas/dark48_props48.png，2 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | 枯树（1 格，带接地阴影） | `dead_tree` | 是 |  |
| (1,0) | 岩石（1 格，可通行=否） | `rock` | 是 |  |

## props96（res://maps/godot/tilesets/atlas/dark48_props96.png，2 块）

| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |
| --- | --- | --- | --- | --- |
| (0,0) | 大树（2×2 格） | `big_tree` | 是 |  |
| (2,0) | 立石（2×2 格） | `boulder` | 是 |  |

## 追加新图块 / 新素材

1. 新素材按 `docs/art/style_guide.md` 的规格生产（尺寸、色板、视角、命名），放进 `assets/`。
2. 在 `dark48.spec.json` 里追加条目（单张 PNG 会自动打包进图集）。
3. 重跑本工具（新素材要先 `--import` 导入一次）。
4. 缺什么素材按 `docs/art/asset_request.md` 提需求。

