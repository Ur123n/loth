extends RefCounted

const SHADER_PATH := "res://dev/map_versions/map_rework_20261005_r01/shared/surface.gdshader"
const PALETTE_PATH := "res://assets/dark48/色板/map_env.json"

static func make(art_path: String, fallback: Color, logical_canvas: Vector2) -> ShaderMaterial:
	var palette_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_PATH))
	assert(palette_data.has("palette") and palette_data.palette.size() == 32, "Candidate map palette must contain 32 colors")
	var colors := PackedColorArray()
	for rgb in palette_data.palette:
		colors.append(Color(float(rgb[0]) / 255.0, float(rgb[1]) / 255.0, float(rgb[2]) / 255.0))
	var shader := load(SHADER_PATH) as Shader
	var art := load(art_path) as Texture2D
	assert(shader != null, "Missing candidate surface shader")
	assert(art != null, "Missing candidate art surface: " + art_path)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("art_surface", art)
	material.set_shader_parameter("map_colors", colors)
	material.set_shader_parameter("fallback_color", fallback)
	material.set_shader_parameter("logical_canvas", logical_canvas)
	return material
