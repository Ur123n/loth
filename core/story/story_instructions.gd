class_name StoryInstructions
extends RefCounted

## 剧情指令实现库：StoryRunner 通过 build_registry() 注册。
## handler 签名：func(ctx: StoryRunner.StoryContext, ins: Dictionary, blocking: bool) -> Variant
## 处理器是同步函数，返回“操作句柄”（null = 立即完成）：
##   Tween           —— 动画/字幕完成（camera.*、move_actor、message）
##   SceneTreeTimer  —— 等待计时（wait）
##   Dictionary      —— 对话令牌 / 历史面板 / 场景切换等轮询型操作
## 结构指令（if / story.start / end / parallel）由 StoryRunner 解释，不在此注册。
## 通用字段：
##   blocking   : bool，默认 true —— true=Runner 等待句柄完成；false=放行（后台继续）
##   transition / ease : camera.move_to、move_actor 的缓动（sine/linear/quad/...）

const TRANSITIONS := {
	"linear": Tween.TRANS_LINEAR,
	"sine": Tween.TRANS_SINE,
	"quad": Tween.TRANS_QUAD,
	"cubic": Tween.TRANS_CUBIC,
	"quart": Tween.TRANS_QUART,
	"quint": Tween.TRANS_QUINT,
	"circ": Tween.TRANS_CIRC,
	"elastic": Tween.TRANS_ELASTIC,
	"back": Tween.TRANS_BACK,
	"bounce": Tween.TRANS_BOUNCE,
}

const EASES := {
	"in": Tween.EASE_IN,
	"out": Tween.EASE_OUT,
	"in_out": Tween.EASE_IN_OUT,
	"out_in": Tween.EASE_OUT_IN,
}


func build_registry() -> Dictionary:
	return {
		"dialogue.line": _instr_dialogue_line,
		"dialogue.choice": _instr_dialogue_choice,
		"dialogue.history.open": _instr_dialogue_history_open,
		"dialogue.history.clear": _instr_dialogue_history_clear,
		"dialogue.end": _instr_dialogue_end,
		"camera.move_to": _instr_camera_move_to,
		"camera.follow": _instr_camera_follow,
		"camera.unfollow": _instr_camera_unfollow,
		"camera.zoom_to": _instr_camera_zoom_to,
		"camera.shake": _instr_camera_shake,
		"camera.reset": _instr_camera_reset,
		"wait": _instr_wait,
		"message": _instr_message,
		"flag.set": _instr_flag_set,
		"var.set": _instr_var_set,
		"move_actor": _instr_move_actor,
		"set_property": _instr_set_property,
		"call_method": _instr_call_method,
		"emit_signal": _instr_emit_signal,
		"player.lock": _instr_player_lock,
		"player.unlock": _instr_player_unlock,
		"change_scene": _instr_change_scene,
	}


func _instr_dialogue_line(_ctx, ins, _blocking):
	var speaker := str(ins.get("speaker", ""))
	var text := str(ins.get("text", ""))
	var avatar := str(ins.get("avatar", ""))
	var color := _parse_color(ins.get("color", ""), Color(0.92, 0.94, 0.97))
	var speed := float(ins.get("speed", 0.03))
	var auto := bool(ins.get("auto", false))
	var auto_delay := float(ins.get("auto_delay", 1.2))
	var token := Dialogue.begin_line(speaker, text, avatar, color, speed, auto, auto_delay)
	return {"kind": "dialogue_line", "token": token}


func _instr_dialogue_choice(ctx, ins, _blocking):
	var options: Array = ins.get("options", [])
	var texts: Array[String] = []
	for opt in options:
		if opt is Dictionary:
			texts.append(str(opt.get("text", "")))
		else:
			texts.append(str(opt))
	var token := Dialogue.show_options(texts)
	var var_name := str(ins.get("var", "choice"))
	return {
		"kind": "dialogue_choice",
		"token": token,
		"on_done": func() -> void:
			var index := Dialogue.get_last_choice_index()
			ctx.variables[var_name] = index
			if index >= 0 and index < options.size():
				var opt = options[index]
				if opt is Dictionary:
					if opt.has("value"):
						ctx.variables[var_name] = _coerce_value(opt.get("value"))
					if opt.has("flag"):
						GameState.set_flag(str(opt.get("flag")), _coerce_value(opt.get("flag_value", true)))
	}


