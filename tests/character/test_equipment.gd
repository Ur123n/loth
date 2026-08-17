extends SceneTree

## 装备系统无头测试（有舍有得）：
## 1. 内容校验：每件装备槽位合法、至少一得一舍、mods 解析正确
## 2. 穿/脱接口：槽位占用校验、按槽位卸下
## 3. 属性合并：敏捷/意志力/生命上限/伤害基数/荷载容量
## 4. 存档往返：装备随角色序列化/还原，旧档缺省不崩
## 运行：godot --headless --path C:\游戏 --script tests\character\test_equipment.gd

var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run_all()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _run_all() -> void:
	_ensure_autoload("EquipDB", "res://core/equipment/equipment_database.gd")
	_ensure_autoload("GameState", "res://core/save/game_state.gd")
	_test_content_validation()
	_test_equip_unequip_slots()
	_test_effective_stats()
	_test_save_round_trip()


func _make_character() -> CharacterData:
	var data := CharacterData.new()
	data.character_name = "测试者"
	data.level = 1
	return data


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _test_content_validation() -> void:
	var db: EquipmentDatabase = root.get_node("EquipDB")
	_check(db.equipment.size() >= 6, "EquipDB 至少 6 件装备（当前 %d）" % db.equipment.size())
	for equip in db.equipment:
		var slot_ok := EquipmentData.SLOT_NAMES.has(equip.slot)
		_check(slot_ok, "「%s」槽位合法（%s）" % [equip.equipment_name, equip.slot])
		_check(equip.has_benefit(), "「%s」有收益（得）" % equip.equipment_name)
		_check(equip.has_cost(), "「%s」有代价（舍）" % equip.equipment_name)
	# 修正解析抽查
	var tie_sword: EquipmentData = db.get_equipment("铁剑")
	_check(tie_sword.get_mod_total("attack_damage_pct") == 20, "铁剑：攻击伤害+20%")
	_check(tie_sword.get_mod_total("defend_bonus") == -2, "铁剑：防御卡格挡-2")


func _test_equip_unequip_slots() -> void:
	var data := _make_character()
	_check(data.equip_by_name("铁剑"), "穿铁剑成功")
	_check(data.get_equipped_in_slot("左手武器") != null, "左手武器槽位已占用")
	_check(not data.equip_by_name("铁剑"), "同槽位重复穿失败")
	_check(data.equip_by_name("长枪"), "穿长枪到右手武器成功")
	_check(not data.equip_by_name("长枪"), "同槽位重复穿失败（右手武器）")
	_check(data.equipment.size() == 2, "已穿 2 件装备")
	var removed := data.unequip_slot("左手武器")
	_check(removed != null and removed.equipment_name == "铁剑", "按槽位卸下铁剑")
	_check(data.get_equipped_in_slot("左手武器") == null, "左手武器槽位已空")
	_check(data.equip_by_name("铁剑"), "卸下后可再穿")


func _test_effective_stats() -> void:
	var data := _make_character()
	_check(data.get_max_hp() == 150, "无装备：HP 150（100+10×5）")
	_check(data.equip_by_name("草鞋"), "穿草鞋")
	_check(data.get_effective_agility() == 12, "草鞋：敏捷 10+2=12")
	_check(data.get_max_hp() == 140, "草鞋：生命上限 150-10=140")
	_check(data.unequip_slot("足部") != null, "脱草鞋")
	_check(data.equip_by_name("皮甲"), "穿皮甲")
	_check(data.get_max_hp() == 170, "皮甲：生命上限 150+20=170")
	_check(data.get_equipment_mod_total("move_points") == -1, "皮甲：移动力-1")
	_check(data.unequip_slot("身体") != null, "脱皮甲")
	_check(data.equip_by_name("铜戒指"), "穿铜戒指")
	_check(data.get_effective_willpower() == 8, "铜戒指：意志力 10-2=8")
	_check(data.get_effective_load_capacity() == 8, "铜戒指：荷载容量 8")
	_check(data.unequip_slot("首饰1") != null, "脱铜戒指")
	_check(data.equip_by_name("铁剑"), "穿铁剑")
	_check(data.get_strength_damage_basis() == 120, "铁剑：伤害基数 100→120")


func _test_save_round_trip() -> void:
	var game_state: Node = root.get_node("GameState")
	var data := _make_character()
	data.equip_by_name("铁剑")
	data.equip_by_name("长枪")
	game_state.party_characters = [data]
	var saved: Array = game_state._serialize_party()
	_check(saved.size() == 1, "存档队伍 1 人")
	var entry: Dictionary = saved[0]
	_check(entry.get("equipment", []) == ["铁剑", "长枪"], "装备按名称序列化")
	# 还原到新角色
	var fresh := _make_character()
	game_state.party_characters = [fresh]
	game_state._apply_party(saved)
	_check(fresh.equipment.size() == 2, "读档还原 2 件装备")
	_check(fresh.get_equipped_in_slot("左手武器") != null
			and fresh.get_equipped_in_slot("左手武器").equipment_name == "铁剑", "还原后铁剑在位")
	# 旧档（无 equipment 字段）兼容：不崩且装备为空
	var old_entry := {"name": "测试者", "level": 3, "exp": 0, "attribute_points": 0, "skills": [], "deck": []}
	var old_data := _make_character()
	game_state.party_characters = [old_data]
	game_state._apply_party([old_entry])
	_check(old_data.equipment.is_empty(), "旧档缺省：装备为空")


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		node = load(script_path).new()
		node.name = node_name
		root.add_child(node)
	return node
