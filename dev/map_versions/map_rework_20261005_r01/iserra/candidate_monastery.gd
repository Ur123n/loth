extends "res://dev/leyton_world_demo/monastery.gd"

const SurfaceMaterial := preload("res://dev/map_versions/map_rework_20261005_r01/shared/surface_material.gd")
const ART_PATH := "res://assets/map_versions/iserra_surface_20261005_r01/base_surface_v1.png"

var candidate_art_enabled := true
var _base_sprite: Sprite2D
var _candidate_material: ShaderMaterial

func _ready() -> void:
	super._ready()
	_base_sprite = get_node("建筑对象/IserraMonasteryHighland/Visual/Base") as Sprite2D
	assert(_base_sprite != null and _base_sprite.texture != null, "Missing Iserra Base geometry layer")
	_candidate_material = SurfaceMaterial.make(ART_PATH, Color("555852"), Vector2(_base_sprite.texture.get_size()))
	set_candidate_art_enabled(true)
	# Building creates its visible YSort regions on the next idle frame.
	_apply_band_materials.call_deferred()
	set_meta("candidate_revision", "iserra_surface_20261005_r01")

func set_candidate_art_enabled(enabled: bool) -> void:
	candidate_art_enabled = enabled
	if is_instance_valid(_base_sprite):
		_base_sprite.material = _candidate_material if enabled else null
	_apply_band_materials()

func _apply_band_materials() -> void:
	for band in get_node("建筑对象").get_children():
		if band.has_meta("semantic_band_id"):
			var region := band.get_node_or_null("Region") as Sprite2D
			if region != null:
				region.material = _candidate_material if candidate_art_enabled else null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		set_candidate_art_enabled(not candidate_art_enabled)
		get_viewport().set_input_as_handled()
