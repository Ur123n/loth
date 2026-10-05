extends SceneTree

## 伊瑟拉修道院专用地图：48×48 地表与小物件 + 一座完整 Building 场景。
## 这里只铺环境 tile；修道院视觉由 iserra_monastery_highland Prefab 独立提供。

const MapSceneScript := preload("res://core/world/map_scene.gd")
const MapPalette := preload("res://maps/godot/tools/map_palette.gd")

const TILESET_PATH := "res://maps/godot/tilesets/dark48.tres"
const OUTPUT_PATH := "res://maps/godot/scenes/iserra_monastery_highlands.tscn"
const MAP_SIZE := Vector2i(84, 88)
const MONASTERY_RECT := Rect2i(18, 12, 48, 58)
const GATE := Vector2i(41, 70)

var _failed := false
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_build()
	quit(1 if _failed else 0)
	return true


func _build() -> void:
	var tile_set := load(TILESET_PATH) as TileSet
	if tile_set == null:
		_fail("TileSet 读取失败：%s" % TILESET_PATH)
		return
	var palette := MapPalette.new()
	if not palette.setup(tile_set):
		_fail("TileSet 缺少 pipeline 语义元数据")
		return

	var map := _new_map(tile_set)
	_paint_terrain(map, palette)
	_paint_props(map, palette)
	_place_markers(map)
	map.set_meta("location_id", "iserra_monastery_highlands")
	map.set_meta("region", "埃尔纳高原西南边境深山")
	map.set_meta("building_asset", "iserra_monastery_highland")
	map.set_meta("tile_grid_px", 48)
	map.set_meta("projection_id", "orthogonal_3q_48_v1")
	map.set_meta("art_direction", "深色山林包围浅灰修院；暖金只用于守焰信仰焦点")
	map.set_meta("generated_by", "maps/godot/tools/make_iserra_monastery_map.gd")

	var packed := PackedScene.new()
	var pack_error := packed.pack(map)
	if pack_error != OK:
		_fail("地图打包失败 err=%d" % pack_error)
		map.free()
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		_fail("地图保存失败 err=%d：%s" % [save_error, OUTPUT_PATH])
	else:
		print("WROTE %s（%dx%d 格，48 px/格）" % [OUTPUT_PATH, MAP_SIZE.x, MAP_SIZE.y])
	map.free()


