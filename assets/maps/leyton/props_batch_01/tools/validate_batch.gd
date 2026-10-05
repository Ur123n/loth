extends SceneTree
const ROOT := "res://assets/maps/leyton/props_batch_01/"
var passed := 0
var failed := 0
func check(ok: bool, label_text: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL ",label_text)
func _initialize() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(doc.palette))
	var allowed := {}
	for rgb: Array in p.palette: allowed[Color8(rgb[0],rgb[1],rgb[2]).to_rgba32()] = true
	allowed[Color8(12,10,16).to_rgba32()] = true
	var measurements: Array = []
	for e: Dictionary in doc.assets:
		var img := Image.new()
		check(img.load_png_from_buffer(FileAccess.get_file_as_bytes(ROOT+e.sprite))==OK,e.id+" PNG decode")
		check(img.get_size()==Vector2i(e.canvas[0],e.canvas[1]),e.id+" dimensions")
		check(FileAccess.get_sha256(ROOT+e.source)==e.source_sha256,e.id+" original hash")
		var outside_palette := 0
		var visible := 0
		var border_clear := true
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x,y)
				if x==0 or y==0 or x==img.get_width()-1 or y==img.get_height()-1: border_clear = border_clear and c.a==0
				if c.a==0: continue
				visible += 1
				c.a = 1
				if not allowed.has(c.to_rgba32()): outside_palette += 1
		check(border_clear,e.id+" transparent margins")
		check(visible>100,e.id+" nonempty image")
		check(outside_palette==0,e.id+" exact environment palette")
		check(e.bright_ratio<=0.05,e.id+" rare highlights")
		check(e.collision_size_px[0]<=e.visible_size[0] and e.collision_size_px[1]<=e.visible_size[1],e.id+" bounded proposed footprint")
		var prop: Node2D = load(ROOT+"scenes/"+e.id+".tscn").instantiate()
		check(prop.has_independent_collision() and prop.get_prop_id()=="leyton_"+e.id,e.id+" FreeProp contract")
		check(prop.get_node("Visual").position == -Vector2(e.anchor[0],e.anchor[1]),e.id+" anchor alignment")
		check(prop.z_index==0 and prop.get_node("Visual").z_index==0,e.id+" YSort band")
		prop.free()
		measurements.append({"id":e.id,"opaque_and_partial_pixels":visible,"outside_palette_pixels":outside_palette,"border_clear":border_clear,"sprite_sha256":FileAccess.get_sha256(ROOT+e.sprite)})
	var file := FileAccess.open(ROOT+"qa/pixel_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"assets":measurements},"\t")+"\n")
	print("PROPS_PIXEL passed=",passed," failed=",failed)
	quit(1 if failed else 0)
