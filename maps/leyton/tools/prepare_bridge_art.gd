extends SceneTree
## Deterministic registration/packaging of an approved generated source, not repainting.
const ROOT := "res://assets/buildings/leyton_cargo_bridge/"
const OUT := ROOT + "source/registered_v2/"
const SOURCE := ROOT + "source/concept_v2.png"
const SOURCE_SHA := "fd0af4f222fed30aa31aebcea08189e994c4ec067100ed6e8b456637b027578b"
const RAILS := [Rect2i(48, 96, 48, 432), Rect2i(576, 96, 48, 432)]

func _initialize() -> void:
	if FileAccess.get_sha256(SOURCE) != SOURCE_SHA:
		printerr("Source changed: registration landmarks must be reviewed again")
		quit(1)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE)) != OK or source.get_size() != Vector2i(1301, 1209):
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	# Measured seams: left rail / deck / right rail; north apron / rails / south apron.
	# Map the whole structure continuously in nine rectangular regions, never into Tiles.
	var source_x := [91, 202, 1104, 1211]
	var source_y := [95, 176, 1026, 1111]
	var target_x := [48, 96, 576, 624]
	var target_y := [48, 96, 528, 576]
	var registered := Image.create(672, 624, false, Image.FORMAT_RGBA8)
	registered.fill(Color.TRANSPARENT)
	for row in 3:
		for col in 3:
			var rect := Rect2i(source_x[col], source_y[row], source_x[col+1]-source_x[col], source_y[row+1]-source_y[row])
			var patch := source.get_region(rect)
			patch.resize(target_x[col+1]-target_x[col], target_y[row+1]-target_y[row], Image.INTERPOLATE_NEAREST)
			registered.blit_rect(patch, Rect2i(Vector2i.ZERO, patch.get_size()), Vector2i(target_x[col], target_y[row]))
	var deck: Image = registered.duplicate()
	var rails := Image.create(672, 624, false, Image.FORMAT_RGBA8)
	rails.fill(Color.TRANSPARENT)
	for rect: Rect2i in RAILS:
		rails.blit_rect(registered, rect, rect.position)
		deck.fill_rect(rect, Color.TRANSPARENT)
	# Disjoint layers reconstruct every RGBA byte, including source partial alpha.
	var recomposed: Image = deck.duplicate()
	for rect: Rect2i in RAILS:
		recomposed.blit_rect(rails, rect, rect.position)
	if recomposed.get_data() != registered.get_data():
		printerr("Layer reconstruction mismatch")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var failed := 0
	for item in [["registered.png", registered], ["deck.png", deck], ["rails.png", rails]]:
		if item[1].save_png(OUT + item[0]) != OK:
			failed += 1
	var report := {
		"source": SOURCE, "sha256": SOURCE_SHA, "canvas": [672,624],
		"source_x": source_x, "source_y": source_y,
		"target_x": target_x, "target_y": target_y,
		"rail_rects": [[48,96,48,432],[576,96,48,432]],
		"alpha_preserved": true, "layer_reconstruction_exact": true,
		"interpolation": "nearest", "collision_changed": false
	}
	var file := FileAccess.open(OUT + "registration.json", FileAccess.WRITE)
	if file == null:
		failed += 1
	else:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("BRIDGE_REGISTER canvas=672x624 exact_layers=true failed=", failed)
	quit(1 if failed else 0)
