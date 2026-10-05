extends "res://core/world/map_scene.gd"
## Data-driven acceptance map; buildings are footprint placeholders, not art tiles.

@export var map_id := "M01"
@export var use_surface := true
const PaletteScript := preload("res://maps/godot/tools/map_palette.gd")
const SURFACE_PATH := "res://maps/godot/tilesets/leyton_surface_v2.tres"
const MATERIALS := {0: "grass", 1: "road_stone", 2: "water_deep", 4: "wall_top", 5: "road_stone"}
var palette: RefCounted
var surface_qa: Dictionary = {}
var layout: Dictionary
var gate_state := 0
var cells: Dictionary = {}
const COLORS := [Color("65725b"), Color("b39b70"), Color("35576c"), Color("59616d"), Color("29494b"), Color("c4ae80"), Color("6f8186")]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/leyton/slice.json"))
	for entry: Dictionary in document.maps:
		if entry.map_id == map_id:
			layout = entry
	assert(not layout.is_empty(), "Unknown Leyton map")
	map_size_cells = Vector2i(int(layout.size[0]), int(layout.size[1]))
	var tiles := _make_tiles()
	for layer_name in LAYERS:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tiles
		add_child(layer)
	var markers := Node2D.new()
	markers.name = MARKER_ROOT
	add_child(markers)
	var spawn := Marker2D.new()
	spawn.name = "spawn"
	spawn.position = cell_to_local(Vector2i(layout.spawn[0], layout.spawn[1]))
	markers.add_child(spawn)
	_build()
	_load_structures()
	super._ready()

func _load_structures() -> void:
	# Complete structures use the existing Building contract, independently of terrain art.
	var structures := Node2D.new()
	structures.name = BUILDING_ROOT
	structures.y_sort_enabled = true
	add_child(structures)
	for entry: Dictionary in layout.structures:
		var prefab := String(entry.get("prefab", ""))
		if prefab.is_empty():
			continue
		var packed := load(prefab) as PackedScene
		assert(packed != null, "Missing Leyton structure: " + prefab)
		var instance := packed.instantiate()
		var origin := rect(entry.rect).position
		var data = instance.get_building_data()
		assert(data.get_footprint_size() == rect(entry.rect).size, "Structure footprint mismatch")
		instance.position = data.top_left_cell_to_node_position(origin)
		instance.set_placement_cell(origin)
		structures.add_child(instance)

func _make_tiles() -> TileSet:
	var image := Image.create(48 * COLORS.size(), 48, false, Image.FORMAT_RGBA8)
	for i in COLORS.size():
		image.fill_rect(Rect2i(i * 48, 0, 48, 48), COLORS[i])
		image.fill_rect(Rect2i(i * 48, 0, 48, 1), COLORS[i].darkened(0.14))
		image.fill_rect(Rect2i(i * 48, 0, 1, 48), COLORS[i].darkened(0.14))
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(48, 48)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(48, 48)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "solid")
	tiles.set_custom_data_layer_type(0, TYPE_BOOL)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(1, "tag")
	tiles.set_custom_data_layer_type(1, TYPE_STRING)
	# The gray source remains available for footprint placeholders and collision data.
	tiles.add_source(atlas, 1000)
	for i in COLORS.size():
		atlas.create_tile(Vector2i(i, 0))
		atlas.get_tile_data(Vector2i(i, 0), 0).set_custom_data("tag", "graybox_%d" % i)
	if use_surface:
		var surface := load(SURFACE_PATH) as TileSet
		assert(surface != null, "Missing Leyton surface TileSet")
		var result := surface.duplicate() as TileSet
		result.add_source(atlas, 1000)
		palette = PaletteScript.new()
		assert(palette.setup(result), "Invalid Leyton surface metadata")
		return result
	return tiles

func set_surface_enabled(enabled: bool) -> void:
	use_surface = enabled
	var tiles := _make_tiles()
	for layer_name in LAYERS:
		get_layer(layer_name).clear()
		get_layer(layer_name).tile_set = tiles
	cells.clear()
	_build()

func rect(values: Array) -> Rect2i:
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))

func _paint(area: Rect2i, tile: int, blocked: bool) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not is_cell_inside(cell):
				continue
			if use_surface and MATERIALS.has(tile):
				palette.set_material(get_layer(LAYER_TERRAIN), cell, MATERIALS[tile])
			else:
				get_layer(LAYER_TERRAIN).set_cell(cell, 1000, Vector2i(tile, 0))
			cells[cell] = tile
			if blocked:
				get_layer(LAYER_COLLISION).set_cell(cell, 1000, Vector2i(tile, 0))
			else:
				get_layer(LAYER_COLLISION).erase_cell(cell)

