extends SceneTree
const DIR := "res://assets/maps/leyton/street_sample_v3/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var results: Array = []
	for spec: Array in [["street_row",Vector2i(720,576),Vector2i(14,8),Vector2(-24,-576)],["service_wing",Vector2i(288,672),Vector2i(5,11),Vector2(-24,-672)],["corner_residence",Vector2i(624,624),Vector2i(12,9),Vector2(-24,-624)],["well",Vector2i(144,192),Vector2i(2,2),Vector2(-72,-192)]]:
		var im := Image.load_from_file(DIR+"source/"+spec[0]+".png")
		assert(im != null and not im.is_empty())
		var lo := im.get_size()
		var hi := Vector2i.ZERO
		var opaque := 0
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x,y).a >= 0.05:
					lo = lo.min(Vector2i(x,y))
					hi = hi.max(Vector2i(x,y)+Vector2i.ONE)
					opaque += 1
		assert(opaque > 0 and opaque < im.get_width()*im.get_height()*0.95,"Expected transparent source")
		var crop := Rect2i(lo,hi-lo)
		im = im.get_region(crop)
		im.resize(spec[1].x,spec[1].y,Image.INTERPOLATE_NEAREST)
		assert(im.save_png(DIR+spec[0]+".png")==OK)
		results.append({"asset":spec[0],"source_crop":[crop.position.x,crop.position.y,crop.size.x,crop.size.y],"size":[im.get_width(),im.get_height()],"source_sha256":FileAccess.get_sha256(DIR+"source/"+spec[0]+".png"),"sprite_sha256":FileAccess.get_sha256(DIR+spec[0]+".png")})
	var f := FileAccess.open(DIR+"manifest.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"assets":results,"processing":"alpha>=0.05 bounds, nearest resize, source alpha retained; collision independently authored"},"\t"))
	print("STREET_ASSETS registered=",results.size())
	quit()
