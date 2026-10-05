extends SceneTree
const BASE := "res://assets/maps/leyton/urban_rework_v1/"
func own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own(child,owner_node)
func _initialize() -> void:
	for name_text: String in ["stone_house","timber_house"]:
		var cells := 8 if name_text=="stone_house" else 6
		var node := Node2D.new()
		node.name = name_text.to_pascal_case()
		node.set_script(load("res://core/world/map_pattern_instance.gd"))
		node.pattern_id = name_text
		node.footprint_cells = Vector2i(cells,cells)
		node.anchor_cell = Vector2i(cells/2,cells)
		node.set_meta("category","building_pattern")
		node.set_meta("projection_id","orthogonal_3q_48_v1")
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var visual := Sprite2D.new()
		visual.name = "Visual"
		visual.texture = load(BASE+name_text+".png")
		visual.centered = false
		visual.position = Vector2(-cells*24,-visual.texture.get_height())
		node.add_child(visual)
		var body := StaticBody2D.new()
		body.name = "Collision"
		body.collision_layer = 2
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(cells,cells)*48
		shape.shape = box
		shape.position = Vector2(0,-cells*24)
		body.add_child(shape)
		node.add_child(body)
		var entrances := Node2D.new()
		entrances.name = "Entrances"
		var door := Marker2D.new()
		door.name = "door_main"
		entrances.add_child(door)
		node.add_child(entrances)
		own(node,node)
		var packed := PackedScene.new()
		assert(packed.pack(node)==OK)
		assert(ResourceSaver.save(packed,BASE+name_text+".tscn")==OK)
		node.free()
	var tiles: TileSet = load("res://maps/godot/tilesets/leyton_surface_v2.tres").duplicate()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(BASE+"urban_pavers.png")
	atlas.texture_region_size = Vector2i(48,48)
	tiles.add_source(atlas,1002)
	atlas.create_tile(Vector2i.ZERO)
	atlas.get_tile_data(Vector2i.ZERO,0).set_custom_data("tag","urban_pavers")
	atlas.get_tile_data(Vector2i.ZERO,0).modulate = Color(0.70,0.70,0.70,1)
	var road := TileSetAtlasSource.new()
	road.texture = atlas.texture
	road.texture_region_size = Vector2i(48,48)
	tiles.add_source(road,1003)
	road.create_tile(Vector2i.ZERO)
	road.get_tile_data(Vector2i.ZERO,0).set_custom_data("tag","urban_road")
	var meta: Dictionary = tiles.get_meta("pipeline").duplicate(true)
	meta.materials.urban_pavers = {"source":1002,"cell":Vector2i.ZERO}
	meta.materials.urban_road = {"source":1003,"cell":Vector2i.ZERO}
	tiles.set_meta("pipeline",meta)
	assert(ResourceSaver.save(tiles,"res://maps/godot/tilesets/urban_rework_v1.tres")==OK)
	print("URBAN_REGISTER patterns=2 tileset=1")
	quit()
