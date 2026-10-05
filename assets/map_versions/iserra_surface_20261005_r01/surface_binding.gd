extends Node

const SurfaceMaterial := preload("res://assets/map_versions/shared/surface_material.gd")
const ART_PATH := "res://assets/map_versions/iserra_surface_20261005_r01/base_surface_v1.png"

func _ready() -> void:
	var base := get_parent().get_node("Visual/Base") as Sprite2D
	assert(base != null and base.texture != null, "Missing Iserra Base geometry")
	base.material = SurfaceMaterial.make(ART_PATH, Color("555852"), Vector2(base.texture.get_size()))
	get_parent().set_meta("active_surface_revision", "iserra_surface_20261005_r01")
