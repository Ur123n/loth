extends SceneTree

## 管线第 2 步：地图场景脚手架 / 示例地图
##
## 用法：
##   godot --headless --path C:\游戏 --script maps/godot/tools/make_map.gd
##       → 当前规格（48px 黑暗奇幻）：scenes/dark48_map_template.tscn（空白模板 26×15）
##         + scenes/abbey_outskirts.tscn（示例地图「修道院外的荒院」，材质配比按标定表铺）
##   … -- --name my_place --size 40x30 [--tileset <res://….tres>] [--scale 1.0]
##                                → 只生成 scenes/my_place.tscn（新地点的空白脚手架）
##
## 场景结构（约定见 core/world/map_scene.gd 与 docs/world/map_pipeline.md）：
##   地图(Node2D + map_scene.gd)
##   ├── 地形 / 高差 / 建筑 / 装饰 / 植被 / 碰撞（TileMapLayer，共用同一个 TileSet）
##   └── 标记（Node2D）→ Marker2D：spawn / gate / battle_trigger / story_trigger / …
##
## 刷图只认 TileSet 里的语义（`tag` 自定义数据 + `pipeline` 元数据），不写死图块坐标：
## 换素材、改 spec 后重跑第 1 步 build_tileset.gd，这里的刷图结果会自动跟着变。

const SCENE_DIR := "res://maps/godot/scenes"
const MAP_SCENE_SCRIPT := "res://core/world/map_scene.gd"
## 用 preload 而非全局类名：类名缓存要开过编辑器才刷新，工具必须能独立跑。
const MapSceneScript := preload(MAP_SCENE_SCRIPT)
const MapPalette := preload("res://maps/godot/tools/map_palette.gd")

# ---- 当前规格：48px 黑暗奇幻（1 格 = 1 米，1:1 显示）----
const DARK48_TILESET := "res://maps/godot/tilesets/dark48.tres"
const DARK48_TEMPLATE := "dark48_map_template"
const DARK48_DEMO := "abbey_outskirts"
const DARK48_SIZE := Vector2i(26, 15)      # 1280×720 视口下 1:1 正好一屏
const DARK48_SCALE := 1.0

# ---- 48px 示例地图「修道院外的荒院」布局（格坐标，y 向下；优先级：砖路 > 碎石 > 泥土 > 枯草 > 草地）----
const D_ROAD_PLAZA := Rect2i(10, 3, 5, 3)      # 北侧石砖小广场
const D_ROAD_PATH := Rect2i(11, 6, 2, 9)       # 南向石砖路（2 格宽）
const D_GRAVEL_A := Rect2i(15, 8, 4, 4)        # 碎石（在泥土带里）
const D_GRAVEL_B := Rect2i(16, 12, 3, 2)
const D_DIRT_WEST := Rect2i(9, 5, 2, 10)       # 路面西侧泥土带
const D_DIRT_EAST := Rect2i(13, 5, 3, 10)      # 路面东侧泥土带
const D_DIRT_NORTH := Rect2i(11, 2, 6, 1)      # 广场北侧泥土
const D_DRY_A := Rect2i(0, 10, 6, 5)           # 枯草斑块（西）
const D_DRY_B := Rect2i(18, 0, 5, 3)           # 枯草斑块（北）
const D_DRY_C := Rect2i(20, 11, 6, 4)          # 枯草斑块（东南）
const D_DRY_D := Rect2i(2, 2, 4, 3)            # 枯草斑块（西北）

# ---- 48px 示例地图的道具与标记 ----
const D_PROPS := [
	{"tag": "dead_tree", "cell": Vector2i(3, 3)},
	{"tag": "dead_tree", "cell": Vector2i(6, 7)},
	{"tag": "dead_tree", "cell": Vector2i(21, 3)},
	{"tag": "dead_tree", "cell": Vector2i(23, 7)},
	{"tag": "dead_tree", "cell": Vector2i(2, 12)},
	{"tag": "dead_tree", "cell": Vector2i(24, 13)},
	{"tag": "dead_tree", "cell": Vector2i(7, 13)},
	{"tag": "dead_tree", "cell": Vector2i(19, 2)},
	{"tag": "rock", "cell": Vector2i(5, 1)},
	{"tag": "rock", "cell": Vector2i(17, 5)},
	{"tag": "rock", "cell": Vector2i(21, 9)},
	{"tag": "rock", "cell": Vector2i(8, 11)},
	{"tag": "rock", "cell": Vector2i(25, 5)},
	{"tag": "big_tree", "cell": Vector2i(0, 5)},
	{"tag": "big_tree", "cell": Vector2i(23, 0)},
	{"tag": "boulder", "cell": Vector2i(17, 12)},
]
const D_MARKERS := {
	"spawn": Vector2i(11, 13),
	"gate": Vector2i(12, 3),
	"church": Vector2i(11, 1),
	"bell_tower": Vector2i(14, 1),
	"kitchen_garden": Vector2i(9, 8),
	"herb_garden": Vector2i(15, 6),
	"battle_trigger": Vector2i(20, 13),
	"skill_light": Vector2i(12, 4),
	"story_trigger": Vector2i(12, 9),
}
## 铺图配比标定表（来自美术线规范）：草 60 / 枯草 15 / 泥土 12 / 碎石 6 / 石砖路 7
const D_RATIO_TARGET := {"grass": 0.60, "grass_dry": 0.15, "dirt": 0.12, "dirt_rocky": 0.06, "road_stone": 0.07}

