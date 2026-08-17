extends Node

## 全局状态（跨场景共享，Autoload）。
## 保存：四人小队数据（技能库、牌组）、大世界位置、光点状态。
## 数据持久化：save_game() / load_game()，默认写入 user://savegame.json。
## 启动时为每名角色卡组补足 5 张打击 + 5 张防御（基础牌）。

const SAVE_PATH := "user://savegame.json"
const DECK_CAPACITY := 20
const BASIC_STRIKE_NAME := "打击"
const BASIC_DEFEND_NAME := "防御"
const BASIC_STRIKE_COUNT := 5
const BASIC_DEFEND_COUNT := 5

var party_characters: Array = []
var overworld_position: Vector2 = Vector2(640, 360)
var battle_trigger_consumed: bool = false
var skill_light_position: Vector2 = Vector2(260, 180)
var skill_light_consumed: bool = false
var money: int = 0                    # 钱币（战斗结算获得）
var inventory: Inventory = Inventory.new()   # 背包（跨场景共享，战斗结束/拾取时写入）
var demo_mode: bool = false           # 战斗测试 Demo 模式
var demo_battle_number: int = 0       # Demo 已通关战斗数（决定下一场难度/敌怪构成）
var save_path: String = SAVE_PATH

var _loaded: bool = false


func setup_party(characters: Array) -> void:
	party_characters = characters


## 每名角色卡组补齐：至少 5 打击 + 5 防御，随后用基础牌补齐到 20 张（GDD 第 11 节）。
func ensure_basic_deck_cards() -> void:
	for character in party_characters:
		_ensure_card_count(character, BASIC_STRIKE_NAME, BASIC_STRIKE_COUNT)
		_ensure_card_count(character, BASIC_DEFEND_NAME, BASIC_DEFEND_COUNT)
		_fill_deck_to_capacity(character)


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


## 获得经验（全队 4 名角色共享同一份战斗经验）。
func grant_battle_exp(amount: int) -> int:
	var total_levels := 0
	for character in party_characters:
		if character is CharacterData:
			total_levels += character.gain_exp(amount)
	save_game()
	return total_levels


## 写入存档：大世界位置、光点状态、各角色技能库与牌组。
func save_game() -> void:
	var data := {
		"version": 2,
		"overworld_position": [overworld_position.x, overworld_position.y],
		"skill_light_consumed": skill_light_consumed,
		"money": money,
		"inventory": inventory.serialize(),
		"party": _serialize_party(),
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
	var pos = parsed.get("overworld_position", [])
	if pos is Array and pos.size() >= 2:
		overworld_position = Vector2(float(pos[0]), float(pos[1]))
	skill_light_consumed = bool(parsed.get("skill_light_consumed", false))
	money = maxi(int(parsed.get("money", 0)), 0)
	inventory.deserialize(parsed.get("inventory", []))
	_apply_party(parsed.get("party", []))


func _serialize_party() -> Array:
	var result: Array = []
	for character in party_characters:
		var entry := {"name": character.character_name, "level": character.level,
			"exp": character.exp, "attribute_points": character.attribute_points,
			"skills": [], "deck": []}
		for skill in character.skill_library:
			entry["skills"].append({"name": skill.skill_name, "description": skill.description})
		for card in character.deck:
			entry["deck"].append(card.card_name)
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
