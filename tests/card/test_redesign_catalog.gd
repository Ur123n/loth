extends SceneTree

const PREFIXES := ["A", "D", "K", "B"]


var _started := false


func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	var mechanism_file := FileAccess.open("res://content/cards/mechanics.json", FileAccess.READ)
	if mechanism_file == null:
		_fail("缺少卡牌机制数据库")
		return true
	var mechanisms = JSON.parse_string(mechanism_file.get_as_text())
	if not mechanisms is Dictionary or int(mechanisms.get("schema_version", 0)) != 1:
		_fail("卡牌机制数据库格式错误")
		return true
	var conditions_file := FileAccess.open("res://content/cards/conditions.json", FileAccess.READ)
	if conditions_file == null:
		_fail("缺少编辑器条件清单")
		return true
	var condition_config = JSON.parse_string(conditions_file.get_as_text())
	if not condition_config is Dictionary:
		_fail("编辑器条件清单格式错误")
		return true
	for entry in condition_config.get("conditions", []):
		var ref := str(entry.get("mechanism_id", ""))
		if not ref.is_empty() and (ref != "conditions." + str(entry.get("type", ""))
				or not mechanisms["conditions"].has(str(entry.get("type", "")))):
			_fail("编辑器条件与机制库不一致：%s" % ref)
			return true
	var expected_supported := 0
	var total := 0
	for prefix in PREFIXES:
		for number in range(1, 76):
			var card_id := "%s%03d" % [prefix, number]
			var path := "res://content/cards/%s.json" % card_id
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				_fail("缺少卡牌 %s" % card_id)
				return true
			var data = JSON.parse_string(file.get_as_text())
			if not data is Dictionary or data.get("id", "") != card_id:
				_fail("卡牌 JSON 错误 %s" % card_id)
				return true
			if str(data.get("description", "")).is_empty() or str(data.get("source_file", "")).is_empty():
				_fail("卡牌缺少规则或来源 %s" % card_id)
				return true
			if data.get("art", "") != "":
				_fail("本轮不应设置卡面 %s" % card_id)
				return true
			if data.get("implementation_status", "") == "supported":
				if (data.get("effects", []) as Array).is_empty():
					_fail("已实现卡牌缺少效果 %s" % card_id)
					return true
				var refs: Array = data.get("mechanism_ids", [])
				if refs.is_empty():
					_fail("已实现卡牌缺少机制引用 %s" % card_id)
					return true
				for ref in refs:
					var parts := str(ref).split(".")
					if parts.size() != 2 or not mechanisms.has(parts[0]) or not mechanisms[parts[0]].has(parts[1]):
						_fail("卡牌引用了未登记机制 %s: %s" % [card_id, ref])
						return true
				for effect in data.get("effects", []):
					if not refs.has("effects." + str(effect.get("logic", ""))):
						_fail("卡牌效果未登记机制 %s" % card_id)
						return true
					if effect.has("condition") and not refs.has("conditions." + str(effect["condition"].get("type", ""))):
						_fail("卡牌效果条件未登记机制 %s" % card_id)
						return true
				for rule in data.get("cost_rules", []):
					if not refs.has("conditions." + str(rule.get("type", ""))):
						_fail("卡牌降费条件未登记机制 %s" % card_id)
						return true
				for condition in data.get("play_conditions", []):
					if not refs.has("conditions." + str(condition.get("type", ""))):
						_fail("卡牌出牌前条件未登记机制 %s" % card_id)
						return true
				if not data.get("play_conditions", []).is_empty() and not refs.has("play_rules.play_conditions"):
					_fail("卡牌出牌前规则未登记机制 %s" % card_id)
					return true
				expected_supported += 1
			total += 1
	var db := CardDatabase.new()
	root.add_child(db)
	var loaded_redesign := 0
	for card in db.cards:
		if card.card_id.length() == 4 and card.card_id.substr(0, 1) in PREFIXES:
			loaded_redesign += 1
	if loaded_redesign != expected_supported:
		_fail("运行时加载 %d 张，预期 %d 张" % [loaded_redesign, expected_supported])
		return true
	print("RESULT: total=%d supported=%d design_only=%d failed=0" % [total, expected_supported, total - expected_supported])
	quit(0)
	return true


func _fail(message: String) -> void:
	push_error(message)
	print("RESULT: failed=1")
	quit(1)
