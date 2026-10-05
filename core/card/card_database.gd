class_name CardDatabase
extends Node

## 卡牌数据库（Autoload）。
## 启动时读取 res://content/cards/*.json，解析为 CardData + 逻辑链效果资源。
## 美术接口：icon/art/animation 均相对 卡牌/ 目录，通过 res://content/cards/<路径> 访问（兼容旧字段 art_path）。

var cards: Array[CardData] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	cards.clear()
	var dir := DirAccess.open("res://content/cards")
	if dir == null:
		push_warning("卡牌目录不存在：res://content/cards")
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path := "res://content/cards/" + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			if str(parsed.get("id", "")).is_empty() or str(parsed.get("name", "")).is_empty():
				continue
			# 设计稿保留在目录中供后续制作；未实现效果的牌不能进入运行时。
			if parsed.get("implementation_status", "supported") != "supported":
				continue
			var card := _parse_card(parsed)
			if card != null and not card.card_name.is_empty():
				cards.append(card)


func get_card(card_name: String) -> CardData:
	for card in cards:
		if card.card_name == card_name:
			return card
	return null


## 用逻辑链效果生成中文描述（用于技能库条目与提示界面）。
static func describe_card(card: CardData) -> String:
	if card == null:
		return ""
	if not card.description.is_empty():
		return card.description
	var parts: Array[String] = []
	var keywords := card.keyword_labels()
	if not keywords.is_empty():
		parts.append("　".join(keywords))
	for effect in card.effects:
		var cond_prefix := _effect_condition_prefix(effect)
		if effect is MoveEffect:
			parts.append("%s移动 %d 格" % [cond_prefix, effect.distance])
		elif effect is SetDreamStateEffect:
			parts.append("%s进入%s" % [cond_prefix, "沉梦" if effect.state == 0 else "幻梦"])
		elif effect is AttackEffect:
			var pierce := "（无视护甲）" if effect.pierce else ""
			var alt_cond := ""
			if effect.alt_value > 0:
				alt_cond = "（本回合已放血则 %d）" % effect.alt_value if effect.alt_condition == "bloodlet_this_turn" else "（本回合移动过则 %d）" % effect.alt_value
			parts.append("%s攻击 %d 点，范围 %d%s%s" % [cond_prefix, effect.value, effect.attack_range, pierce, alt_cond])
		elif effect is DefenseEffect:
			var defense_cond := ""
			if effect.alt_value > 0:
				defense_cond = "（本回合移动过则 %d）" % effect.alt_value
			parts.append("%s防御 %d 点%s" % [cond_prefix, effect.value, defense_cond])
		elif effect is HealEffect:
			parts.append("%s恢复 %d 点生命" % [cond_prefix, effect.value])
		elif effect is BuffEffect:
			var stacks_text := "" if effect.stacks == 1 else "%d 层 " % effect.stacks
			if effect.duration > 0:
				parts.append("%sbuff%s持续 %d 回合" % [cond_prefix, stacks_text, effect.duration])
			else:
				parts.append("%sbuff%s（持续按 buff 数据自动）" % [cond_prefix, stacks_text])
		elif effect is TriggerBuffEffect:
			parts.append("%s立即结算「%s」一次" % [cond_prefix, effect.buff_type])
		elif effect is DrawEffect:
			parts.append("%s抽 %d 张牌" % [cond_prefix, effect.value])
		elif effect is ChooseFromPileEffect:
			parts.append("%s从%s随机展示至多 %d 张牌，选择 1 张加入%s" % [
				cond_prefix, _pile_name(effect.source), effect.sample_count,
				"手牌" if effect.destination == "hand" else "抽牌堆顶"])
		elif effect is InspectTopCardsEffect:
			parts.append("%s查看抽牌堆顶 %d 张并选择去向与顺序" % [cond_prefix, effect.count])
		elif effect is DiscardEffect:
			if effect.mode == "all":
				parts.append("%s弃掉全部手牌" % cond_prefix)
			else:
				parts.append("%s弃掉 %d 张手牌" % [cond_prefix, effect.value])
		elif effect is AddToHandEffect:
			parts.append("%s将 %d 张「%s」加入手牌" % [cond_prefix, effect.value, effect.card_name])
		elif effect is AddToDrawEffect:
			var pos := "置于抽牌堆顶" if effect.position == "top" else "洗入抽牌堆"
			parts.append("%s将 %d 张「%s」%s" % [cond_prefix, effect.value, effect.card_name, pos])
		elif effect is AddToDiscardEffect:
			parts.append("%s将 %d 张「%s」加入弃牌堆" % [cond_prefix, effect.value, effect.card_name])
		elif effect is GenerateEffect:
			var source: String = effect.card_name if not effect.card_name.is_empty() else ("随机%s" % effect.pool if not effect.pool.is_empty() else "随机牌")
			parts.append("%s生成 %d 张%s" % [cond_prefix, effect.value, source])
		elif effect is CopyEffect:
			parts.append("%s将本牌 %d 张复制品加入%s" % [cond_prefix, effect.value, _pile_name(effect.pile)])
		elif effect is LoseHpEffect:
			var who := "敌方" if effect.target == "enemy" else "自身"
			parts.append("%s%s失去 %d 点生命" % [cond_prefix, who, effect.value])
		elif effect is GainEnergyEffect:
			parts.append("%s获得 %d 点费用" % [cond_prefix, effect.value])
		elif effect is FlankEffect:
			parts.append("%s伺机：本回合离开攻击范围时造成 %d 点伤害" % [cond_prefix, effect.value])
		elif effect is KnockbackEffect:
			parts.append("%s击退命中的敌人 %d 格" % [cond_prefix, effect.value])
	return "；".join(parts)


