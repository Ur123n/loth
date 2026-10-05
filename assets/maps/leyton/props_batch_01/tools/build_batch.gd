extends SceneTree
## Mechanical registration, nearest-neighbor reduction and palette export only.
const ROOT := "res://assets/maps/leyton/props_batch_01/"
const SPECS := [
	["crate","木箱",Vector2i(96,96),44,Vector2i(40,28)],
	["barrel","木桶",Vector2i(96,96),34,Vector2i(32,24)],
	["grain_sacks","粮袋堆",Vector2i(144,96),72,Vector2i(68,40)],
	["coal_basket","煤筐",Vector2i(144,96),64,Vector2i(58,26)],
	["notice_board","公告栏",Vector2i(144,144),68,Vector2i(64,12)],
	["handcart","手推车",Vector2i(144,192),58,Vector2i(54,94)]
]
var palette: Array[Color] = []
var failures := 0
func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ",what)
func _initialize() -> void:
	var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dark48/色板/map_env.json"))
	for rgb: Array in p.palette: palette.append(Color8(rgb[0],rgb[1],rgb[2]))
	palette.append(Color8(12,10,16))
	var manifest := {"version":1,"status":"candidate_for_visual_review","generation":"built-in image_gen","projection_id":"orthogonal_3q_48_v1","tile_size_px":48,"palette":"res://assets/dark48/色板/map_env.json","assets":[]}
	for spec: Array in SPECS:
		var id: String = spec[0]
		var source := Image.new()
		check(source.load(ROOT+"source/"+id+".png")==OK,id+" PNG decode")
		source.convert(Image.FORMAT_RGBA8)
		check(source.get_pixel(0,0).a==0,id+" transparent corner")
		# Ignore near-invisible generation residue when measuring the crop only.
		# All alpha inside this crop, including the contact shadow, is preserved.
		var low := source.get_size()
		var high := Vector2i(-1,-1)
		for y in source.get_height():
			for x in source.get_width():
				if source.get_pixel(x,y).a>=0.05:
					low = low.min(Vector2i(x,y))
					high = high.max(Vector2i(x,y))
		var bounds := Rect2i(low,high-low+Vector2i.ONE)
		check(bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<source.get_width() and bounds.end.y<source.get_height(),id+" whole silhouette")
		var reduced := source.get_region(bounds)
		var target_width: int = spec[3]
		var target_height := roundi(float(bounds.size.y)*target_width/bounds.size.x)
		reduced.resize(target_width,target_height,Image.INTERPOLATE_NEAREST)
		# Preserve alpha; quantize RGB to existing environment colors, no invented paint.
		var bright := 0
		var visible := 0
		var total_luma := 0.0
		for y in reduced.get_height():
			for x in reduced.get_width():
				var color := reduced.get_pixel(x,y)
				if color.a==0: continue
				var nearest := palette[0]
				var distance := INF
				for candidate: Color in palette:
					var d := pow(color.r-candidate.r,2)*0.299+pow(color.g-candidate.g,2)*0.587+pow(color.b-candidate.b,2)*0.114
					if d<distance:
						distance = d
						nearest = candidate
				nearest.a = color.a
				reduced.set_pixel(x,y,nearest)
				if color.a>0.5:
					visible += 1
					var luma := (nearest.r*0.299+nearest.g*0.587+nearest.b*0.114)*255
					total_luma += luma
					if luma>=185: bright += 1
		var size: Vector2i = spec[2]
		var anchor := Vector2i(size.x/2,size.y-12)
		var origin := Vector2i(anchor.x-target_width/2,anchor.y-target_height)
		check(origin.x>=4 and origin.y>=4,id+" canvas margin")
		var output := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		output.blit_rect(reduced,Rect2i(Vector2i.ZERO,reduced.get_size()),origin)
		check(output.save_png(ROOT+"sprites/prop_"+id+".png")==OK,id+" save")
		manifest.assets.append({"id":id,"name":spec[1],"source":"source/"+id+".png","source_sha256":FileAccess.get_sha256(ROOT+"source/"+id+".png"),"crop_alpha_threshold":0.05,"source_crop":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"sprite":"sprites/prop_"+id+".png","canvas":[size.x,size.y],"anchor":[anchor.x,anchor.y],"visible_size":[target_width,target_height],"collision_size_px":[spec[4].x,spec[4].y],"mean_luma":total_luma/maxi(1,visible),"bright_ratio":float(bright)/maxi(1,visible),"alpha_preserved_inside_crop":true,"status":"candidate"})
	var file := FileAccess.open(ROOT+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t")+"\n")
	print("PROPS_REGISTER assets=6 failed=",failures)
	quit(1 if failures else 0)
