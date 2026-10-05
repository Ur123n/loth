extends "res://maps/leyton/graybox_map.gd"

const SurfaceMaterial := preload("res://assets/map_versions/shared/surface_material.gd")
const ART_PATHS := [
	"res://assets/map_versions/leyton_m02_surface_20261005_r01/noble_surface_a.png",
	"res://assets/map_versions/leyton_m02_surface_20261005_r01/noble_surface_b.png",
	"res://assets/map_versions/leyton_m02_surface_20261005_r01/noble_surface_c.png",
]

var candidate_art_enabled := true
var candidate_visuals: Array[Sprite2D] = []
var candidate_materials: Array[ShaderMaterial] = []
var candidate_variant_counts := [0, 0, 0]

func _ready() -> void:
	super._ready()
	_apply_candidate_materials()
	set_meta("active_surface_revision", "leyton_m02_surface_20261005_r01")

func _apply_candidate_materials() -> void:
	var root := get_building_root()
	var visual_index := 0
	for child in root.get_children():
		if str(child.get("pattern_id")) != "stone_house":
			continue
		var visual := child.get_node_or_null("Visual") as Sprite2D
		if visual == null or visual.texture == null:
			continue
		var variant := visual_index % ART_PATHS.size()
		var material := SurfaceMaterial.make(ART_PATHS[variant], Color("4b4b47"), Vector2(visual.texture.get_size()))
		candidate_visuals.append(visual)
		candidate_materials.append(material)
		candidate_variant_counts[variant] += 1
		visual_index += 1
	set_candidate_art_enabled(true)

func set_candidate_art_enabled(enabled: bool) -> void:
	candidate_art_enabled = enabled
	for index in candidate_visuals.size():
		candidate_visuals[index].material = candidate_materials[index] if enabled else null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		set_candidate_art_enabled(not candidate_art_enabled)
		get_viewport().set_input_as_handled()
