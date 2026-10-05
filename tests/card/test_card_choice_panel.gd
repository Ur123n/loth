extends SceneTree

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var host := Node2D.new()
	root.add_child(host)
	var panel := CardChoicePanel.new()
	host.add_child(panel)
	var db := root.get_node("CardDB") as CardDatabase
	var first := db.get_card("陌生页码")
	var second := db.get_card("随手翻找")
	if first == null or second == null:
		push_error("选择面板测试卡牌缺失")
		quit(1)
		return true
	var picked := [-1]
	panel.option_selected.connect(func(index: int) -> void: picked[0] = index)
	panel.show_choices("请选择一张", [first, second])
	var center := panel.get_child(1) as CenterContainer
	var card_panel := center.get_child(0) as PanelContainer
	var layout := card_panel.get_child(0) as VBoxContainer
	var options := layout.get_child(1) as VBoxContainer
	var okay := panel.visible and panel.size.x > 0 and options.get_child_count() == 2
	if okay:
		(options.get_child(1) as Button).pressed.emit()
		okay = picked[0] == 1
	host.free()
	print("RESULT: panel_choice=%s failed=%d" % [str(okay), 0 if okay else 1])
	quit(0 if okay else 1)
	return true
