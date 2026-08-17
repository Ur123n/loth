class_name BuffDatabase
extends Node

## buff 数据库（Autoload：BuffDB）。
## 读取 res://content/buffs/*.json（由 编辑器/buff创建.xlsx 同步生成）。

var buffs: Array[BuffData] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	buffs.clear()
	var dir := DirAccess.open("res://content/buffs")
	if dir == null:
		push_warning("buff 数据目录不存在：res://content/buffs")
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://content/buffs/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			var buff := _parse_buff(parsed)
			if buff != null:
				buffs.append(buff)


func get_buff(buff_name: String) -> BuffData:
	for buff in buffs:
		if buff.buff_name == buff_name:
			return buff
	return null


func _parse_buff(data: Dictionary) -> BuffData:
	var buff := BuffData.new()
	buff.buff_name = str(data.get("name", ""))
	buff.alignment = str(data.get("alignment", "中立"))
	buff.buff_type = str(data.get("type", "持续"))
	buff.value = int(data.get("value", 0))
	buff.base_duration = int(data.get("base_duration", 1))
	buff.duration_per_stack = int(data.get("duration_per_stack", 0))
	buff.decay_per_turn = _parse_bool(data.get("decay_per_turn", false))
	buff.decay_amount = int(data.get("decay_amount", 1))
	buff.consumed_on_trigger = _parse_bool(data.get("consumed_on_trigger", false))
	buff.trigger_timing = str(data.get("trigger_timing", ""))
	buff.trigger_condition = str(data.get("trigger_condition", ""))
	buff.description = str(data.get("description", ""))
	# 美术接口：icon/art/animation 均为 res:// 路径，留空则用文本/占位
	buff.icon_path = str(data.get("icon", ""))
	buff.art_path = str(data.get("art", ""))
	buff.animation_path = str(data.get("animation", ""))
	return buff


## 兼容 JSON 布尔（true/false）与表格文本（是/否）。
func _parse_bool(value, default_value: bool = false) -> bool:
	if value is bool:
		return value
	return str(value) == "是"
