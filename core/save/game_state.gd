extends Node

## 全局状态（跨场景共享，Autoload）。
## 保存：四人小队数据（技能库、牌组）、大世界位置、光点状态。
## 数据持久化：save_game() / load_game()，默认写入 user://savegame.json。
## 存档为带 version 的字典载荷；load_game() 按版本迁移（旧档缺省字段兼容）。
## v5 新增 story_played（已播放剧情，防重复触发）；
## v4 预留 flags（剧情 Flag）/ quest_state（任务状态）/ world_state（世界状态），空实现缺省安全。
## v6 新增 world_time（世界时钟，小时 0-24，NPC 行动轨迹/时间类任务读取）。
## 启动时为每名角色卡组补足 5 张打击 + 5 张防御（基础牌）。

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 6
const DECK_CAPACITY := 20
const BASIC_STRIKE_NAME := "打击"
const BASIC_DEFEND_NAME := "防御"
const BASIC_STRIKE_COUNT := 5
const BASIC_DEFEND_COUNT := 5

signal flag_changed(key: String, value)

var party_characters: Array = []
var overworld_position: Vector2 = Vector2(616, 480)
var battle_trigger_consumed: bool = false
var skill_light_position: Vector2 = Vector2(496, 408)
var skill_light_consumed: bool = false
var money: int = 0                    # 钱币（战斗结算获得）
var inventory: Inventory = Inventory.new()   # 背包（跨场景共享，战斗结束/拾取时写入）
var demo_mode: bool = false           # 战斗测试 Demo 模式
var demo_battle_number: int = 0       # Demo 已通关战斗数（决定下一场难度/敌怪构成）
var story_played: Array = []          # 已播放剧情 id（随存档持久化，防重复触发）
var story_active: bool = false        # 剧情播放中（运行时状态，不入存档）
var flags: Dictionary = {}            # 剧情 Flag（v4 预留，剧情系统写入）
var quest_state: Dictionary = {}      # 任务状态（v4 预留，任务系统写入：active/done/talked/battles_won）
var world_state: Dictionary = {}      # 世界状态（v4 预留，世界系统写入）
var world_time: float = 8.0           # 世界时钟（小时 0-24，v6；NPC 行动轨迹/时间任务读取）
var save_path: String = SAVE_PATH

var _loaded: bool = false


func setup_party(characters: Array) -> void:
	party_characters = characters


## 剧情是否已播放过（防重复触发；剧情开始播放时即记录）。
func is_story_played(story_id: String) -> bool:
	return story_played.has(story_id)


## 记录剧情已播放并立即写档。
func mark_story_played(story_id: String) -> void:
	if story_id.is_empty() or is_story_played(story_id):
		return
	story_played.append(story_id)
	save_game()


## 通用剧情 Flag 读取。
func get_flag(key: String, default = null):
	return flags.get(key, default)


## 通用剧情 Flag 写入：变化时发 flag_changed 信号（供触发器判定）并立即写档。
func set_flag(key: String, value) -> void:
	if flags.has(key) and flags[key] == value:
		return
	flags[key] = value
	flag_changed.emit(key, value)
	save_game()


## 每名角色卡组补齐：至少 5 打击 + 5 防御，随后用基础牌补齐到 20 张（GDD 第 11 节）。
func ensure_basic_deck_cards() -> void:
	for character in party_characters:
		_ensure_card_count(character, BASIC_STRIKE_NAME, BASIC_STRIKE_COUNT)
		_ensure_card_count(character, BASIC_DEFEND_NAME, BASIC_DEFEND_COUNT)
		_fill_deck_to_capacity(character)
		for basic_name in [BASIC_STRIKE_NAME, BASIC_DEFEND_NAME]:
			if not _skill_has(character, basic_name):
				var basic_skill := SkillData.new()
				basic_skill.skill_name = basic_name
				basic_skill.description = CardDB.describe_card(_card_from_name(basic_name))
				character.skill_library.append(basic_skill)


