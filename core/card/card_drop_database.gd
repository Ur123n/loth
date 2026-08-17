class_name CardDropTable
extends Node

## 卡牌掉落表（Autoload：CardDropDB）。
## 读取 res://content/cards/card_drops.json（Demo 敌怪专用卡牌掉落表，正式战斗不使用）。
## 结构：{"普通": {"chance": 50, "count": 1}, "精英": {...}, "Boss": {...}}
## chance = 每名角色独立掷骰的掉落概率（1-100）；count = 该难度下每名角色可“三选一”的次数。

var drops: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	drops.clear()
	var file := FileAccess.open("res://content/cards/card_drops.json", FileAccess.READ)
	if file == null:
		push_warning("卡牌掉落表不存在：res://content/cards/card_drops.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		drops = parsed


func get_drop(tier: String) -> Dictionary:
	var entry = drops.get(tier, {})
	return entry if entry is Dictionary else {}