## 效果的条件前缀（如“如果有 2 名敌人在攻击范围内，则 ”）；无条件返回空串。
static func _effect_condition_prefix(effect: Resource) -> String:
	if not effect.has_meta("condition"):
		return ""
	var condition: Dictionary = effect.get_meta("condition", {})
	if condition.is_empty():
		return ""
	var text := _condition_text(condition)
	if text.is_empty():
		return ""
	return "如果%s，则 " % text


## 条件类型的中文描述（与 卡牌/conditions.json 的 type/name 对应）。
static func _condition_text(condition: Dictionary) -> String:
	var negate := bool(condition.get("negate", false))
	var text := ""
	match str(condition.get("type", "")):
		"enemies_in_range":
			text = "%d 名敌人在攻击范围内" % int(condition.get("count", 1))
		"moved_this_turn":
			text = "本回合已移动"
		"not_moved_this_turn":
			text = "本回合未移动"
		"hp_below_pct":
			text = "生命低于 %d%%" % int(condition.get("pct", 50))
		"hp_at_most_pct":
			text = "生命不高于 %d%%" % int(condition.get("pct", 50))
		"target_hp_at_most_pct":
			text = "目标生命不高于 %d%%" % int(condition.get("pct", 50))
		"target_buff_stacks_at_least":
			text = "目标「%s」不少于 %d 层" % [str(condition.get("buff", "")), int(condition.get("stacks", 1))]
		"played_card_tags_this_turn":
			text = "本行动已打出「%s」" % str(condition.get("tag", ""))
			if not str(condition.get("other_tag", "")).is_empty():
				text += "和「%s」" % str(condition.get("other_tag", ""))
			if str(condition.get("card_type", "")) == "Attack":
				text += "攻击牌"
		"redesign_dream_state_is":
			text = "处于沉梦" if int(condition.get("state", 0)) == 0 else "处于幻梦"
		"redesign_dream_state_at_play_is":
			text = "本牌结算前处于沉梦" if int(condition.get("state", 0)) == 0 else "本牌结算前处于幻梦"
		"target_has_buff_at_play":
			text = "目标出牌前持有「%s」" % str(condition.get("buff_name", ""))
		"target_has_any_debuff_at_play":
			text = "目标出牌前有负面状态"
		"target_lost_direct_hp_this_turn":
			text = "目标本回合曾直接失去生命"
		"target_moved_this_turn":
			text = "目标本回合已移动"
		"caster_target_adjacent":
			text = "与所选目标相邻"
		"adjacent_enemies_at_least":
			text = "相邻敌人不少于 %d 名" % int(condition.get("count", 2))
		"hand_size_at_least":
			text = "手牌不少于 %d 张" % int(condition.get("count", 1))
		"energy_at_least":
			text = "费用不少于 %d" % int(condition.get("value", 1))
		"has_buff":
			text = "持有「%s」" % str(condition.get("buff_name", ""))
		"enemies_alive_at_least":
			text = "场上敌人不少于 %d" % int(condition.get("count", 1))
		"last_card_keyword":
			text = "上一张牌带「%s」" % str(condition.get("keyword", ""))
	if negate and not text.is_empty():
		text = "非" + text
	return text


static func _pile_name(pile: String) -> String:
	match pile:
		"hand":
			return "手牌"
		"draw":
			return "抽牌堆"
		"discard":
			return "弃牌堆"
	return pile


