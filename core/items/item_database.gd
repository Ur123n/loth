class_name ItemDatabase
extends Node

## 物品数据库（Autoload：ItemDB）。
## 读取 res://content/items/*.json（由 编辑器/物品创建.xlsx 同步生成）。

var items: Array[ItemData] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	items.clear()
	var dir := DirAccess.open("res://content/items")
	if dir == null:
		push_warning("物品数据目录不存在：res://content/items")
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://content/items/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			var item := _parse_item(parsed)
			if item != null:
				items.append(item)


func get_item(item_name: String) -> ItemData:
	for item in items:
		if item.item_name == item_name:
			return item
	return null


func _parse_item(data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.item_name = str(data.get("name", ""))
	item.description = str(data.get("description", ""))
	item.shape = str(data.get("shape", "1x1"))
	item.value = int(data.get("value", 0))
	# 美术接口：icon/art/animation 均为 res:// 路径，留空则用色块/文本占位
	item.icon_path = str(data.get("icon", ""))
	item.art_path = str(data.get("art", ""))
	item.animation_path = str(data.get("animation", ""))
	return item
