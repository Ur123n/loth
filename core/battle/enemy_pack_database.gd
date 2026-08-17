class_name EnemyPackDatabase
extends Node

## 敌方小队表（Autoload：EnemyPackDB）。
## 读取 res://content/encounters/enemy_packs.json（由 编辑器/敌怪小队创建.xlsx 同步生成）。
## 每支小队由 3~4 只相互配合的敌怪组成，按强度（普通/精英/Boss）分类；
## 战斗时从符合强度的若干小队中随机抽取一支（DemoComposer / battle_map 使用）。

var packs: Array[Dictionary] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	packs.clear()
	var file := FileAccess.open("res://content/encounters/enemy_packs.json", FileAccess.READ)
	if file == null:
		push_warning("敌方小队表不存在：res://content/encounters/enemy_packs.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var raw_packs = parsed.get("packs", [])
		if raw_packs is Array:
			for pack in raw_packs:
				if pack is Dictionary:
					packs.append(pack)


func get_packs_by_tier(tier: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pack in packs:
		if str(pack.get("tier", "")) == tier:
			result.append(pack)
	return result


## 从符合强度的若干小队中随机抽取一支；无匹配时返回空字典。
func random_pack(tier: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var candidates := get_packs_by_tier(tier)
	if candidates.is_empty():
		return {}
	var r := rng if rng != null else RandomNumberGenerator.new()
	return candidates[r.randi_range(0, candidates.size() - 1)]


## 把小队成员展开为带角色/首领标记的单位条目（按 count 复制；未知敌怪跳过）。
## 每项：{"enemy": EnemyData, "role": String, "leader": bool}。
func pack_member_entries(pack: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if pack.is_empty():
		return result
	var members = pack.get("members", [])
	if not members is Array:
		return result
	var db := _get_enemy_db()
	if db == null:
		return result
	for member in members:
		if not member is Dictionary:
			continue
		var enemy: EnemyData = db.get_enemy(str(member.get("enemy", "")))
		if enemy == null:
			continue
		var count := maxi(int(member.get("count", 1)), 1)
		var role := str(member.get("role", ""))
		var is_leader := bool(member.get("leader", false))
		for i in count:
			result.append({"enemy": enemy, "role": role, "leader": is_leader})
	return result


## 展开为敌怪数据数组（测试/兜底用，不含角色信息）。
func resolve_pack(pack: Dictionary) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for entry in pack_member_entries(pack):
		result.append(entry.get("enemy") as EnemyData)
	return result


static func _get_enemy_db() -> EnemyDatabase:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EnemyDB") as EnemyDatabase
	return null
