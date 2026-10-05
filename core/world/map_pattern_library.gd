class_name MapPatternLibrary
extends RefCounted

## Data-driven library for complete, repeatable small-building patterns.
## A pattern can be a TileMapPattern later; phase one uses a PackedScene stamp,
## which is explicitly allowed by the map architecture plan.

const ROOT := "res://content/map_patterns"
const SCHEMA := "map_pattern/1"

var _cache: Dictionary = {}


func list_pattern_ids() -> PackedStringArray:
	var found := {}
	var directory := DirAccess.open(ROOT)
	if directory == null:
		return PackedStringArray()
	for file_name in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		var fallback := file_name.trim_suffix(".json")
		var pattern := load_pattern(fallback)
		if not pattern.is_empty():
			found[String(pattern.get("pattern_id", fallback))] = true
	var ids: Array = found.keys()
	ids.sort()
	var out := PackedStringArray()
	for id in ids:
		out.append(String(id))
	return out


func load_pattern(pattern_id: String) -> Dictionary:
	if _cache.has(pattern_id):
		return (_cache[pattern_id] as Dictionary).duplicate(true)
	var path := ROOT.path_join("%s.json" % pattern_id)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var pattern: Dictionary = parsed
	if not validate_pattern(pattern).is_empty():
		return {}
	pattern["_source_path"] = path
	_cache[pattern_id] = pattern
	return pattern.duplicate(true)


func validate_pattern(pattern: Dictionary) -> PackedStringArray:
	var issues := PackedStringArray()
	if String(pattern.get("schema", "")) != SCHEMA:
		issues.append("schema 必须是 %s" % SCHEMA)
	if String(pattern.get("pattern_id", "")).is_empty():
		issues.append("缺少 pattern_id")
	var scene_path := String(pattern.get("scene", ""))
	if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
		issues.append("scene 不存在：%s" % scene_path)
	var footprint: Variant = pattern.get("footprint_cells", null)
	if typeof(footprint) != TYPE_ARRAY or (footprint as Array).size() != 2:
		issues.append("footprint_cells 必须是 [宽, 高]")
	elif int(footprint[0]) <= 0 or int(footprint[1]) <= 0:
		issues.append("footprint_cells 必须为正数")
	var anchor: Variant = pattern.get("anchor_cell", null)
	if typeof(anchor) != TYPE_ARRAY or (anchor as Array).size() != 2:
		issues.append("anchor_cell 必须是 [x, y]")
	return issues


func instantiate_pattern(pattern_id: String) -> Node2D:
	var pattern := load_pattern(pattern_id)
	if pattern.is_empty():
		return null
	var packed := load(String(pattern["scene"])) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node2D
	if instance == null:
		return null
	instance.set_meta("pattern_id", pattern_id)
	instance.set_meta("pattern_source", String(pattern.get("_source_path", "")))
	return instance


## One-call stamp placement: instantiate the complete pattern and place its anchor.
func place_pattern(parent: Node, pattern_id: String, anchor_position: Vector2,
		options: Dictionary = {}) -> Node2D:
	if parent == null:
		return null
	var instance := instantiate_pattern(pattern_id)
	if instance == null:
		return null
	if options.has("name"):
		instance.name = String(options["name"])
	parent.add_child(instance)
	instance.position = anchor_position
	return instance


func clear_cache() -> void:
	_cache.clear()

