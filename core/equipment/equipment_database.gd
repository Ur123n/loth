class_name EquipmentDatabase
extends Node

## 装备数据库（Autoload：EquipDB）。
## 读取 res://content/equipment/*.json（由 编辑器/装备创建.xlsx 同步生成）。

var equipment: Array[EquipmentData] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	equipment.clear()
	var dir := DirAccess.open("res://content/equipment")
	if dir == null:
		push_warning("装备数据目录不存在：res://content/equipment")
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://content/equipment/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			var item := EquipmentData.new()
			item.equipment_name = str(parsed.get("name", ""))
			item.slot = str(parsed.get("slot", ""))
			item.description = str(parsed.get("description", ""))
			# 美术接口：icon/art/animation 均为 res:// 路径，留空则用文本/占位
			item.icon_path = str(parsed.get("icon", ""))
			item.art_path = str(parsed.get("art", ""))
			item.animation_path = str(parsed.get("animation", ""))
			# 有舍有得修正列表：[{type, value, stat?}]，旧数据缺省为空
			var parsed_mods = parsed.get("mods", [])
			if parsed_mods is Array:
				for mod in parsed_mods:
					if mod is Dictionary:
						item.mods.append({
							"type": str(mod.get("type", "")),
							"value": int(mod.get("value", 0)),
							"stat": str(mod.get("stat", "")),
						})
			equipment.append(item)


func get_equipment(item_name: String) -> EquipmentData:
	for item in equipment:
		if item.equipment_name == item_name:
			return item
	return null