func _parse_card(data: Dictionary) -> CardData:
	var card := CardData.new()
	card.card_id = str(data.get("id", ""))
	card.card_name = str(data.get("name", ""))
	card.character_name = str(data.get("character", ""))
	card.rarity = str(data.get("rarity", ""))
	card.description = str(data.get("description", ""))
	for tag in data.get("tags", []):
		card.tags.append(str(tag))
	card.path_name = str(data.get("path", ""))
	# 美术接口：icon/art/animation 相对 卡牌/ 目录；art 兼容旧字段 art_path
	card.icon_path = str(data.get("icon", ""))
	card.art_path = str(data.get("art", data.get("art_path", "")))
	card.animation_path = str(data.get("animation", ""))
	card.category = _parse_category(str(data.get("category", "")))
	card.card_type = _parse_card_type(str(data.get("card_type", "")))
	card.cost = int(data.get("cost", 0))
	card.load = int(data.get("load", 0))
	card.hp_payment = int(data.get("hp_payment", 0))
	card.dream_mode = str(data.get("dream_mode", ""))
	for rule in data.get("cost_rules", []):
		if rule is Dictionary:
			card.cost_rules.append(rule.duplicate(true))
	for condition in data.get("play_conditions", []):
		if condition is Dictionary:
			card.play_conditions.append(condition.duplicate(true))
	card.target_type = _parse_target_type(str(data.get("target_type", "")))
	card.range = int(data.get("range", 0))
	card.min_range = int(data.get("min_range", 1))
	card.area = int(data.get("area", 0))
	# 关键词：消耗/保留/虚无/固有/沉梦/幻梦/灾梦/衍生（兼容旧字段 discard_on_use=true → 消耗）
	card.exhaust_on_play = bool(data.get("exhaust_on_play", false))
	card.retain = bool(data.get("retain", false))
	card.ethereal = bool(data.get("ethereal", false))
	card.innate = bool(data.get("innate", false))
	card.dream = bool(data.get("dream", false))
	card.phantom = bool(data.get("phantom", false))
	card.doom_dream = bool(data.get("doom_dream", false))
	card.derived = bool(data.get("derived", false))
	card.lifesteal = bool(data.get("lifesteal", false))
	if bool(data.get("discard_on_use", false)):
		card.exhaust_on_play = true
	for keyword in data.get("keywords", []):
		match str(keyword):
			"消耗":
				card.exhaust_on_play = true
			"保留":
				card.retain = true
			"虚无":
				card.ethereal = true
			"固有":
				card.innate = true
			"沉梦":
				card.dream = true
			"幻梦":
				card.phantom = true
			"灾梦":
				card.doom_dream = true
			"衍生":
				card.derived = true
			"吸血":
				card.lifesteal = true
	for effect_data in data.get("effects", []):
		var effect := _parse_effect(effect_data)
		if effect != null:
			# 条件判断：效果可挂 condition（类型见 卡牌/conditions.json），存入效果 meta
			if effect_data.has("condition"):
				effect.set_meta("condition", effect_data.get("condition"))
			card.effects.append(effect)
	return card


