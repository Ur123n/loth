extends SceneTree
## Mechanical source registration and semantic layer packaging; no painted replacement.
const ROOT := "res://assets/buildings/leyton_west_gatehouse/"
const OUT := ROOT + "source/registered_art_v1/"
const SOURCE := ROOT + "source/concept_v1.png"
const SOURCE_SHA := "df4dfc32cc8fa283247b731b0b2db2aaf6af894df3fd1a0d5000552ed4baff19"
const UPPER := Rect2i(360,48,192,768)
const ROOFS := [Rect2i(48,48,312,166),Rect2i(48,576,312,168)]
var failed := 0

func _initialize() -> void:
	if FileAccess.get_sha256(SOURCE) != SOURCE_SHA:
		printerr("Source changed: review gatehouse registration landmarks")
		quit(1)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE)) != OK or source.get_size() != Vector2i(1066,1476):
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	var registered := canvas()
	# Independently register the wings/aprons and upper bridge: the generation has
	# perspective-height padding on the upper walkway which cannot shift ground geometry.
	var source_y := [85,560,900,1364]
	var target_y := [48,288,576,816]
	for row in 3:
		stamp(source,registered,Rect2i(77,source_y[row],563,source_y[row+1]-source_y[row]),Rect2i(48,target_y[row],312,target_y[row+1]-target_y[row]))
		stamp(source,registered,Rect2i(905,source_y[row],87,source_y[row+1]-source_y[row]),Rect2i(552,target_y[row],24,target_y[row+1]-target_y[row]))
	# Keep all THREE meters of walkway clear; parapets sit outside it, in 24px strips.
	for pair in [[640,62,360,24],[702,148,384,144],[850,55,528,24]]:
		stamp(source,registered,Rect2i(pair[0],80,pair[1],1318),Rect2i(pair[2],48,pair[3],768))
	var layers := {"base":canvas(),"floor":canvas(),"roof":canvas(),"upper":canvas()}
	var reconstructed := canvas()
	for y in 864:
		for x in 624:
			var p := Vector2i(x,y)
			var role := "base"
			if UPPER.has_point(p):
				role = "upper"
			elif ROOFS[0].has_point(p) or ROOFS[1].has_point(p):
				role = "roof"
			elif Rect2i(48,288,528,288).has_point(p):
				role = "floor"
			var color := registered.get_pixelv(p)
			layers[role].set_pixelv(p,color)
			reconstructed.set_pixelv(p,layers[role].get_pixelv(p))
	if reconstructed.get_data() != registered.get_data():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for role in layers:
		if layers[role].save_png(OUT+role+".png") != OK:
			failed += 1
	if registered.save_png(OUT+"registered.png") != OK:
		failed += 1
	# A repeated strip extends the SAME clear 3m lane beyond this independent building.
	var strip: Image = layers.upper.get_region(Rect2i(360,384,192,48))
	if strip.save_png(OUT+"wall_walk_strip.png") != OK:
		failed += 1
	var record := {"source":SOURCE,"sha256":SOURCE_SHA,"size_px":[624,864],
		"wing_source_y":source_y,"wing_target_y":target_y,"wing_x":[77,640,48,360],"east_x":[905,992,552,576],
		"upper_source":[[640,80,62,1318],[702,80,148,1318],[850,80,55,1318]],
		"upper_target":[[360,48,24,768],[384,48,144,768],[528,48,24,768]],
		"roof_rects":[[48,48,312,166],[48,576,312,168]],"reconstruction_exact":true,"interpolation":"nearest","collision_changed":false}
	write_json(OUT+"registration.json",record)
	# Write a reviewable staged spec first. Promotion is a separate file copy.
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"building.spec.json"))
	spec.display_name = "莱顿西门楼"
	spec.visual.layers = [
		{"name":"Base","role":"base","source":OUT+"base.png","output":"base.png","z_index":0,"visible":true},
		{"name":"Floor","role":"floor","source":OUT+"floor.png","output":"floor.png","z_index":-1,"visible":true},
		{"name":"Roof","role":"roof","source":OUT+"roof.png","output":"roof.png","z_index":2,"visible":true},
		{"name":"WallWalk","role":"foreground","source":OUT+"upper.png","output":"upper.png","z_index":4,"visible":true}]
	write_json(OUT+"building.spec.staged.json",spec)
	print("GATEHOUSE_ART_REGISTER layers=4 exact_reconstruction=true failed=",failed)
	quit(1 if failed else 0)

func canvas() -> Image:
	var image := Image.create(624,864,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image

func stamp(source: Image, target: Image, from: Rect2i, to: Rect2i) -> void:
	var patch := source.get_region(from)
	patch.resize(to.size.x,to.size.y,Image.INTERPOLATE_NEAREST)
	target.blit_rect(patch,Rect2i(Vector2i.ZERO,patch.get_size()),to.position)

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		failed += 1
		return
	file.store_string(JSON.stringify(value,"\t")+"\n")
