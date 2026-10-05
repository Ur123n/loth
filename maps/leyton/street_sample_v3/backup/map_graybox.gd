extends "res://maps/leyton/graybox_map.gd"
var art_enabled := false
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
	# The well is deliberately a graybox until its own prop is produced.
	var well := Polygon2D.new()
	well.name = "WellGraybox"
	well.position = Vector2(18,17)*48
	well.polygon = PackedVector2Array([Vector2(-30,-24),Vector2(30,-24),Vector2(42,0),Vector2(30,24),Vector2(-30,24),Vector2(-42,0)])
	well.color = Color("858074")
	holder.add_child(well)
	ObjectPlacer.stamp_collision(self,[17,16,2,2])
func update_occlusion(actor: Vector2) -> void:
	for b: Node2D in block_visuals:
		var local_actor := actor-b.position
		var obscures: bool = b.get_meta("visual_rect").has_point(local_actor) and local_actor.y < 0
		b.modulate.a = 0.32 if obscures else 1.0
