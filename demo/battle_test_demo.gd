extends Node

## 战斗测试 Demo 启动器：配置四人小队（道途 + 专属初始牌 + 基础牌），
## 直接进入第一场随机战斗。Demo 使用独立存档（user://demo_save.json），不影响正式档。

const CHARACTER_FILES := ["alice", "baldwin", "dismas", "kasha"]


func _ready() -> void:
	GameState.demo_mode = true
	GameState.demo_battle_number = 0
	GameState.money = 0
	GameState.inventory.clear()
	GameState.save_path = "user://demo_save.json"

	var party: Array = []
	for stem in CHARACTER_FILES:
		var base := load("res://content/characters/%s.tres" % stem) as CharacterData
		if base == null:
			continue
		# 深拷贝：demo 的加点/重置不污染 .tres 缓存资源；通关重开即恢复基础属性
		var data := base.duplicate(true) as CharacterData
		_reset_demo_character(data)
		party.append(data)
	GameState.setup_party(party)
	GameState.apply_path_system()         # 道途系统：path_name + 专属初始牌进技能库/卡组
	GameState.ensure_basic_deck_cards()   # 卡组补齐：基础牌补齐到 20 张
	GameState.save_game()
	# 延迟切换：_ready 中直接切换会与节点树操作冲突
	get_tree().call_deferred("change_scene_to_file", "res://world/encounters/BattleMap.tscn")


## 每次启动 Demo 都重置为 Lv1、空经验、空牌组（保持可重复测试）。
func _reset_demo_character(character: CharacterData) -> void:
	character.level = 1
	character.exp = 0
	character.attribute_points = 0
	character.path_name = ""
	character.deck.clear()
	character.skill_library.clear()



