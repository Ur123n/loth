class_name EnemyDatabase
extends Node

## 敌怪数据库（Autoload：EnemyDB）。
## 读取 res://content/enemies/*.json（由 编辑器/敌怪创建.xlsx 同步生成）。

var enemies: Array[EnemyData] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	enemies.clear()
	var dir := DirAccess.open("res://content/enemies")
	if dir == null:
		push_warning("敌怪目录不存在：res://content/enemies")
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://content/enemies/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			var enemy := _parse_enemy(parsed)
			if enemy != null:
				enemies.append(enemy)


func get_enemy(enemy_name: String) -> EnemyData:
	for enemy in enemies:
		if enemy.enemy_name == enemy_name:
			return enemy
	return null


func _parse_enemy(data: Dictionary) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.enemy_name = str(data.get("name", ""))
	enemy.hp_min = int(data.get("hp_min", 100))
	enemy.hp_max = int(data.get("hp_max", 100))
	enemy.attack_min = int(data.get("attack_min", 0))
	enemy.attack_max = int(data.get("attack_max", 0))
	enemy.attack_range = int(data.get("attack_range", 1))
	enemy.move_points = int(data.get("move_points", 0))
	enemy.agility = int(data.get("agility", 5))
	enemy.ai_mode = str(data.get("ai", "无"))
	enemy.archetype = str(data.get("archetype", ""))
	enemy.ai_profile = _parse_dict(data.get("ai_profile", ""))
	var raw_skills = data.get("skills", [])
	enemy.skills = raw_skills if raw_skills is Array else []
	enemy.tier = str(data.get("tier", "普通"))
	enemy.coin_min = int(data.get("coin_min", 0))
	enemy.coin_max = int(data.get("coin_max", 0))
	enemy.exp = int(data.get("exp", 0))
	var raw_loot = data.get("loot_table", [])
	enemy.loot_table = raw_loot if raw_loot is Array else []
	enemy.description = str(data.get("description", ""))
	# 美术接口：路径留空时使用对应占位表现。
	enemy.icon_path = str(data.get("icon", ""))
	enemy.art_path = str(data.get("art", ""))
	enemy.animation_path = str(data.get("animation", ""))
	enemy.corpse_art_a_path = str(data.get("corpse_art_a", ""))
	enemy.corpse_art_b_path = str(data.get("corpse_art_b", ""))
	var color_str := str(data.get("color", ""))
	if not color_str.is_empty():
		enemy.block_color = Color(color_str)
	return enemy


## 解析 ai_profile 列：接受 JSON 对象字符串或直接字典（缺省/空返回 {}）。
func _parse_dict(value) -> Dictionary:
	if value is Dictionary:
		return value
	if value is String and not (value as String).is_empty():
		var parsed = JSON.parse_string(value)
		if parsed is Dictionary:
			return parsed
	return {}