var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var args := _parse_args()
	if args.has("name"):
		var tileset_path := String(args.get("tileset", DARK48_TILESET))
		_build_template(String(args["name"]), _parse_size(String(args.get("size", "26x15"))), tileset_path,
			float(args.get("scale", DARK48_SCALE)))
	else:
		_build_template(DARK48_TEMPLATE, DARK48_SIZE, DARK48_TILESET, DARK48_SCALE)
		_build_dark48_demo()
	print("RESULT: failed=%d" % _failed)
	quit(0 if _failed == 0 else 1)
	return true


func _fail(msg: String) -> void:
	_failed += 1
	print("FAIL  ", msg)


func _parse_args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		var arg := argv[i]
		if arg.begins_with("--") and i + 1 < argv.size():
			out[arg.trim_prefix("--")] = argv[i + 1]
			i += 2
			continue
		out["_flag" + str(i)] = arg
		i += 1
	return out


func _parse_size(text: String) -> Vector2i:
	var parts := text.split("x")
	if parts.size() != 2:
		return DARK48_SIZE
	return Vector2i(maxi(1, int(parts[0])), maxi(1, int(parts[1])))


# ---------------------------------------------------------------- 场景骨架

func _build_template(map_name: String, cells: Vector2i, tileset_path: String, display_scale: float) -> void:
	var tile_set := load(tileset_path) as TileSet
	if tile_set == null:
		_fail("TileSet 加载失败：%s（先跑第 1 步 build_tileset.gd）" % tileset_path)
		return
	var root := _new_map(map_name, cells, tile_set, display_scale)
	if root == null:
		return
	_place_markers(root, _placeholder_marker_cells(cells))
	_save_map(root, SCENE_DIR.path_join(map_name + ".tscn"))


## 建地图骨架：根节点挂 map_scene.gd + 六个图块层 + 标记容器（标记由调用方摆）。
func _new_map(map_name: String, cells: Vector2i, tile_set: TileSet, display_scale: float = 1.0) -> Node2D:
	var root := Node2D.new()
	root.name = map_name
	root.set_script(load(MAP_SCENE_SCRIPT))
	root.set("map_size_cells", cells)
	root.set("display_scale", display_scale)
	for layer_name in MapSceneScript.LAYERS:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tile_set
		layer.y_sort_enabled = false
		root.add_child(layer)
		layer.owner = root
		if layer_name == MapSceneScript.LAYER_COLLISION:
			layer.visible = false   # 只存数据，不在游戏里显示
	var markers := Node2D.new()
	markers.name = MapSceneScript.MARKER_ROOT
	root.add_child(markers)
	markers.owner = root
	return root


## 摆标记：id → 格坐标（转成格中心像素）。
func _place_markers(root: Node2D, cells: Dictionary) -> void:
	var markers := root.get_node_or_null(NodePath(MapSceneScript.MARKER_ROOT))
	var tile_size := _tile_size(root)
	for marker_id in cells:
		var marker := Marker2D.new()
		marker.name = String(marker_id)
		marker.position = (Vector2(cells[marker_id]) + Vector2(0.5, 0.5)) * Vector2(tile_size)
		markers.add_child(marker)
		marker.owner = root


# ---------------------------------------------------------------- 48px 示例地图

func _build_dark48_demo() -> void:
	var tile_set := load(DARK48_TILESET) as TileSet
	if tile_set == null:
		_fail("48px 示例地图的 TileSet 加载失败：%s（先跑第 1 步 build_tileset.gd）" % DARK48_TILESET)
		return
	var palette = MapPalette.new()
	if not palette.setup(tile_set):
		_fail("TileSet 缺少 pipeline 元数据（重跑第 1 步 build_tileset.gd）")
		return
	var root := _new_map(DARK48_DEMO, DARK48_SIZE, tile_set, DARK48_SCALE)
	if root == null:
		return
	root.set_meta("generated_by", "maps/godot/tools/make_map.gd（48px 示例地图；材质配比按美术线标定表）")
	_paint_materials(root, palette)
	_place_props(root, palette)
	_place_markers(root, D_MARKERS)
	_save_map(root, SCENE_DIR.path_join(DARK48_DEMO + ".tscn"))


