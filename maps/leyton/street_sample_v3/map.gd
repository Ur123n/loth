extends "res://maps/leyton/graybox_map.gd"
var art_enabled := true
var block_visuals: Array[Node2D] = []
func _init() -> void:
	layout_document = "res://maps/leyton/street_sample_v3/layout.json"
	map_id = "M02"
func _load_structures() -> void:
	var holder := Node2D.new()
	holder.name = BUILDING_ROOT
	holder.y_sort_enabled = true
	holder.z_index = 1
	add_child(holder)
	for entry: Dictionary in layout.structures:
		var b := Node2D.new()
		b.name = entry.id
		var r := rect(entry.rect)
		b.position = Vector2(r.position.x,r.end.y)*48
		b.set_script(load("res://core/world/map_pattern_instance.gd"))
		b.pattern_id = entry.id
		b.footprint_cells = r.size
		b.anchor_cell = Vector2i(0,r.size.y)
		b.set_meta("ground_rect",r)
		var h := float(entry.height)*48
		var facade := Polygon2D.new()
		facade.name = "Facade"
		facade.polygon = PackedVector2Array([Vector2(0,-h),Vector2(r.size.x*48,-h),Vector2(r.size.x*48,0),Vector2.ZERO])
		facade.color = Color("625f58")
		b.add_child(facade)
		var roof := Polygon2D.new()
		roof.name = "Roof"
		roof.position = Vector2(0,-r.size.y*48-h)
		roof.polygon = rectangle_points(Vector2(r.size)*48)
		roof.color = Color("434b51") if int(entry.height)==3 else Color("545354")
		b.add_child(roof)
		var line := Line2D.new()
		line.points = PackedVector2Array([roof.position+Vector2(0,r.size.y*24),roof.position+Vector2(r.size.x*48,r.size.y*24)])
		line.width = 3
		line.default_color = Color("777975")
		b.add_child(line)
		var body := StaticBody2D.new()
		body.name = "Collision"
		body.collision_layer = 2
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(r.size)*48
		collision.shape = shape
		collision.position = Vector2(r.size.x*24,-r.size.y*24)
		body.add_child(collision)
		b.add_child(body)
		b.set_meta("visual_rect",Rect2(Vector2(0,-r.size.y*48-h),Vector2(r.size.x*48,r.size.y*48+h)))
		holder.add_child(b)
		block_visuals.append(b)
		if art_enabled: _apply_art(b,entry)
	# The well is deliberately a graybox until its own prop is produced.
	var well := Polygon2D.new()
	well.name = "WellGraybox"
	well.position = Vector2(18,17)*48
	well.polygon = PackedVector2Array([Vector2(-30,-24),Vector2(30,-24),Vector2(42,0),Vector2(30,24),Vector2(-30,24),Vector2(-42,0)])
	well.color = Color("858074")
	holder.add_child(well)
	well.visible = not art_enabled
	var well_art: Node2D = load("res://assets/maps/leyton/street_sample_v3/well.tscn").instantiate()
	well_art.name = "Well"
	well_art.position = Vector2(18,18)*48
	well_art.visible = art_enabled
	holder.add_child(well_art)
	ObjectPlacer.stamp_collision(self,[17,16,2,2])
func update_occlusion(actor: Vector2) -> void:
	for b: Node2D in block_visuals:
		var local_actor := actor-b.position
		var obscures: bool = b.get_meta("visual_rect").has_point(local_actor) and local_actor.y < 0
		b.modulate.a = 1.0
		if art_enabled and b.has_node("GeneratedVisual/Roof"):
			b.get_node("GeneratedVisual/Roof").modulate.a = 0.25 if obscures else 1.0
		else:
			b.modulate.a = 0.32 if obscures else 1.0

func _apply_art(block: Node2D, entry: Dictionary) -> void:
	if entry.id in ["estate_east_n","estate_east_s"]: return
	var wing: bool = entry.id == "estate_west"
	var corner: bool = entry.id in ["corner_row","estate_north"]
	var tex: Texture2D = load("res://assets/maps/leyton/street_sample_v3/"+("service_wing" if wing else ("corner_residence" if corner else "street_row"))+".png")
	if tex == null: return
	var width := float(entry.rect[2])*48
	var factor := width/(240.0 if wing else (576.0 if corner else 672.0))
	for child: Node in block.get_children():
		if child is Polygon2D or child is Line2D: child.visible = false
	var visual := Node2D.new()
	visual.name = "GeneratedVisual"
	visual.scale = Vector2.ONE*factor
	visual.position = Vector2(-24*factor,-tex.get_height()*factor)
	var split := floori(tex.get_height()*(0.69 if not corner else 0.54))
	for part in 2:
		var sprite := Sprite2D.new()
		sprite.name = "Roof" if part==0 else "Facade"
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(0,0 if part==0 else split,tex.get_width(),split if part==0 else tex.get_height()-split)
		sprite.texture = atlas
		sprite.centered = false
		sprite.position.y = 0 if part==0 else split
		visual.add_child(sprite)
	block.add_child(visual)
	block.set_meta("visual_rect",Rect2(visual.position,Vector2(tex.get_size())*factor))
func set_art_enabled(enabled: bool) -> void:
	art_enabled = enabled
	get_building_root().get_node("Well").visible = enabled
	get_building_root().get_node("WellGraybox").visible = not enabled
	for block: Node2D in block_visuals:
		if not block.has_node("GeneratedVisual"): continue
		block.get_node("GeneratedVisual").visible = enabled
		for child: Node in block.get_children():
			if child is Polygon2D or child is Line2D: child.visible = not enabled
