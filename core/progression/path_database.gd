class_name PathDatabase
extends Node

## 道途数据库（Autoload：PathDB）。
## 读取 res://content/paths/*.json（由 编辑器/道途创建.xlsx 同步生成）。

var paths: Array[PathData] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	paths.clear()
	var dir := DirAccess.open("res://content/paths")
	if dir == null:
		push_warning("道途数据目录不存在：res://content/paths")
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://content/paths/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			var path_data := _parse_path(parsed)
			if path_data != null:
				paths.append(path_data)


func get_path_data(path_name: String) -> PathData:
	for path_data in paths:
		if path_data.path_name == path_name:
			return path_data
	return null


## 按归属角色名查找道途（角色 → 道途）。
func get_path_for_character(character_name: String) -> PathData:
	for path_data in paths:
		if path_data.character_name == character_name:
			return path_data
	return null


func _parse_path(data: Dictionary) -> PathData:
	var path_data := PathData.new()
	path_data.path_name = str(data.get("name", ""))
	path_data.character_name = str(data.get("character", ""))
	path_data.description = str(data.get("description", ""))
	var raw_cards = data.get("starter_cards", [])
	path_data.starter_cards.clear()
	if raw_cards is Array:
		for card_name in raw_cards:
			path_data.starter_cards.append(str(card_name))
	path_data.icon_path = str(data.get("icon", ""))
	path_data.art_path = str(data.get("art", ""))
	path_data.animation_path = str(data.get("animation", ""))
	var passive_data = data.get("passive", {})
	if passive_data is Dictionary:
		var passive := PassiveData.new()
		passive.passive_name = str(passive_data.get("name", ""))
		passive.description = str(passive_data.get("description", ""))
		passive.trigger_timing = str(passive_data.get("trigger_timing", ""))
		passive.value = int(passive_data.get("value", 0))
		path_data.passive = passive
	return path_data
