class_name DemoComposer
extends RefCounted

## 战斗测试 Demo 的战役构成器。
## 固定流程（共 6 场）：普通 ×2 → 精英 ×1 → 普通 ×2 → Boss ×1。
## 普通：2~3 只普通怪；精英：1 精英 + 1~2 普通随从；Boss：1 Boss + 1~2 随从。

const BATTLE_TIERS: Array[String] = ["普通", "普通", "精英", "普通", "普通", "Boss"]


static func total_battles() -> int:
	return BATTLE_TIERS.size()


## 第 battle_number 场（1 开始）的难度。
static func battle_tier(battle_number: int) -> String:
	var index := clampi(battle_number - 1, 0, BATTLE_TIERS.size() - 1)
	return BATTLE_TIERS[index]


static func compose_battle(battle_number: int, rng: RandomNumberGenerator = null) -> Array[EnemyData]:
	var r := rng if rng != null else RandomNumberGenerator.new()
	var tier := battle_tier(battle_number)
	# 优先：从敌怪小队表按强度随机抽取一支 3~4 人小队
	var pack_db := _get_pack_db()
	if pack_db != null:
		var pack := pack_db.random_pack(tier, r)
		if not pack.is_empty():
			var resolved := pack_db.resolve_pack(pack)
			if not resolved.is_empty():
				return resolved
	# 兜底：无小队表/该强度无匹配小队时，沿用旧的按难度随机拼怪
	return _compose_legacy(tier, r)


## 旧版随机拼怪（小队表缺失时的兜底）。
static func _compose_legacy(tier: String, r: RandomNumberGenerator) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	match tier:
		"Boss":
			var boss := _pick_tier(["Boss"], r)
			if boss != null:
				result.append(boss)
			for i in 1 + r.randi_range(0, 1):
				var minion := _pick_tier(["普通", "精英"], r)
				if minion != null:
					result.append(minion)
		"精英":
			var elite := _pick_tier(["精英"], r)
			if elite != null:
				result.append(elite)
			for i in 1 + r.randi_range(0, 1):
				var minion := _pick_tier(["普通"], r)
				if minion != null:
					result.append(minion)
		_:
			for i in 2 + r.randi_range(0, 1):
				var enemy := _pick_tier(["普通"], r)
				if enemy != null:
					result.append(enemy)
	return result


static func _get_pack_db() -> EnemyPackDatabase:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EnemyPackDB") as EnemyPackDatabase
	return null


## 从敌怪库按难度随机取一只（排除训练木桩）。
static func _pick_tier(tier_pool, rng: RandomNumberGenerator) -> EnemyData:
	var db := _get_enemy_db()
	if db == null:
		return null
	var wanted: Array[String] = []
	if tier_pool is String:
		wanted.append(tier_pool)
	else:
		for tier in tier_pool:
			wanted.append(str(tier))
	var pool: Array[EnemyData] = []
	for enemy in db.enemies:
		if enemy.enemy_name == "木桩":
			continue
		if wanted.has(enemy.tier):
			pool.append(enemy)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _get_enemy_db() -> EnemyDatabase:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EnemyDB") as EnemyDatabase
	return null
