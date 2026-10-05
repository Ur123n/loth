class_name AiDebugPanel
extends PanelContainer

## AI 决策调试面板（开发工具）。
## 展示敌怪最近一次 AI 决策：Goal、目标、候选行动评分（含 Utility 分项）、最终选择与原因。
## 打开方式：F4 切换；点击场上任意敌怪查看其决策（需该敌怪已行动过）。

var _title: Label
var _body: RichTextLabel


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.94)
	style.border_color = Color(0.35, 0.75, 1.0, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.50, 0.85, 1.0))
	box.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.custom_minimum_size = Vector2(440, 300)
	_body.add_theme_font_size_override("normal_font_size", 12)
	box.add_child(_body)

	var hint := Label.new()
	hint.text = "F4 关闭　|　点击其他敌怪查看其决策"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
	box.add_child(hint)

	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-464, 46)


## 展示某个单位最近一次的 AI 决策。
func show_decision(unit: BattleUnit, decision: Dictionary) -> void:
	visible = true
	var target: BattleUnit = decision.get("target")
	var target_text := "无"
	var target_threat := 0
	if target != null:
		target_text = target.get_display_name()
		target_threat = EnemyAI.estimate_threat(target)
	_title.text = "AI 决策调试 —— %s（模板：%s）" % [
		unit.get_display_name(), str(decision.get("archetype", ""))]
	var lines: Array[String] = []
	lines.append("当前 Goal：%s" % str(decision.get("goal", "")))
	lines.append("当前目标：%s　威胁估值 %d" % [target_text, target_threat])
	lines.append("最终选择：[color=#7fe07f]%s[/color]　评分 %d" % [
		str(decision.get("action", "等待")), int(decision.get("score", 0))])
	lines.append("原因：%s" % str(decision.get("explain", "")))
	lines.append("")
	lines.append("候选行动（降序）：")
	for c in decision.get("candidates", []):
		var action := str(c.get("action", ""))
		var mark := "▶" if action == str(decision.get("action", "")) else " "
		var component_text := ""
		var comps: Dictionary = c.get("components", {})
		if not comps.is_empty():
			component_text = "　(基础%d 目标%d 位置%d 场景%d 性格%d 紧急%d 随机%d)" % [
				int(comps.get("base", 0)), int(comps.get("target", 0)),
				int(comps.get("position", 0)), int(comps.get("context", 0)),
				int(comps.get("personality", 0)), int(comps.get("urgency", 0)),
				int(comps.get("random", 0))]
		lines.append("%s %s　%4d 分%s　%s" % [
			mark, action, int(c.get("score", 0)), component_text, str(c.get("reason", ""))])
	lines.append("")
	lines.append("移动目标：%s　路径步数：%d" % [
		str(decision.get("move_cell", Vector2i(-1, -1))),
		(decision.get("path", []) as Array).size()])
	_body.text = "\n".join(lines)


## 清空并隐藏。
func clear_panel() -> void:
	visible = false
	_title.text = ""
	_body.text = ""
