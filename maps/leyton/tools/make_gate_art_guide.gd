extends SceneTree
const ROOT := "res://assets/buildings/leyton_west_gatehouse/"

func _initialize() -> void:
	var guide := Image.create(624,864,false,Image.FORMAT_RGBA8)
	guide.fill(Color.TRANSPARENT)
	for part in ["floor","base","upper"]:
		var layer := Image.new()
		if layer.load_png_from_buffer(FileAccess.get_file_as_bytes(ROOT+"source/graybox_%s.png" % part)) != OK:
			quit(1)
			return
		guide.blend_rect(layer,Rect2i(0,0,624,864),Vector2i.ZERO)
	var error := guide.save_png(ROOT+"source/art_geometry_guide.png")
	print("GATE_ART_GUIDE error=",error)
	quit(0 if error == OK else 1)
