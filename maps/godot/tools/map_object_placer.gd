extends RefCounted
## Shared placement for complete Pattern scenes and independent FreeProps.
static func add_pattern(map: Node2D, entry: Dictionary) -> Node2D:
	var instance: Node2D = load("res://assets/maps/leyton/urban_rework_v1/%s.tscn" % entry.pattern).instantiate()
	var r: Array = entry.rect
	var footprint: Vector2i = instance.get_footprint_cells()
	instance.scale = Vector2(r[2]/float(footprint.x),r[3]/float(footprint.y))
	instance.position = Vector2(r[0]+r[2]*0.5,r[1]+r[3])*48
	instance.set_meta("label",entry.get("label",""))
	instance.set_meta("map_footprint",Rect2i(r[0],r[1],r[2],r[3]))
	map.get_building_root().add_child(instance)
	return instance
static func add_prop(map: Node2D, entry: Dictionary) -> Node2D:
	var instance: Node2D = load(entry.scene).instantiate()
	instance.position = Vector2(entry.cell[0]+0.5,entry.cell[1]+1)*48
	instance.set_meta("category","free_prop")
	instance.set_meta("review_status","placed_in_rework_v1")
	map.get_building_root().add_child(instance)
	return instance
static func stamp_collision(map: Node2D, values: Array) -> void:
	var terrain: TileMapLayer = map.get_layer("地形")
	var collision: TileMapLayer = map.get_layer("碰撞")
	for y in range(values[1],values[1]+values[3]):
		for x in range(values[0],values[0]+values[2]):
			var cell := Vector2i(x,y)
			collision.set_cell(cell,terrain.get_cell_source_id(cell),terrain.get_cell_atlas_coords(cell))
