extends SceneTree
## Geometry-first diagnostic structure. These flat images are not final building art.
const ROOT := "res://assets/buildings/leyton_west_gatehouse/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "source"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "visual"))
	var base := canvas()
	var floor_image := canvas()
	var upper := canvas()
	paint_grid(base,Rect2i(48,48,528,240),Color("344c50"))
	paint_grid(base,Rect2i(48,576,528,240),Color("344c50"))
	paint_grid(floor_image,Rect2i(48,288,528,288),Color("a59c81"))
	paint_grid(upper,Rect2i(384,48,144,768),Color("78948e"))
	upper.fill_rect(Rect2i(384,48,4,768),Color("bfd0b1"))
	upper.fill_rect(Rect2i(524,48,4,768),Color("bfd0b1"))
	var failed := 0
	for item in [["base",base],["floor",floor_image],["upper",upper]]:
		if item[1].save_png(ROOT + "source/graybox_%s.png" % item[0]) != OK:
			failed += 1
	var spec := {
		"building_id":"leyton_west_gatehouse", "display_name":"莱顿西门楼（结构灰盒）",
		"kind":"structure", "projection_id":"orthogonal_3q_48_v1", "anchor_mode":"bottom_center",
		"visual":{"tile_size":48,"padding_tiles":1,"source_origin_tile":[1,1],"clip_to_logic":false,
			"layers":[
				{"name":"Base","role":"base","source":ROOT+"source/graybox_base.png","output":"base.png","z_index":0,"visible":true},
				{"name":"Floor","role":"floor","source":ROOT+"source/graybox_floor.png","output":"floor.png","z_index":-1,"visible":true},
				{"name":"WallWalk","role":"foreground","source":ROOT+"source/graybox_upper.png","output":"upper.png","z_index":4,"visible":true}]},
		"collision":{"layer":2,"mask":1},
		"sorting":{"mode":"y_sort","y_sort_origin":"bottom_center","z_index":0,"occluder":false,"roof_layer_z":12},
		"tactical":{"cover":2,"cover_level":"high","height_level":0,"blocks_los":true,"enterable":true},
		"plan":{"scale":{"px_per_meter":48,"tile_px":48},"origin_m":[0,0],"footprint_m":[11,16],
			"rooms":[{"id":"gatehouse","label":"地面实体与门洞","x_m":0,"y_m":0,"w_m":11,"h_m":16,"solid":true,"roof":null}],
			"openings":[{"x_m":1,"y_m":5,"w_m":9,"h_m":6}],
			"doors":[{"id":"west","x_m":0,"y_m":5,"w_m":6,"side":"w","target":"outside","interact":""},
				{"id":"east","x_m":10,"y_m":5,"w_m":6,"side":"e","target":"outside","interact":""}]}
	}
	var serialized := JSON.stringify(spec,"\t") + "\n"
	var staged := FileAccess.open(ROOT + "source/building.spec.staged.json",FileAccess.WRITE)
	staged.store_string(serialized)
	staged.close()
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source/building.spec.staged.json"))
	if parsed.plan.footprint_m != [11.0,16.0] or parsed.visual.layers.size() != 3:
		printerr("Gatehouse spec invariant failed")
		quit(1)
		return
	# This diagnostic builder owns the generated spec. Edit this source to rebuild it.
	if DirAccess.copy_absolute(ROOT + "source/building.spec.staged.json",ROOT + "building.spec.json") != OK:
		failed += 1
	print("GATEHOUSE_DRAFT canvas=624x864 layers=3 failed=",failed)
	quit(1 if failed else 0)

func canvas() -> Image:
	var image := Image.create(624,864,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image

func paint_grid(image: Image, area: Rect2i, color: Color) -> void:
	image.fill_rect(area,color)
	for x in range(area.position.x,area.end.x,48):
		image.fill_rect(Rect2i(x,area.position.y,1,area.size.y),color.lightened(0.15))
	for y in range(area.position.y,area.end.y,48):
		image.fill_rect(Rect2i(area.position.x,y,area.size.x,1),color.lightened(0.15))