func _instr_dialogue_history_open(_ctx, ins, blocking):
	Dialogue.open_history()
	if blocking:
		return {"kind": "history"}
	return null


func _instr_dialogue_history_clear(_ctx, _ins, _blocking) -> void:
	Dialogue.history.clear()
	if Dialogue.box != null:
		Dialogue.box.set_history_lines(Dialogue.history.lines)


func _instr_dialogue_end(_ctx, _ins, _blocking) -> void:
	Dialogue.end_session()


func _instr_camera_move_to(ctx, ins, _blocking):
	CameraCtrl.ensure_camera()
	var target := _resolve_position(ctx, ins.get("target", [640, 360]))
	var duration := maxf(float(ins.get("duration", 1.0)), 0.0)
	return CameraCtrl.move_to(target, duration, _transition(ins), _ease(ins), ins.get("zoom", null))


func _instr_camera_follow(ctx, ins, _blocking) -> void:
	var node := _resolve_node(ctx, ins.get("target", "player"))
	if node is Node2D:
		CameraCtrl.follow_node(node, _as_vector2(ins.get("offset", []), Vector2.ZERO))
	else:
		push_warning("[Story] camera.follow 目标不是 Node2D：%s" % str(ins.get("target")))


func _instr_camera_unfollow(_ctx, _ins, _blocking) -> void:
	CameraCtrl.unfollow()


func _instr_camera_zoom_to(_ctx, ins, _blocking):
	return CameraCtrl.zoom_to(ins.get("zoom", 1.0), float(ins.get("duration", 1.0)),
		_transition(ins), _ease(ins))


func _instr_camera_shake(_ctx, ins, _blocking):
	return CameraCtrl.shake(float(ins.get("strength", 5.0)), float(ins.get("duration", 0.5)))


func _instr_camera_reset(_ctx, _ins, _blocking) -> void:
	CameraCtrl.reset()


func _instr_wait(ctx, ins, blocking):
	var seconds := maxf(float(ins.get("seconds", 0.0)), 0.0)
	if seconds <= 0.0 or not blocking:
		return null
	return ctx.tree().create_timer(seconds)


func _instr_message(ctx, ins, _blocking):
	return ctx.runner.show_message(str(ins.get("text", "")), float(ins.get("duration", 2.0)))


func _instr_flag_set(_ctx, ins, _blocking) -> void:
	var key := str(ins.get("key", ""))
	if key.is_empty():
		return
	GameState.set_flag(key, _coerce_value(ins.get("value", true)))


func _instr_var_set(ctx, ins, _blocking) -> void:
	var name := str(ins.get("name", ""))
	if not name.is_empty():
		ctx.variables[name] = _coerce_value(ins.get("value", null))


func _instr_move_actor(ctx, ins, _blocking):
	var node := _resolve_node(ctx, ins.get("node", ""))
	if node == null:
		push_warning("[Story] move_actor 找不到节点：%s" % str(ins.get("node")))
		return null
	if not node is Node2D:
		push_warning("[Story] move_actor 目标不是 Node2D：%s" % str(ins.get("node")))
		return null
	var target := _resolve_position(ctx, ins.get("target", []))
	var duration := maxf(float(ins.get("duration", 1.0)), 0.0)
	var tween := node.create_tween()
	tween.tween_property(node, "position", target, duration).set_trans(_transition(ins)).set_ease(_ease(ins))
	return tween


func _instr_set_property(ctx, ins, _blocking) -> void:
	var node := _resolve_node(ctx, ins.get("node", ""))
	var prop := str(ins.get("property", ""))
	if node == null or prop.is_empty():
		return
	node.set(prop, _coerce_value(ins.get("value", null)))


func _instr_call_method(ctx, ins, _blocking) -> void:
	var node := _resolve_node(ctx, ins.get("node", ""))
	var method := str(ins.get("method", ""))
	if node == null or method.is_empty():
		return
	var raw_args = ins.get("args", [])
	if not raw_args is Array:
		raw_args = [raw_args]
	var args: Array = []
	for a in raw_args:
		args.append(_coerce_value(a))
	node.callv(method, args)


