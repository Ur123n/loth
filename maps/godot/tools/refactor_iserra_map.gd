extends SceneTree
## Rebuild environment around the current complete monastery, preserving its asset and markers.
const OUTPUT := "res://maps/godot/scenes/iserra_monastery_highlands.tscn"
const STAGED := "res://maps/godot/scenes/iserra_monastery_highlands.staged.tscn"
const Placer := preload("res://maps/godot/tools/map_object_placer.gd")
const Palette := preload("res://maps/godot/tools/map_palette.gd")
const BUILDING_RECT := Rect2i(18,12,48,58)
var prop_count := 0
func _initialize() -> void: call_deferred("run")
func own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own(child,owner_node)
func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
func tree_prop(map: Node2D, palette: RefCounted, tag: String, cell: Vector2i) -> void:
	var entry: Dictionary = palette.tiles[tag]
	var source: TileSetAtlasSource = palette.tile_set.get_source(entry.source)
	var texture := AtlasTexture.new()
	texture.atlas = source.texture
	texture.region = source.get_tile_texture_region(entry.cell)
	var node := Node2D.new()
	node.name = "LandscapeProp%d" % prop_count
	node.set_script(load("res://core/world/free_prop.gd"))
	node.prop_id = tag
	node.set_meta("category","free_prop")
	var span: Vector2i = source.get_tile_size_in_atlas(entry.cell)
	node.footprint_cells = span
	node.position = Vector2(cell.x+span.x*0.5,cell.y+span.y)*48
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = texture
	visual.centered = false
	visual.position = Vector2(-texture.get_width()*0.5,-texture.get_height())
	if tag in ["big_tree", "dead_tree"]:
		visual.scale = Vector2(2,2)
		visual.position *= 2
	node.add_child(visual)
	var body := StaticBody2D.new()
	body.name = "Collision"
	body.collision_layer = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(span)*48
	collision.shape = shape
	collision.position = Vector2(0,-span.y*24)
	body.add_child(collision)
	node.add_child(body)
	map.get_building_root().add_child(node)
	node.owner = map
	own(node,map)
	Placer.stamp_collision(map,[cell.x,cell.y,span.x,span.y])
	prop_count += 1