## 卡组不足 20 张时，用 打击/防御 交替补齐（GDD：初始牌填充）。
func _fill_deck_to_capacity(character: CharacterData) -> void:
	var index := 0
	while character.deck.size() < DECK_CAPACITY:
		var card_name := BASIC_STRIKE_NAME if index % 2 == 0 else BASIC_DEFEND_NAME
		var card := _card_from_name(card_name)
		if card == null:
			break
		character.deck.append(card)
		index += 1


func _ensure_card_count(character: CharacterData, card_name: String, count: int) -> void:
	var current := 0
	for card in character.deck:
		if card.card_name == card_name:
			current += 1
	var missing := count - current
	for i in missing:
		var card := _card_from_name(card_name)
		if card != null:
			character.deck.append(card)


## 道途系统实装：按角色名匹配道途（PathDB），设置角色道途，
## 并把道途专属初始牌加入技能库（SkillData）与战斗卡组。
## 幂等：已存在的不重复添加；旧档/新档均可安全调用。
func apply_path_system() -> void:
	var path_db := get_node_or_null("/root/PathDB")
	if path_db == null:
		return
	for character in party_characters:
		if not character is CharacterData:
			continue
		var path_data: PathData = path_db.get_path_for_character(character.character_name)
		if path_data == null:
			continue
		if character.path_name.is_empty():
			character.path_name = path_data.path_name
		for card_name in path_data.starter_cards:
			var card := _card_from_name(card_name)
			if card == null or card.card_name.is_empty():
				continue
			if not _skill_has(character, card_name):
				var skill := SkillData.new()
				skill.skill_name = card_name
				skill.description = CardDB.describe_card(card)
				character.skill_library.append(skill)
			if not _deck_has(character, card_name) and character.deck.size() < DECK_CAPACITY:
				character.deck.append(card)


func _skill_has(character: CharacterData, skill_name: String) -> bool:
	for skill in character.skill_library:
		if skill.skill_name == skill_name:
			return true
	return false


func _deck_has(character: CharacterData, card_name: String) -> bool:
	for card in character.deck:
		if card.card_name == card_name:
			return true
	return false


## 增加钱币并立即写档。
func add_money(amount: int) -> void:
	money = maxi(money + amount, 0)
	save_game()


## 推进世界时钟：每秒 real_seconds × rate 游戏分钟；超过 24 小时回绕（0-24）。
func advance_world_time(real_seconds: float, rate: float = 1.0) -> void:
	world_time = fmod(world_time + real_seconds * rate / 60.0, 24.0)
	if world_time < 0.0:
		world_time += 24.0


## 任务状态读写（统一经 GameState 持久化，不新建存档通道）。
func set_quest_state(key: String, value) -> void:
	quest_state[key] = value
	save_game()


func get_quest_state(key: String, default = null):
	return quest_state.get(key, default)


## 获得经验（全队 4 名角色共享同一份战斗经验）。
func grant_battle_exp(amount: int) -> int:
	var total_levels := 0
	for character in party_characters:
		if character is CharacterData:
			total_levels += character.gain_exp(amount)
	save_game()
	return total_levels


