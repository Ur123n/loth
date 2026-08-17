extends SceneTree

## 卡牌重平衡无头测试：
## 梦境链（沉梦→幻梦解锁灾梦）、幻梦无视护甲、伺机/击退标记、buff 层数、
## 肾上腺素透支延迟、重平衡数值与衍生牌标记。
## 运行：godot --headless --path C:\游戏 --script tests\card\test_card_rebalance.gd

var _card_db: CardDatabase
var _cards_by_name: Dictionary = {}
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
	_setup_card_db()
	_test_rebalance_parse()
	_test_dream_chain()
	_test_phantom_pierce()
	_test_flank_knockback()
	_test_buff_stacks()
	_test_adrenaline_overdraft()


func _setup_card_db() -> void:
	var db_node: Node = root.get_node_or_null("CardDB")
	if db_node == null:
		var db := CardDatabase.new()
		db.name = "CardDB"
		root.add_child(db)
		db_node = db
	_card_db = db_node as CardDatabase
	for card in _card_db.cards:
		_cards_by_name[card.card_name] = card


func _make_unit(deck: Array) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_enemy = false
	var char_data := CharacterData.new()
	char_data.character_name = "测试者"
	char_data.deck.clear()
	for c in deck:
		char_data.deck.append(c)
	unit.character_data = char_data
	unit.current_hp = 100
	return unit


func _make_manager(unit: BattleUnit) -> BattleManager:
	var manager := BattleManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260812
	var units: Array[BattleUnit] = [unit]
	manager.setup(units, rng, func(name: String) -> CardData:
		return _cards_by_name.get(name))
	manager.turn_system.action_order = [0]
	manager.turn_system.current_index = 0
	return manager


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _test_rebalance_parse() -> void:
	var xiao_dao: CardData = _cards_by_name.get("小刀")
	_check(xiao_dao != null and xiao_dao.derived, "小刀：衍生标记")
	var chen_meng: CardData = _cards_by_name.get("沉梦之拥")
	_check(chen_meng != null and chen_meng.dream, "沉梦之拥：沉梦词条")
	var defense := chen_meng.effects[0] as DefenseEffect
	var heal := chen_meng.effects[1] as BuffEffect
	_check(defense != null and defense.value == 5, "沉梦之拥：1费5防")
	_check(heal != null and heal.stacks == 2, "沉梦之拥：疗愈2层")
	var huan_meng: CardData = _cards_by_name.get("幻梦利爪")
	_check(huan_meng != null and huan_meng.phantom, "幻梦利爪：幻梦词条")
	var zhong_yan: CardData = _cards_by_name.get("终焉之梦")
	var zy_attack := zhong_yan.effects[0] as AttackEffect
	_check(zhong_yan != null and zhong_yan.doom_dream and zy_attack.value == 64, "终焉之梦：灾梦+64伤")
	var shuang_qiang: CardData = _cards_by_name.get("双枪连射")
	var sq_attack := shuang_qiang.effects[0] as AttackEffect
	_check(sq_attack != null and sq_attack.value == 4 and sq_attack.attack_range == 2, "双枪连射：4×2 射程2")
	var shou_shu: CardData = _cards_by_name.get("手术刀")
	var ss_attack := shou_shu.effects[0] as AttackEffect
	_check(ss_attack != null and ss_attack.value == 6, "手术刀：6伤")
	var shan_bi: CardData = _cards_by_name.get("闪避")
	var sb_defense := shan_bi.effects[0] as DefenseEffect
	_check(sb_defense != null and sb_defense.value == 5, "闪避：+3防（5防）")
	var lie_nu: CardData = _cards_by_name.get("烈怒")
	var ln_attack := lie_nu.effects[0] as AttackEffect
	_check(ln_attack != null and ln_attack.value == 6, "烈怒：6伤")
	var ju_li: CardData = _cards_by_name.get("巨力猛击")
	var has_knock := ju_li.effects.any(func(e): return e is KnockbackEffect)
	var has_move := ju_li.effects.any(func(e): return e is MoveEffect)
	var jl_attack := ju_li.effects[0] as AttackEffect
	_check(has_knock and has_move and jl_attack.value == 18, "巨力猛击：18伤+移动1+击退1")
	var shun_shou: CardData = _cards_by_name.get("顺手牵羊")
	var ss_flank := shun_shou.effects[0] as FlankEffect
	_check(ss_flank != null and ss_flank.value == 7, "顺手牵羊：伺机7伤")
	var qiang_du: CardData = _cards_by_name.get("强效毒剂")
	var qd_buff := qiang_du.effects[0] as BuffEffect
	_check(qd_buff != null and qd_buff.buff_type == "中毒" and qd_buff.stacks == 5 and qd_buff.duration == 5 \
			and not qiang_du.effects.any(func(e): return e is AttackEffect), "强效毒剂：中毒5层（无伤害）")
	var bao_za: CardData = _cards_by_name.get("包扎")
	var bz_buff := bao_za.effects[0] as BuffEffect
	_check(bz_buff != null and bz_buff.buff_type == "疗愈" and bz_buff.stacks == 3, "包扎：疗愈3层")
	var ji_jiu: CardData = _cards_by_name.get("急救包")
	var jj_buff := ji_jiu.effects[1] as BuffEffect
	_check(jj_buff != null and jj_buff.buff_type == "疗愈" and jj_buff.stacks == 1, "急救包：疗愈1层（不变）")
	var xing_fen: CardData = _cards_by_name.get("兴奋药剂")
	var xf_buff := xing_fen.effects[0] as BuffEffect
	_check(xf_buff != null and xf_buff.buff_type == "疗愈" and xf_buff.stacks == 3, "兴奋药剂：疗愈3层")
	_check(not _cards_by_name.has("侦察"), "侦察已删除")
	_check(not _cards_by_name.has("圣辉"), "圣辉已删除")
	for name in ["突袭", "后撤", "迂回", "疾风步", "夹击", "坚守", "游走", "拦截"]:
		_check(_cards_by_name.has(name), "移动卡入库：%s" % name)
	var shou_xing: CardData = _cards_by_name.get("兽性觉醒")
	var sx_attack := shou_xing.effects[0] as AttackEffect
	_check(shou_xing != null and shou_xing.cost == 2 and shou_xing.load == 2 \
			and sx_attack != null and sx_attack.value == 8, "兽性觉醒：2费2荷载打8")
	_check(shou_xing.lifesteal and shou_xing.keyword_labels().has("吸血") \
			and shou_xing.effects.size() == 1, "兽性觉醒：吸血词条（原疗愈效果移除）")


