class_name NpcSchedule
extends RefCounted

## NPC 行动轨迹（时间轴）纯逻辑：由世界时钟 GameState.world_time（小时 0-24）驱动，
## 在相邻时间点之间线性插值移动；跨零点（最后一条 → 第一条）自动衔接。
## 位置为地图内像素坐标（当前初始地图 640×480，若换图需调整 MAP_W/MAP_H）。

const MAP_W := 640.0
const MAP_H := 480.0


## 计算某时刻 NPC 的地图内位置；schedule 为空返回 Vector2.INF（无效）。
static func compute_position(schedule: Array, time_hour: float) -> Vector2:
	var entries := _sorted(schedule)
	if entries.is_empty():
		return Vector2.INF
	if entries.size() == 1:
		return _pos(entries[0])
	var h := fmod(time_hour, 24.0)
	# 命中整点：直接返回该时间点位置
	for e in entries:
		if absf(float(e.get("hour", 0.0)) - h) < 0.0001:
			return _pos(e)
	# 找第一条 hour > h 的条目 i；i==0 表示 h 在首个时间点之前（跨零点）
	var i := entries.size()
	for idx in entries.size():
		if float(entries[idx].get("hour", 0.0)) > h:
			i = idx
			break
	var a: Dictionary = entries[(i - 1 + entries.size()) % entries.size()]
	var b: Dictionary = entries[i % entries.size()]
	var ha := float(a.get("hour", 0.0))
	var hb := float(b.get("hour", 0.0))
	if i == 0:
		ha -= 24.0    # 跨零点：a 为昨天最后一条
	elif hb <= ha:
		hb += 24.0
	var t := 0.0
	if hb > ha:
		t = clampf((h - ha) / (hb - ha), 0.0, 1.0)
	return _pos(a).lerp(_pos(b), t)


## 校验时间轴；问题写入 problems（无问题返回 true）。
static func validate(schedule: Array, problems: Array[String], npc_name: String = "") -> void:
	if schedule.is_empty():
		problems.append("%s schedule 为空" % npc_name)
		return
	var prev_hour := -1.0
	for i in schedule.size():
		var e = schedule[i]
		if not e is Dictionary:
			problems.append("%s schedule[%d] 不是对象" % [npc_name, i])
			continue
		var hour = e.get("hour", null)
		if hour == null or not (hour is float or hour is int):
			problems.append("%s schedule[%d] 缺少 hour（数字）" % [npc_name, i])
			continue
		var h := float(hour)
		if h < 0.0 or h >= 24.0:
			problems.append("%s schedule[%d] hour 越界：%s（应 0-24）" % [npc_name, i, h])
		if h <= prev_hour:
			problems.append("%s schedule[%d] hour 未递增（%s ≤ %s）" % [npc_name, i, h, prev_hour])
		prev_hour = h
		var pos = e.get("position", null)
		if pos is Array and pos.size() >= 2:
			var px := float(pos[0])
			var py := float(pos[1])
			if px < 0.0 or px > MAP_W or py < 0.0 or py > MAP_H:
				problems.append("%s schedule[%d] 位置越界：[%s, %s]（地图 %s×%s）" % [npc_name, i, px, py, MAP_W, MAP_H])
		else:
			problems.append("%s schedule[%d] 缺少 position（[x, y]）" % [npc_name, i])


static func _sorted(schedule: Array) -> Array:
	var entries: Array = []
	for e in schedule:
		if e is Dictionary and e.has("hour") and e.has("position"):
			entries.append(e)
	entries.sort_custom(func(a, b): return float(a.get("hour", 0.0)) < float(b.get("hour", 0.0)))
	return entries


static func _pos(e: Dictionary) -> Vector2:
	var pos = e.get("position", [0, 0])
	return Vector2(float(pos[0]), float(pos[1]))