func run() -> void:
	var map: Node2D = load(OUTPUT).instantiate()
	root.add_child(map)
	assert(map.get_buildings().size()==1,"Current complete monastery required")
	var building: Node2D = map.get_buildings()[0]
	var original_position := building.position
	for child in map.get_building_root().get_children():
		if child != building: child.free()
	for name_text in ["Gameplay","Navigation"]:
		var old := map.get_node_or_null(NodePath(name_text))
		if old != null: old.free()
	var tiles: TileSet = load("res://maps/godot/tilesets/urban_rework_v1.tres")
	var palette := Palette.new()
	assert(palette.setup(tiles))
	for layer_name: String in map.LAYERS:
		var layer: TileMapLayer = map.get_layer(layer_name)
		layer.clear()
		layer.tile_set = tiles
		layer.z_index = -1
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var terrain: TileMapLayer = map.get_layer("地形")
	for y in 88:
		for x in 84:
			var cell := Vector2i(x,y)
			var point := Vector2(cell)+Vector2(0.5,0.5)
			var material := "grass"
			if BUILDING_RECT.grow(4).has_point(cell): material = "dirt"
			if BUILDING_RECT.has_point(cell): material = "grass"
			if BUILDING_RECT.has_point(cell) and building.judge_map_cell(cell): material = "urban_pavers"
			if Rect2i(30,70,30,11).has_point(cell): material = "urban_pavers"
			if Rect2i(3,54,11,24).has_point(cell) or Rect2i(69,53,12,24).has_point(cell): material = "dirt"
			var paths := [[Vector2(42,68),Vector2(42,74)],[Vector2(42,74),Vector2(45,79)],[Vector2(45,79),Vector2(45,88)]]
			for edge: Array in paths:
				if segment_distance(point,edge[0],edge[1])<=3.0: material = "urban_road"
			for edge: Array in [[Vector2(12,74),Vector2(12,6)],[Vector2(12,6),Vector2(72,6)],[Vector2(72,6),Vector2(72,75)],[Vector2(12,74),Vector2(42,74)],[Vector2(45,76),Vector2(72,75)]]:
				if segment_distance(point,edge[0],edge[1])<=1.5: material = "dirt"
			palette.set_material(terrain,cell,material)
	palette.apply_autotile(terrain)
	map.get_building_root().y_sort_enabled = true
	map.get_building_root().z_index = 0
	map.get_building_root().set_meta("role","shared_y_sort_buildings_props_entities")
	var old_palette := Palette.new()
	assert(old_palette.setup(load("res://maps/godot/tilesets/dark48.tres")))
	# Independent landscape props, away from all services and road approaches.
	for y in range(3,84,7):
		for x in [3,79]:
			if y>=52 and y<=78: continue
			tree_prop(map,old_palette,"big_tree",Vector2i(x,y))
	for x in range(18,70,7): tree_prop(map,old_palette,"big_tree",Vector2i(x,2))
	for point: Vector2i in [Vector2i(8,44),Vector2i(75,42),Vector2i(5,80),Vector2i(74,81)]:
		tree_prop(map,old_palette,"boulder",point)
	for entry: Dictionary in [{"pattern":"timber_house","label":"修院柴房与工棚","rect":[3,56,7,7]},{"pattern":"stone_house","label":"旅客救济与物资房","rect":[74,60,7,7]}]:
		var node := Placer.add_pattern(map,entry)
		node.owner = map
		Placer.stamp_collision(map,entry.rect)
	var props := [{"id":"crate","cell":[5,66]},{"id":"barrel","cell":[7,66]},{"id":"grain_sacks","cell":[5,70]},{"id":"handcart","cell":[8,73]},{"id":"notice_board","cell":[34,77]},{"id":"coal_basket","cell":[76,70]},{"id":"crate","cell":[78,70]},{"id":"barrel","cell":[76,56]},{"id":"grain_sacks","cell":[78,56]},{"id":"notice_board","cell":[55,77]}]
	for entry: Dictionary in props:
		entry.scene = "res://assets/maps/leyton/props_batch_01/scenes/%s.tscn" % entry.id
		var node := Placer.add_prop(map,entry)
		node.owner = map
		Placer.stamp_collision(map,[entry.cell[0],entry.cell[1]-1,1,2])
		prop_count += 1
	for name_text: String in ["Gameplay","Navigation"]:
		var node := Node2D.new()
		node.name = name_text
		node.set_meta("role","marker_driven_gameplay" if name_text=="Gameplay" else "MapScene_walkability_query")
		map.add_child(node)
		node.owner = map
	map.set_meta("environment_revision","urban_rework_v1")
	map.set_meta("generated_by","maps/godot/tools/refactor_iserra_map.gd")
	assert(building.position==original_position)
	assert(map.validate().is_empty())
	assert(map.validate_spawn_walkable().is_empty())
	assert(map.validate_buildings().is_empty())
	var packed := PackedScene.new()
	assert(packed.pack(map)==OK)
	assert(ResourceSaver.save(packed,STAGED)==OK)
	var probe: Node2D = load(STAGED).instantiate()
	assert(probe.get_buildings().size()==1 and probe.get_all_marker_ids().size()==map.get_all_marker_ids().size())
	probe.free()
	assert(DirAccess.rename_absolute(ProjectSettings.globalize_path(STAGED),ProjectSettings.globalize_path(OUTPUT))==OK)
	var report := FileAccess.open("res://maps/leyton/rework_v2/qa/monastery.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"props":prop_count,"patterns":2,"large_buildings":1,"markers":map.get_all_marker_ids(),"validation_errors":0},"\t")+"\n")
	print("MONASTERY_REWORK props=",prop_count," patterns=2 building=1 errors=0")
	map.free()
	quit()