func _test_dream_chain() -> void:
	var chen_meng: CardData = _cards_by_name.get("沉梦之拥")
	var huan_meng: CardData = _cards_by_name.get("幻梦利爪")
	var zhong_yan: CardData = _cards_by_name.get("终焉之梦")
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	var enemy := _make_unit([])
	enemy.is_enemy = true
	enemy.current_hp = 100
	unit.energy = 10
	unit.hand = [zhong_yan, chen_meng, huan_meng]
	# 未解锁：灾梦无法打出
	manager.play_card(zhong_yan, enemy)
	_check(unit.dream_progress == 0 and unit.hand.has(zhong_yan), "灾梦未解锁时无法打出")
	# 沉梦 → 幻梦 → 灾梦
	manager.play_card(chen_meng, null)
	_check(unit.dream_progress == 1, "打出沉梦牌：梦境进度 1")
	manager.play_card(zhong_yan, enemy)
	_check(unit.hand.has(zhong_yan), "仅沉梦时灾梦仍锁定")
	manager.play_card(huan_meng, enemy)
	_check(unit.dream_progress == 2, "沉梦→幻梦顺序完成：梦境进度 2")
	manager.play_card(zhong_yan, enemy)
	_check(not unit.hand.has(zhong_yan), "灾梦解锁后可打出")
	_check(enemy.current_hp <= 36, "终焉之梦造成 64 伤（敌方 HP ≤ 36）")