## 写入存档：版本化载荷（大世界位置/触发状态/钱币/背包/队伍/预留状态字段）。
func save_game() -> void:
	# 兜底：父目录不存在时先创建（自定义存档路径/测试临时目录均可用）
	var dir_path := save_path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var data := {
		"version": SAVE_VERSION,
		"overworld_position": [overworld_position.x, overworld_position.y],
		"battle_trigger_consumed": battle_trigger_consumed,
		"skill_light_position": [skill_light_position.x, skill_light_position.y],
		"skill_light_consumed": skill_light_consumed,
		"money": money,
		"inventory": inventory.serialize(),
		"party": _serialize_party(),
		"story_played": story_played,
		"flags": flags,
		"quest_state": quest_state,
		"world_state": world_state,
		"world_time": world_time,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("存档写入失败：%s" % save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## 启动时读取存档并恢复到当前小队角色上（只执行一次）。
func load_game() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var version := int(parsed.get("version", 0))
	parsed = _migrate_save_data(parsed, version)
	var pos = parsed.get("overworld_position", [])
	if pos is Array and pos.size() >= 2:
		overworld_position = Vector2(float(pos[0]), float(pos[1]))
	battle_trigger_consumed = bool(parsed.get("battle_trigger_consumed", false))
	var light_pos = parsed.get("skill_light_position", [])
	if light_pos is Array and light_pos.size() >= 2:
		skill_light_position = Vector2(float(light_pos[0]), float(light_pos[1]))
	skill_light_consumed = bool(parsed.get("skill_light_consumed", false))
	money = maxi(int(parsed.get("money", 0)), 0)
	inventory.deserialize(parsed.get("inventory", []))
	_apply_party(parsed.get("party", []))
	var played = parsed.get("story_played", [])
	story_played = []
	if played is Array:
		for story_id in played:
			story_played.append(str(story_id))
	flags = _as_dict(parsed.get("flags", {}))
	quest_state = _as_dict(parsed.get("quest_state", {}))
	world_state = _as_dict(parsed.get("world_state", {}))
	world_time = float(parsed.get("world_time", 8.0))


## 存档迁移：旧档缺省新增字段，保证可读；未来版本升级在此补字段。
## 规则：只补缺省值，不破坏已有字段；新字段缺省安全（空字典/默认值）。
func _migrate_save_data(data: Dictionary, version: int) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	if version < 4:
		if not result.has("battle_trigger_consumed"):
			result["battle_trigger_consumed"] = false
		if not result.has("skill_light_position"):
			result["skill_light_position"] = [skill_light_position.x, skill_light_position.y]
		if not result.has("flags"):
			result["flags"] = {}
		if not result.has("quest_state"):
			result["quest_state"] = {}
		if not result.has("world_state"):
			result["world_state"] = {}
	if version < 5:
		if not result.has("story_played"):
			result["story_played"] = []
	if version < 6:
		if not result.has("world_time"):
			result["world_time"] = world_time
	return result


func _as_dict(value) -> Dictionary:
	return value if value is Dictionary else {}


func _serialize_party() -> Array:
	var result: Array = []
	for character in party_characters:
		var entry := {"name": character.character_name, "level": character.level,
			"exp": character.exp, "attribute_points": character.attribute_points,
			"skills": [], "deck": [], "equipment": []}
		for skill in character.skill_library:
			entry["skills"].append({"name": skill.skill_name, "description": skill.description})
		for card in character.deck:
			entry["deck"].append(card.card_name)
		for equip in character.equipment:
			if equip is EquipmentData:
				entry["equipment"].append(equip.equipment_name)
		result.append(entry)
	return result


func _apply_party(saved_party: Array) -> void:
	for entry in saved_party:
		if not entry is Dictionary:
			continue
		var saved_name := str(entry.get("name", ""))
		for character in party_characters:
			if character.character_name != saved_name:
				continue
			# 旧存档无 level 字段时保留 .tres 中的初始等级
			character.level = maxi(int(entry.get("level", character.level)), 0)
			character.exp = maxi(int(entry.get("exp", 0)), 0)
			character.attribute_points = maxi(int(entry.get("attribute_points", 0)), 0)
			character.skill_library.clear()
			for skill_data in entry.get("skills", []):
				if not skill_data is Dictionary:
					continue
				var skill := SkillData.new()
				skill.skill_name = str(skill_data.get("name", ""))
				skill.description = str(skill_data.get("description", ""))
				character.skill_library.append(skill)
			character.deck.clear()
			for card_name in entry.get("deck", []):
				var card := _card_from_name(str(card_name))
				if card != null:
					character.deck.append(card)
			# 装备（v3）：按名称从 EquipDB 还原；旧存档缺省为空
			character.equipment.clear()
			var equip_db := get_node_or_null("/root/EquipDB")
			for equip_name in entry.get("equipment", []):
				var equip: EquipmentData = equip_db.get_equipment(str(equip_name)) if equip_db != null else null
				if equip != null:
					character.equipment.append(equip)
			break


## 按名称从卡牌数据库取卡；取不到时用名称构造兜底卡（效果后续补充）。
func _card_from_name(card_name: String) -> CardData:
	if card_name.is_empty():
		return null
	var card: CardData = null
	if is_inside_tree() and has_node("/root/CardDB"):
		card = get_node("/root/CardDB").get_card(card_name)
	if card == null:
		card = CardData.new()
		card.card_name = card_name
	return card
