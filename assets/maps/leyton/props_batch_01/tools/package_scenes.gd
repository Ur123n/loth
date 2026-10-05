extends SceneTree
const ROOT := "res://assets/maps/leyton/props_batch_01/"
func _initialize() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	var failed := 0
	for entry: Dictionary in doc.assets:
		var prop := Node2D.new()
		prop.set_script(load("res://core/world/free_prop.gd"))
		prop.name = entry.id.to_pascal_case()
		prop.prop_id = "leyton_"+entry.id
		prop.footprint_cells = Vector2i(ceili(entry.collision_size_px[0]/48.0),ceili(entry.collision_size_px[1]/48.0))
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prop.set_meta("projection_id","orthogonal_3q_48_v1")
		prop.set_meta("review_status","candidate")
		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = load(ROOT+entry.sprite)
		sprite.centered = false
		sprite.position = -Vector2(entry.anchor[0],entry.anchor[1])
		prop.add_child(sprite)
		sprite.owner = prop
		var collision := StaticBody2D.new()
		collision.name = "Collision"
		collision.collision_layer = 2
		collision.collision_mask = 1
		prop.add_child(collision)
		collision.owner = prop
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(entry.collision_size_px[0],entry.collision_size_px[1])
		shape.shape = rect
		shape.position.y = -rect.size.y/2
		collision.add_child(shape)
		shape.owner = prop
		var packed := PackedScene.new()
		if packed.pack(prop)!=OK or ResourceSaver.save(packed,ROOT+"scenes/"+entry.id+".tscn")!=OK: failed += 1
		prop.free()
	print("PROPS_PACKAGE scenes=6 failed=",failed)
	quit(1 if failed else 0)