func _test_phantom_pierce() -> void:
	var chen_meng: CardData = _cards_by_name.get("沉梦之拥")
	var huan_meng: CardData = _cards_by_name.get("幻梦利爪")
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	var enemy := _make_unit([])
	enemy.is_enemy = true
	enemy.current_hp = 100
	enemy.block_value = 50
	unit.energy = 10
	unit.hand = [chen_meng, huan_meng]
	manager.play_card(chen_meng, null)
	manager.play_card(huan_meng, enemy)
	_check(enemy.current_hp == 94 and enemy.block_value == 50, "幻梦（上张为沉梦）：无视护甲，格挡不消耗")
	# 直接验证 take_damage 穿透
	var enemy2 := _make_unit([])
	enemy2.is_enemy = true
	enemy2.current_hp = 50
	enemy2.block_value = 30
	manager.take_damage(enemy2, 10, true)
	_check(enemy2.current_hp == 40 and enemy2.block_value == 30, "take_damage ignore_block：格挡不消耗")


func _test_flank_knockback() -> void:
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	var flank_card := CardData.new()
	flank_card.card_name = "伺机测试"
	flank_card.effects = [FlankEffect.new()]
	(flank_card.effects[0] as FlankEffect).value = 7
	var knock_card := CardData.new()
	knock_card.card_name = "击退测试"
	knock_card.effects = [KnockbackEffect.new()]
	(knock_card.effects[0] as KnockbackEffect).value = 1
	manager._resolve_effects(unit, flank_card, null)
	_check(unit.flank_trigger_damage == 7, "伺机：注册本回合触发伤害 7")
	manager._resolve_effects(unit, knock_card, null)
	_check(unit.pending_knockback == 1, "击退：注册本回合击退 1 格")
	manager.end_turn()
	_check(unit.flank_trigger_damage == 0 and unit.pending_knockback == 0, "回合结束清除伺机/击退")


func _test_buff_stacks() -> void:
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	var enemy := _make_unit([])
	enemy.is_enemy = true
	unit.energy = 10
	var xing_fen: CardData = _cards_by_name.get("兴奋药剂")
	unit.hand = [xing_fen]
	manager.play_card(xing_fen, null)
	var heal_buff: Dictionary = _find_buff(unit, "疗愈")
	_check(not heal_buff.is_empty() and int(heal_buff.get("stacks", 0)) == 3, "兴奋药剂：疗愈 buff 初始 3 层")
	var qiang_du: CardData = _cards_by_name.get("强效毒剂")
	unit.hand = [qiang_du]
	manager.play_card(qiang_du, enemy)
	var poison_buff: Dictionary = _find_buff(enemy, "中毒")
	_check(not poison_buff.is_empty() and int(poison_buff.get("stacks", 0)) == 5 \
			and int(poison_buff.get("duration", 0)) == 5, "强效毒剂：敌方中毒 5 层持续 5 回合")


func _test_adrenaline_overdraft() -> void:
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	var jia_shen: CardData = _cards_by_name.get("肾上腺素")
	var draw_effect := jia_shen.effects[0] as DrawEffect
	var overdraft := jia_shen.effects[1] as BuffEffect
	_check(draw_effect != null and draw_effect.value == 3, "肾上腺素：0费抽3")
	_check(overdraft != null and overdraft.buff_type == "肾上腺素透支" and overdraft.stacks == -2 \
			and overdraft.duration == 3, "肾上腺素：透支 buff -2 层持续 3 回合")
	var defend: CardData = _cards_by_name.get("防御")
	for i in 12:
		unit.draw_pile.append(defend)
	unit.energy = 10
	unit.hand = [jia_shen]
	manager.play_card(jia_shen, null)
	_check(unit.hand.size() == 3, "肾上腺素：抽 3 张牌")
	var overdraft_buff: Dictionary = _find_buff(unit, "肾上腺素透支")
	_check(not overdraft_buff.is_empty() and int(overdraft_buff.get("stacks", 0)) == -2, "透支 buff 已施加（-2 层）")
	# 三回合内抽牌阶段不发作
	unit.hand.clear()
	var bonus_early: int = manager._consume_draw_bonus(unit)
	_check(bonus_early == 0, "透支延迟：第一回合抽牌阶段不发作")
	# 手动把 duration 降到 1，模拟三回合后
	overdraft_buff["duration"] = 1
	var bonus_late: int = manager._consume_draw_bonus(unit)
	_check(bonus_late == -2, "透支发作：三回合后抽牌 -2")


func _find_buff(unit: BattleUnit, buff_name: String) -> Dictionary:
	for buff in unit.buffs:
		if buff.get("name", "") == buff_name:
			return buff
	return {}
