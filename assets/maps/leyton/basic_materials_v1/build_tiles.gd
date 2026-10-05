extends SceneTree
const BASE := "res://assets/maps/leyton/basic_materials_v1/"
const NAMES := ["roof", "field", "wood", "soil"]
func _initialize() -> void:
	var palette: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dark48/色板/map_env.json")).palette
	var report: Array = []
	var sheet := Image.create(768,192,false,Image.FORMAT_RGBA8)
	var atlas := Image.create(192,48,false,Image.FORMAT_RGBA8)
	for index in NAMES.size():
		var name_text: String = NAMES[index]
		var source := BASE+"source/"+name_text+".png"
		var tile := Image.load_from_file(source)
		assert(tile != null)
		tile.resize(48,48,Image.INTERPOLATE_NEAREST)
		tile.convert(Image.FORMAT_RGBA8)
		var mean := 0.0
		for y in 48:
			for x in 48:
				var original := tile.get_pixel(x,y)
				var best := Color.BLACK
				var distance := INF
				for rgb: Array in palette:
					var candidate := Color8(rgb[0],rgb[1],rgb[2])
					var diff := Vector3(original.r-candidate.r,original.g-candidate.g,original.b-candidate.b).length_squared()
					if diff < distance:
						distance = diff
						best = candidate
				tile.set_pixel(x,y,best)
				mean += (best.r*0.299+best.g*0.587+best.b*0.114)*255
		assert(tile.save_png(BASE+"tiles/"+name_text+".png")==OK)
		atlas.blit_rect(tile,Rect2i(0,0,48,48),Vector2i(index*48,0))
		var seam := 0.0
		for i in 48:
			var a := tile.get_pixel(0,i)
			var b := tile.get_pixel(47,i)
			var c := tile.get_pixel(i,0)
			var d := tile.get_pixel(i,47)
			seam += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(c.r-d.r)+absf(c.g-d.g)+absf(c.b-d.b))*255
		for y in 4:
			for x in 4:
				sheet.blit_rect(tile,Rect2i(0,0,48,48),Vector2i(index*192+x*48,y*48))
		report.append({"name":name_text,"source_sha256":FileAccess.get_sha256(source),"size":[48,48],"mean_luma":mean/2304,"edge_mean_rgb_delta":seam/288,"processing":"nearest resize; map_env palette; source retained; no edge repaint"})
	assert(atlas.save_png(BASE+"atlas.png")==OK)
	sheet.resize(1536,384,Image.INTERPOLATE_NEAREST)
	assert(sheet.save_png(BASE+"qa/tiling.png")==OK)
	var file := FileAccess.open(BASE+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"generator":"built-in image_gen","materials":report},"\t")+"\n")
	print("BASIC_MATERIALS built=4")
	quit()