func _build() -> void:
	_paint(Rect2i(Vector2i.ZERO, map_size_cells), 0, false)
	for zone: Dictionary in layout.get("zones", []):
		if zone.kind == "plaza":
			_paint(rect(zone.rect), 1, false)
		if zone.kind != "lake":
			continue
		var bounds := rect(zone.rect)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var point := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(bounds.get_center())) / (Vector2(bounds.size) * 0.5)
				if point.length_squared() <= 1.0:
					_paint(Rect2i(x, y, 1, 1), 2, true)
	for road: Dictionary in layout.roads:
		_paint(rect(road.rect), 1, false)
	for water: Dictionary in layout.get("water", []):
		for y in map_size_cells.y:
			for x in map_size_cells.x:
				var point := Vector2(x + 0.5, y + 0.5)
				for i in range(water.points.size() - 1):
					var a := Vector2(water.points[i][0], water.points[i][1])
					var b := Vector2(water.points[i + 1][0], water.points[i + 1][1])
					if point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) <= float(water.width) / 2.0:
						_paint(Rect2i(x, y, 1, 1), 2, true)
	for wall: Dictionary in layout.get("walls", []):
		_paint(rect(wall.rect), 4, true)
	for building: Dictionary in layout.structures:
		if building.kind == "bridge":
			continue
		var permeable: bool = building.kind in ["checkpoint", "caravan"]
		_paint(rect(building.rect), 6 if permeable else 3, not permeable)
	for bridge: Array in layout.bridges:
		_paint(rect(bridge), 5, false)
	if not layout.wall_walk.is_empty():
		_paint(rect(layout.wall_walk), 4, true)
	set_gate_state(gate_state)
	# Block unfinished district exits; they are clearly marked in the viewer.
	for ex: Dictionary in layout.exits:
		if not ex.enabled:
			_paint(exit_rect(ex), 4, true)
	if use_surface:
		_apply_surface_edges()

func _apply_surface_edges() -> void:
	var terrain := get_layer(LAYER_TERRAIN)
	# A two-cell dirt verge keeps road-over-dirt and dirt-over-grass transitions separate.
	for cell: Vector2i in cells:
		if cells[cell] not in [1, 5]:
			continue
		for y in range(-2, 3):
			for x in range(-2, 3):
				var neighbor := cell + Vector2i(x, y)
				if cells.get(neighbor, -1) == 0:
					palette.set_material(terrain, neighbor, "dirt")
	surface_qa = palette.apply_autotile(terrain)
	_apply_surface_details()

func _apply_surface_details() -> void:
	var terrain := get_layer(LAYER_TERRAIN)
	var materials := {}
	for cell: Vector2i in cells:
		materials[cell] = palette.material_of_cell(terrain, cell)
	var shores := 0
	var variants := 0
	for cell: Vector2i in cells:
		if cells[cell] == 2:
			var code := 0
			var factor := 1
			for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var neighbor: String = materials.get(cell + offset, "")
				var kind := 1 if neighbor == "grass" else (2 if neighbor == "dirt" else 0)
				code += kind * factor
				factor *= 3
			if code != 0:
				palette.set_material(terrain, cell, "shore_%d" % code)
				shores += 1
		elif palette.tag_of_cell(terrain, cell) in ["grass", "road_stone"]:
			var variant := absi(hash("%d,%d" % [cell.x, cell.y])) % 4
			if variant != 0:
				palette.set_material(terrain, cell, "%s_variant_%d" % [materials[cell], variant])
				variants += 1
	surface_qa["shore_cells"] = shores
	surface_qa["variant_cells"] = variants

func exit_rect(ex: Dictionary) -> Rect2i:
	match ex.edge:
		"west": return Rect2i(0, ex.offset, 2, ex.width)
		"east": return Rect2i(map_size_cells.x - 2, ex.offset, 2, ex.width)
		"north": return Rect2i(ex.offset, 0, ex.width, 2)
	return Rect2i(ex.offset, map_size_cells.y - 2, ex.width, 2)

func arrival(edge: String) -> Vector2:
	for ex: Dictionary in layout.exits:
		if ex.edge != edge:
			continue
		var middle := float(ex.offset) + float(ex.width) / 2.0
		match edge:
			"west": return Vector2(4, middle) * 48
			"east": return Vector2(map_size_cells.x - 4, middle) * 48
	return get_spawn_position()

func set_gate_state(state: int) -> void:
	gate_state = posmod(state, 3)
	if not layout.get("gate", []).is_empty():
		_paint(rect(layout.gate), 1 if gate_state == 0 else 4, gate_state != 0)

func can_occupy(center: Vector2, footprint: Vector2, on_wall := false) -> bool:
	var low := local_to_cell(center - footprint * 0.5 + Vector2(0.01, 0.01))
	var high := local_to_cell(center + footprint * 0.5 - Vector2(0.01, 0.01))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if on_wall:
				if layout.wall_walk.is_empty() or not rect(layout.wall_walk).has_point(Vector2i(x, y)):
					return false
			elif not is_cell_walkable(Vector2i(x, y)):
				return false
	return true
