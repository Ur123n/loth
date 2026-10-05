extends SceneTree
const BASE := "res://assets/maps/leyton/urban_rework_v1/"
func _initialize() -> void:
	var palette: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dark48/色板/map_env.json")).palette
	var report: Array = []
	for name_text: String in ["stone_house","timber_house","urban_pavers"]:
		var source := BASE+"source/"+name_text+".png"
		var original := Image.load_from_file(source)
		assert(original != null)
		var bounds := original.get_used_rect()
		if name_text != "urban_pavers":
			var low := original.get_size()
			var high := Vector2i.ZERO
			for y in original.get_height():
				for x in original.get_width():
					if original.get_pixel(x,y).a >= 0.05:
						low = Vector2i(mini(low.x,x),mini(low.y,y))
						high = Vector2i(maxi(high.x,x),maxi(high.y,y))
			bounds = Rect2i(low,high-low+Vector2i.ONE)
		var image := original.get_region(bounds)
		var size := Vector2i(384,480) if name_text=="stone_house" else Vector2i(288,336)
		if name_text=="urban_pavers": size = Vector2i(48,48)
		image.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
		image.convert(Image.FORMAT_RGBA8)
		for y in size.y:
			for x in size.x:
				var color := image.get_pixel(x,y)
				if color.a==0: continue
				var distance := INF
				var best := Color.BLACK
				for rgb: Array in palette:
					var candidate := Color8(rgb[0],rgb[1],rgb[2])
					var difference := Vector3(color.r-candidate.r,color.g-candidate.g,color.b-candidate.b).length_squared()
					if difference<distance:
						distance = difference
						best = candidate
				best.a = color.a
				image.set_pixel(x,y,best)
		assert(image.save_png(BASE+name_text+".png")==OK)
		report.append({"id":name_text,"source_sha256":FileAccess.get_sha256(source),"size":[size.x,size.y],"source_alpha":original.detect_alpha(),"crop":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
	var file := FileAccess.open(BASE+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"generator":"built-in image_gen","assets":report},"\t")+"\n")
	print("URBAN_ASSETS built=3")
	quit()
