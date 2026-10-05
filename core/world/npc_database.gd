class_name NpcDatabase
extends Node

## NPC 数据库（Autoload：NpcDB）。
## 读取 res://content/npcs/*.json（由 编辑器/NPC创建.xlsx 同步生成）。

var npcs: Array[NpcData] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	npcs.clear()
	var dir := DirAccess.open("res://content/npcs")
	if dir == null:
		push_warning("NPC 数据目录不存在：res://content/npcs")
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://content/npcs/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			var npc := _parse_npc(parsed)
			if npc != null:
				npcs.append(npc)


func get_npc(npc_name: String) -> NpcData:
	for npc in npcs:
		if npc.npc_name == npc_name:
			return npc
	return null


func _parse_npc(data: Dictionary) -> NpcData:
	var npc := NpcData.new()
	npc.npc_name = str(data.get("name", ""))
	npc.description = str(data.get("description", ""))
	# 美术接口：icon/art/animation 均为 res:// 路径，留空则用色块/文本占位
	npc.icon_path = str(data.get("icon", ""))
	npc.art_path = str(data.get("art", ""))
	npc.animation_path = str(data.get("animation", ""))
	npc.ai_mode = str(data.get("ai", ""))
	var color_str := str(data.get("color", ""))
	if not color_str.is_empty():
		npc.block_color = Color(color_str)
	var interactions = data.get("interaction", [])
	if interactions is Array:
		for option in interactions:
			npc.interaction_options.append(str(option))
	var dialogue = data.get("dialogue", [])
	if dialogue is Array:
		npc.dialogue = dialogue
	var schedule = data.get("schedule", [])
	if schedule is Array:
		npc.schedule = schedule
	return npc
