class_name CardChoicePanel
extends Control

signal option_selected(index: int)

var _title: Label
var _options: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 180)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	layout.add_child(_title)
	_options = VBoxContainer.new()
	layout.add_child(_options)


func _resize_to_viewport() -> void:
	size = get_viewport_rect().size


func show_choices(prompt: String, cards: Array) -> void:
	_title.text = prompt
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for i in cards.size():
		var card := cards[i] as CardData
		var button := Button.new()
		button.custom_minimum_size = Vector2(440, 58)
		button.text = "%s　费用 %d\n%s" % [card.card_name, card.cost, CardDatabase.describe_card(card)]
		button.pressed.connect(_on_option_pressed.bind(i))
		_options.add_child(button)
	visible = true


func _on_option_pressed(index: int) -> void:
	option_selected.emit(index)