func _parse_effect(data) -> Resource:
	if not data is Dictionary:
		return null
	var logic := str(data.get("logic", ""))
	match logic:
		"attack":
			var attack := AttackEffect.new()
			attack.value = int(data.get("value", 0))
			attack.attack_range = int(data.get("attack_range", 0))
			attack.pierce = bool(data.get("pierce", false))
			attack.alt_value = int(data.get("alt_value", 0))
			attack.alt_condition = str(data.get("alt_condition", "moved_this_turn"))
			return attack
		"move":
			var move := MoveEffect.new()
			move.distance = int(data.get("distance", 0))
			move.target = str(data.get("target", "self"))
			return move
		"set_dream_state":
			var dream_state := SetDreamStateEffect.new()
			dream_state.state = int(data.get("state", 0))
			return dream_state
		"defense":
			var defense := DefenseEffect.new()
			defense.value = int(data.get("value", 0))
			defense.alt_value = int(data.get("alt_value", 0))
			defense.target = str(data.get("target", "self"))
			return defense
		"heal":
			var heal := HealEffect.new()
			heal.value = int(data.get("value", 0))
			heal.target = str(data.get("target", "self"))
			return heal
		"buff":
			var buff := BuffEffect.new()
			buff.target = str(data.get("target", "self"))
			buff.buff_type = str(data.get("buff_type", ""))
			buff.duration = int(data.get("duration", 0))
			buff.stacks = int(data.get("stacks", 1))
			return buff
		"trigger_buff":
			var trigger := TriggerBuffEffect.new()
			trigger.target = str(data.get("target", "enemy"))
			trigger.buff_type = str(data.get("buff_type", ""))
			return trigger
		"draw":
			var draw := DrawEffect.new()
			draw.value = int(data.get("value", 1))
			return draw
		"transfer_random_card":
			var transfer := TransferRandomCardEffect.new()
			transfer.source = str(data.get("source", "discard"))
			transfer.destination = str(data.get("destination", "draw"))
			transfer.exclude_card_type = str(data.get("exclude_card_type", ""))
			transfer.position = str(data.get("position", "top"))
			transfer.count = int(data.get("count", 1))
			return transfer
		"mulligan_hand":
			return MulliganHandEffect.new()
		"choose_from_pile":
			var choice := ChooseFromPileEffect.new()
			choice.source = str(data.get("source", "draw"))
			choice.sample_count = int(data.get("sample_count", 3))
			choice.show_all = bool(data.get("show_all", false))
			choice.destination = str(data.get("destination", "draw"))
			choice.position = str(data.get("position", "top"))
			choice.required_card_type = str(data.get("required_card_type", ""))
			choice.exclude_card_type = str(data.get("exclude_card_type", ""))
			choice.required_rarity = str(data.get("required_rarity", ""))
			choice.base_cost = int(data.get("base_cost", -1))
			for tag in data.get("required_tags", []):
				choice.required_tags.append(str(tag))
			choice.played_in_battle = bool(data.get("played_in_battle", false))
			choice.not_played_this_turn = bool(data.get("not_played_this_turn", false))
			choice.exhaust_selected_on_play = bool(data.get("exhaust_selected_on_play", false))
			choice.selected_cost_override = int(data.get("selected_cost_override", -1))
			choice.selected_cost_reduction = int(data.get("selected_cost_reduction", 0))
			choice.grant_retain_selected = bool(data.get("grant_retain_selected", false))
			choice.temporary_copy = bool(data.get("temporary_copy", false))
			return choice
		"inspect_top_cards":
			var inspect := InspectTopCardsEffect.new()
			inspect.count = int(data.get("count", 0))
			inspect.pick_to_hand = bool(data.get("pick_to_hand", false))
			inspect.pick_to_discard = int(data.get("pick_to_discard", 0))
			inspect.discard_up_to = int(data.get("discard_up_to", 0))
			inspect.reorder_remaining = bool(data.get("reorder_remaining", true))
			return inspect
		"discard":
			var discard := DiscardEffect.new()
			discard.value = int(data.get("value", 1))
			discard.mode = str(data.get("mode", "random"))
			return discard
		"add_to_hand":
			var add_hand := AddToHandEffect.new()
			add_hand.card_name = str(data.get("card", ""))
			add_hand.value = int(data.get("value", 1))
			return add_hand
		"add_to_draw":
			var add_draw := AddToDrawEffect.new()
			add_draw.card_name = str(data.get("card", ""))
			add_draw.value = int(data.get("value", 1))
			add_draw.position = str(data.get("position", "shuffle"))
			return add_draw
		"add_to_discard":
			var add_discard := AddToDiscardEffect.new()
			add_discard.card_name = str(data.get("card", ""))
			add_discard.value = int(data.get("value", 1))
			return add_discard
		"generate":
			var generate := GenerateEffect.new()
			generate.card_name = str(data.get("card", ""))
			generate.pool = str(data.get("pool", ""))
			generate.value = int(data.get("value", 1))
			generate.pile = str(data.get("pile", "hand"))
			return generate
		"copy":
			var copy := CopyEffect.new()
			copy.value = int(data.get("value", 1))
			copy.pile = str(data.get("pile", "discard"))
			return copy
		"lose_hp":
			var lose := LoseHpEffect.new()
			lose.value = int(data.get("value", 1))
			lose.target = str(data.get("target", "self"))
			lose.value_from_target_buff_stacks = str(data.get("value_from_target_buff_stacks", ""))
			return lose
		"gain_energy":
			var gain := GainEnergyEffect.new()
			gain.value = int(data.get("value", 1))
			return gain
		"flank":
			var flank := FlankEffect.new()
			flank.value = int(data.get("value", 7))
			return flank
		"knockback":
			var knock := KnockbackEffect.new()
			knock.value = int(data.get("value", 1))
			return knock
	return null


func _parse_category(value: String) -> CardData.CardCategory:
	match value:
		"道途专属卡牌":
			return CardData.CardCategory.PATH
	return CardData.CardCategory.GENERIC


func _parse_card_type(value: String) -> CardData.CardType:
	match value:
		"行动":
			return CardData.CardType.ACTION
		"能力":
			return CardData.CardType.ABILITY
	return CardData.CardType.ATTACK


func _parse_target_type(value: String) -> CardData.TargetType:
	match value:
		"Self":
			return CardData.TargetType.SELF
		"Ally":
			return CardData.TargetType.ALLY
		"Enemy":
			return CardData.TargetType.ENEMY
		"Hex":
			return CardData.TargetType.HEX
		"Area":
			return CardData.TargetType.AREA
	return CardData.TargetType.NONE