func _new_map(tile_set: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = "IserraMonasteryHighlands"
	root.set_script(load("res://core/world/map_scene.gd"))
	root.set("map_size_cells", MAP_SIZE)
	root.set("display_scale", 1.0)
	for layer_name in MapSceneScript.LAYERS:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tile_set
		root.add_child(layer)
		layer.owner = root
		if layer_name == MapSceneScript.LAYER_COLLISION:
			layer.visible = false
	var markers := Node2D.new()
	markers.name = MapSceneScript.MARKER_ROOT
	root.add_child(markers)
	markers.owner = root
	var buildings := Node2D.new()
	buildings.name = "建筑对象"
	buildings.y_sort_enabled = true
	root.add_child(buildings)
	buildings.owner = root
	return root


func _paint_terrain(map: Node2D, palette) -> void:
	var terrain := map.get_node(MapSceneScript.LAYER_TERRAIN) as TileMapLayer
	var materials := {}
	var dirt_apron := MONASTERY_RECT.grow(4)
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var tag := "grass"
			var edge := mini(mini(x, MAP_SIZE.x - 1 - x), mini(y, MAP_SIZE.y - 1 - y))
			var n := _noise01(cell, 17)
			# 林缘裸露的高原碎石脊；主体仍保持低明度草地。
			if edge < 5 and n > 0.34:
				tag = "dirt_rocky"
			elif _ellipse(cell, Vector2i(8, 47), Vector2i(11, 22)) \
					or _ellipse(cell, Vector2i(75, 27), Vector2i(10, 18)):
				tag = "grass_dry" if n > 0.23 else "grass"
			elif _ellipse(cell, Vector2i(69, 74), Vector2i(12, 10)):
				tag = "grass_dry" if n > 0.45 else "grass"

			# 修院四周是被车轮、担架和柴车磨出的土环；建筑视觉与此逻辑无关。
			if dirt_apron.has_point(cell) and not MONASTERY_RECT.has_point(cell):
				tag = "dirt" if n > 0.18 else "dirt_rocky"
			if _road_shoulder(cell):
				tag = "dirt"
			if _road(cell):
				tag = "road_stone"
			materials[cell] = tag

	for cell in materials:
		palette.set_material(terrain, cell, String(materials[cell]))
	var report: Dictionary = palette.apply_autotile(terrain)
	print("TERRAIN counts=%s autotile_changed=%d conflicts=%d" % [
		str(report.get("counts", {})), int(report.get("changed", 0)),
		(report.get("conflicts", []) as Array).size()])


func _paint_props(map: Node2D, palette) -> void:
	var vegetation := map.get_node(MapSceneScript.LAYER_VEGETATION) as TileMapLayer
	var decor := map.get_node(MapSceneScript.LAYER_DECOR) as TileMapLayer
	var reserved := MONASTERY_RECT.grow(6)
	var placed := 0
	var occupied := {}

	# 深山森林形成暗色外框，南侧给高原驿路留出狭窄缺口。
	# 候选遍历每一格，再用散列阈值与邻距约束取样，避免出现规则种植行。
	for y in range(1, MAP_SIZE.y - 2):
		for x in range(1, MAP_SIZE.x - 2):
			var cell := Vector2i(x, y)
			var edge := mini(mini(x, MAP_SIZE.x - 2 - x), mini(y, MAP_SIZE.y - 2 - y))
			if edge > 13 or reserved.has_point(cell) or _road_shoulder(cell):
				continue
			if y > 69 and absi(x - 43) < 9:
				continue
			if _noise01(cell, 101) < 0.88 or _has_nearby(occupied, cell, 2):
				continue
			var tag := "dead_tree" if _noise01(cell, 303) > 0.84 else "big_tree"
			if palette.set_material(vegetation, cell, tag):
				occupied[cell] = true
				placed += 1

	var dead_trees := [
		Vector2i(10, 20), Vector2i(12, 65), Vector2i(70, 16), Vector2i(73, 52),
		Vector2i(8, 78), Vector2i(70, 76), Vector2i(15, 8), Vector2i(68, 8),
	]
	for cell in dead_trees:
		if palette.set_material(vegetation, cell, "dead_tree"):
			occupied[cell] = true
			placed += 1
	var boulders := [
		Vector2i(4, 8), Vector2i(78, 10), Vector2i(7, 36), Vector2i(75, 41),
		Vector2i(13, 75), Vector2i(67, 82), Vector2i(72, 62),
	]
	for cell in boulders:
		if palette.set_material(decor, cell, "boulder"):
			placed += 1
	var rocks := [
		Vector2i(15, 18), Vector2i(69, 22), Vector2i(11, 57), Vector2i(73, 67),
		Vector2i(21, 76), Vector2i(61, 79), Vector2i(37, 82),
	]
	for cell in rocks:
		if palette.set_material(decor, cell, "rock"):
			placed += 1
	print("PROPS placed=%d（仅使用 dark48 已有小物件）" % placed)


func _place_markers(map: Node2D) -> void:
	var root := map.get_node(MapSceneScript.MARKER_ROOT)
	var cells := {
		"spawn": Vector2i(45, 84),
		"gate": GATE,
		"story_trigger": Vector2i(42, 74),
		"skill_light": Vector2i(42, 72),
		"battle_trigger": Vector2i(69, 74),
		"church": Vector2i(42, 34),
		"cloister": Vector2i(42, 50),
		"bell_tower": Vector2i(24, 22),
		"hospice": Vector2i(59, 48),
		"crematory": Vector2i(62, 58),
		"herb_garden": Vector2i(69, 55),
		"highland_pass": Vector2i(45, 87),
	}
	for marker_name in cells:
		var marker := Marker2D.new()
		marker.name = String(marker_name)
		marker.position = (Vector2(cells[marker_name]) + Vector2(0.5, 0.5)) * 48.0
		root.add_child(marker)
		marker.owner = map


func _road(cell: Vector2i) -> bool:
	if cell.y < GATE.y or cell.y >= MAP_SIZE.y:
		return false
	var bend := int((cell.y - GATE.y) / 6)
	var center_x := GATE.x + 1 + bend
	return cell.x == center_x or cell.x == center_x + 1


func _road_shoulder(cell: Vector2i) -> bool:
	if cell.y < GATE.y - 2:
		return false
	var bend := maxi(0, int((cell.y - GATE.y) / 6))
	var center_x := GATE.x + 1 + bend
	return absi(cell.x - center_x) <= 3


func _ellipse(cell: Vector2i, center: Vector2i, radius: Vector2i) -> bool:
	var dx := float(cell.x - center.x) / float(radius.x)
	var dy := float(cell.y - center.y) / float(radius.y)
	return dx * dx + dy * dy <= 1.0


func _noise01(cell: Vector2i, salt: int) -> float:
	var value := cell.x * 374761393 + cell.y * 668265263 + salt * 982451653
	value = (value ^ (value >> 13)) * 1274126177
	value = value ^ (value >> 16)
	return float(value & 0x7fffffff) / 2147483647.0


func _has_nearby(occupied: Dictionary, cell: Vector2i, radius: int) -> bool:
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			if occupied.has(Vector2i(x, y)):
				return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("FAIL  ", message)