func _instr_emit_signal(ctx, ins, _blocking) -> void:
	var signal_name := str(ins.get("signal", ""))
	var target: Object = _resolve_node(ctx, ins.get("on", ""))
	if target == null:
		target = ctx.runner
	if signal_name.is_empty():
		return
	var sig = target.get(signal_name)
	if not sig is Signal:
		push_warning("[Story] emit_signal：%s 不是信号" % signal_name)
		return
	var raw_args = ins.get("args", [])
	if not raw_args is Array:
		raw_args = [raw_args]
	var args: Array = []
	for a in raw_args:
		args.append(_coerce_value(a))
	sig.emit.callv(args)


func _instr_player_lock(ctx, _ins, _blocking) -> void:
	ctx.runner.lock_player_input()


func _instr_player_unlock(ctx, _ins, _blocking) -> void:
	ctx.runner.unlock_player_input()


func _instr_change_scene(ctx, ins, blocking):
	var scene_path := str(ins.get("scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("[Story] change_scene 场景不存在：%s" % scene_path)
		return null
	ctx.tree().change_scene_to_file(scene_path)
	if blocking:
		return {"kind": "scene", "scene": scene_path}
	return null


func _resolve_node(ctx, ref) -> Node:
	if ref is Node:
		return ref
	if not ref is String:
		return null
	var path := str(ref)
	var tree: SceneTree = ctx.tree()
	if path == "player":
		return tree.get_first_node_in_group("player")
	if path == "camera":
		return CameraCtrl.camera
	if path.begins_with("/"):
		return tree.root.get_node_or_null(path)
	var scene: Node = tree.current_scene
	if scene != null:
		var node: Node = scene.get_node_or_null(path)
		if node != null:
			return node
	return tree.root.get_node_or_null(path)


func _resolve_position(ctx, target) -> Vector2:
	if target is Array and target.size() >= 2:
		return Vector2(float(target[0]), float(target[1]))
	if target is Dictionary and target.has("x"):
		return Vector2(float(target.get("x", 0.0)), float(target.get("y", 0.0)))
	if target is String:
		var node := _resolve_node(ctx, target)
		if node is Node2D:
			return node.global_position
	return Vector2(640, 360)


## 供 StoryRunner 解释 if 指令时使用。
func evaluate_condition(ctx, cond) -> bool:
	return _eval_condition(ctx, cond)


func _eval_condition(ctx, cond) -> bool:
	if cond is bool:
		return cond
	if not cond is Dictionary:
		return false
	if cond.has("and"):
		for sub in cond.get("and", []):
			if not _eval_condition(ctx, sub):
				return false
		return true
	if cond.has("or"):
		for sub in cond.get("or", []):
			if _eval_condition(ctx, sub):
				return true
		return false
	if cond.has("not"):
		return not _eval_condition(ctx, cond.get("not"))
	if cond.has("flag"):
		return _compare(GameState.get_flag(str(cond.get("flag"))), cond.get("equals", true))
	if cond.has("var"):
		return _compare(ctx.variables.get(str(cond.get("var"))), cond.get("equals", true))
	return false


func _compare(actual, expected) -> bool:
	if actual is bool or expected is bool:
		return bool(actual) == bool(expected)
	if actual is float or expected is float or actual is int or expected is int:
		return float(actual) == float(expected)
	return actual == expected


func _coerce_value(v):
	if v is Array:
		if v.size() == 2 and _all_numeric(v):
			return Vector2(float(v[0]), float(v[1]))
		if v.size() == 3 and _all_numeric(v):
			return Vector3(float(v[0]), float(v[1]), float(v[2]))
		var out: Array = []
		for e in v:
			out.append(_coerce_value(e))
		return out
	if v is Dictionary:
		var out := {}
		for key in v:
			out[key] = _coerce_value(v[key])
		return out
	return v


func _all_numeric(values: Array) -> bool:
	for v in values:
		if not (v is int or v is float):
			return false
	return true


func _parse_color(raw, default_color: Color) -> Color:
	var s := str(raw)
	if s.is_empty() or not Color.html_is_valid(s):
		return default_color
	return Color(s)


func _transition(ins: Dictionary) -> int:
	return int(TRANSITIONS.get(str(ins.get("transition", "sine")), Tween.TRANS_SINE))


func _ease(ins: Dictionary) -> int:
	return int(EASES.get(str(ins.get("ease", "in_out")), Tween.EASE_IN_OUT))


func _as_vector2(v, default_value: Vector2) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Dictionary and v.has("x"):
		return Vector2(float(v.get("x", 0.0)), float(v.get("y", 0.0)))
	return default_value