## 铺材质（草地底 + 枯草斑块 + 泥土带 + 碎石 + 石砖路），再按四邻重算边缘块。
func _paint_materials(root: Node2D, palette) -> void:
	var terrain := _layer(root, MapSceneScript.LAYER_TERRAIN)
	var cells: Vector2i = root.get("map_size_cells")
	var materials := {}
	for y in cells.y:
		for x in cells.x:
			materials[Vector2i(x, y)] = "grass"
	_fill(materials, D_DRY_A, "grass_dry", 0.72)
	_fill(materials, D_DRY_B, "grass_dry", 0.72)
	_fill(materials, D_DRY_C, "grass_dry", 0.68)
	_fill(materials, D_DRY_D, "grass_dry", 0.66)
	_fill(materials, D_DIRT_WEST, "dirt", 1.0)
	_fill(materials, D_DIRT_EAST, "dirt", 1.0)
	_fill(materials, D_DIRT_NORTH, "dirt", 1.0)
	_fill(materials, D_GRAVEL_A, "dirt_rocky", 1.0)
	_fill(materials, D_GRAVEL_B, "dirt_rocky", 1.0)
	_fill(materials, D_ROAD_PLAZA, "road_stone", 1.0)
	_fill(materials, D_ROAD_PATH, "road_stone", 1.0)
	for cell in materials:
		palette.set_material(terrain, cell, String(materials[cell]))
	var report: Dictionary = palette.apply_autotile(terrain)
	_report_ratio(report.get("counts", {}), cells.x * cells.y)
	for conflict in report.get("conflicts", []):
		_fail("自动拼接冲突：%s" % conflict)


## 按矩形铺材质；keep < 1 时用确定性噪声打散边缘（避免呆板的矩形斑块）。
func _fill(materials: Dictionary, rect: Rect2i, tag: String, keep: float) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not materials.has(cell):
				continue
			if keep < 1.0 and _noise01(cell) > keep:
				continue
			materials[cell] = tag


## 确定性噪声（同一格永远同一值，重跑结果一致）。
func _noise01(cell: Vector2i) -> float:
	var value := absi(cell.x * 92837111 + cell.y * 689287499 + cell.x * cell.y * 283923481)
	return float(value % 10000) / 10000.0


## 铺道具（枯树/岩石/大树/立石）：图块自带 solid，阻挡效果由 MapScene 判定。
func _place_props(root: Node2D, palette) -> void:
	var vegetation := _layer(root, MapSceneScript.LAYER_VEGETATION)
	var decor := _layer(root, MapSceneScript.LAYER_DECOR)
	for entry in D_PROPS:
		var e: Dictionary = entry
		var layer := vegetation if String(e["tag"]).contains("tree") else decor
		if not palette.set_material(layer, e["cell"], String(e["tag"])):
			_fail("道具 tag 在 TileSet 里不存在：%s" % String(e["tag"]))


## 打印材质配比（对照美术线标定表：草 60 / 枯草 15 / 泥土 12 / 碎石 6 / 石砖路 7）。
func _report_ratio(counts: Dictionary, total: int) -> void:
	var parts := PackedStringArray()
	for tag in D_RATIO_TARGET:
		var actual := float(counts.get(tag, 0)) / float(maxi(1, total))
		parts.append("%s %.1f%%（目标 %.0f%%）" % [tag, actual * 100.0, float(D_RATIO_TARGET[tag]) * 100.0])
	print("RATIO ", ", ".join(parts))


func _save_map(root: Node2D, path: String) -> void:
	if DirAccess.open(SCENE_DIR) == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		_fail("打包场景失败：%s err=%d" % [path, pack_err])
		root.free()
		return
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		_fail("保存场景失败：%s err=%d" % [path, err])
	else:
		print("WROTE ", path)
	root.free()


func _tile_size(root: Node2D) -> Vector2i:
	var terrain := root.get_node_or_null(NodePath(MapSceneScript.LAYER_TERRAIN)) as TileMapLayer
	if terrain != null and terrain.tile_set != null:
		return terrain.tile_set.tile_size
	return Vector2i(48, 48)


# ---------------------------------------------------------------- 刷图

func _layer(root: Node2D, layer_name: String) -> TileMapLayer:
	return root.get_node_or_null(NodePath(layer_name)) as TileMapLayer


## 空白模板/新地图的标记占位（贴着地图右下角夹一下，避免小地图上摆到界外）。
func _placeholder_marker_cells(cells: Vector2i) -> Dictionary:
	var out := {}
	for marker_id in D_MARKERS:
		var cell: Vector2i = D_MARKERS[marker_id]
		out[marker_id] = Vector2i(clampi(cell.x, 0, cells.x - 1), clampi(cell.y, 0, cells.y - 1))
	return out
