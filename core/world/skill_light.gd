class_name SkillLight
extends Node2D

## 大世界上的技能光点（表现占位）：脉动光点 + “技能”标签。

var _dot: Polygon2D


func _ready() -> void:
	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.polygon = _circle_points(15.0)
	glow.color = Color(1.0, 0.85, 0.30, 0.22)
	add_child(glow)

	_dot = Polygon2D.new()
	_dot.name = "Dot"
	_dot.polygon = _circle_points(10.0)
	_dot.color = Color(1.0, 0.90, 0.45)
	add_child(_dot)

	var label := Label.new()
	label.name = "Label"
	label.text = "技能"
	label.position = Vector2(-20, 16)
	label.size = Vector2(40, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70))
	add_child(label)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var scale := 1.0 + 0.18 * sin(t * 3.0)
	_dot.scale = Vector2(scale, scale)


func _circle_points(radius: float, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
