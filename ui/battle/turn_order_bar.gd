class_name TurnOrderBar
extends Control

## 行动次序条（表现层）：按行动值从大到小显示本回合单位顺序（玩家与敌怪），
## 高亮当前行动者。

var _labels: Array[Label] = []
var _base_texts: Array[String] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = 44


func update_order(order: Array, values: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_labels.clear()
	_base_texts.clear()

	var hbox := HBoxContainer.new()
	hbox.name = "OrderList"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	for i in order.size():
		var unit := order[i] as BattleUnit
		var text := "%d. %s (%d)" % [i + 1, unit.get_display_name(), values.get(unit, 0)]
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80))
		hbox.add_child(label)
		_labels.append(label)
		_base_texts.append(text)

	set_current(0)


func set_current(index: int) -> void:
	for i in _labels.size():
		if i == index:
			_labels[i].text = "▶ " + _base_texts[i]
			_labels[i].add_theme_font_size_override("font_size", 16)
			_labels[i].add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		else:
			_labels[i].text = _base_texts[i]
			_labels[i].add_theme_font_size_override("font_size", 14)
			_labels[i].add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
