extends SceneTree
const ROOT := "res://assets/buildings/leyton_west_gatehouse/"
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: "+message)

func png(path: String) -> Image:
	var image := Image.new()
	check(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK,"decode "+path)
	return image

func run() -> void:
	var layers: Array[Image] = []
	for role in ["base","floor","roof","upper"]:
		var image := png(ROOT+"visual/"+role+".png")
		check(image.get_size() == Vector2i(624,864),"shared canvas: "+role)
		layers.append(image)
	var composite := png(ROOT+"source/registered_art_v1/registered.png")
	var exact := true
	var disjoint := true
	var padding := true
	var roof_clear := true
	var clear_lane := true
	for y in 864:
		for x in 624:
			var p := Vector2i(x,y)
			var sum := Color(0,0,0,0)
			var nonempty := 0
			for layer in layers:
				var pixel := layer.get_pixelv(p)
				if pixel.a > 0:
					nonempty += 1
					sum = pixel
				if not Rect2i(48,48,528,768).has_point(p):
					padding = padding and is_zero_approx(pixel.a)
			disjoint = disjoint and nonempty <= 1
			# Fully transparent RGB is irrelevant to alpha composition.
			var expected := composite.get_pixelv(p)
			exact = exact and (sum.is_equal_approx(expected) or (sum.a == 0 and expected.a == 0))
			if Rect2i(48,288,528,288).has_point(p):
				roof_clear = roof_clear and is_zero_approx(layers[2].get_pixelv(p).a)
			if Rect2i(384,48,144,768).has_point(p):
				clear_lane = clear_lane and is_zero_approx(layers[2].get_pixelv(p).a) and is_zero_approx(layers[0].get_pixelv(p).a)
	check(exact,"layers reproduce the complete registered image")
	check(disjoint,"semantic layers never double-blend source alpha")
	check(padding,"one-cell transparent outer margin")
	check(roof_clear,"roof never intrudes into six-cell lower passage")
	check(clear_lane,"full three-meter upper lane stays clear of roof and base")
	var backup := "res://maps/leyton/archive/pre_gatehouse_art/leyton_west_gatehouse/"
	for file in ["occupancy.png","walkable.png","collision.png","occlusion.png","doors.png"]:
		check(FileAccess.get_sha256(ROOT+"masks/"+file) == FileAccess.get_sha256(backup+"masks/"+file),"unchanged logic mask: "+file)
	var map: Node = load("res://maps/leyton/scenes/m07.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var gate: Node = map.get_buildings()[0]
	check(gate.get_node("Visual/Roof").visible and gate.get_node("Visual/Roof").z_index == 2,"roof loaded at intended depth")
	check(gate.get_node("Visual/WallWalk").z_index == 4,"upper surface remains above roofs")
	var segments := 0
	for child in map.get_node("UpperWallWalk").get_children():
		if child is Polygon2D and child.texture != null:
			segments += 1
			check(child.texture.get_width() == 192 and child.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED,"wall continuation uses 3m lane plus outside parapets")
	check(segments == 2,"north/south extensions both use art texture")
	map.queue_free()
	await process_frame
	print("LEYTON_GATEHOUSE_ART passed=%d failed=%d" % [passed,failed])
	quit(1 if failed else 0)
