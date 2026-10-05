class_name BuildingLibrary
extends RefCounted

## 建筑资产库：扫描 `res://assets/buildings/*/metadata/building.json`，回答
## "有哪些建筑、某座建筑长什么样、它的 Prefab 在哪"。
##
## 这是 Agent 的**入口**：`list_buildings()` → `inspect_building(id)` → `place_building(...)`。
## Agent 不需要知道目录结构，也不需要读图。

const ROOT := "res://assets/buildings"
const METADATA_NAME := "metadata/building.json"
const SPEC_NAME := "building.spec.json"

var _data_cache: Dictionary = {}
var _dir_cache: Dictionary = {}


## 列出全部建筑 id（目录名 ∪ metadata 里的 building_id），按字典序。
func list_building_ids() -> PackedStringArray:
	var ids := {}
	var dir := DirAccess.open(ROOT)
	if dir != null:
		for sub in dir.get_directories():
			if FileAccess.file_exists(get_metadata_path(sub)):
				ids[sub] = true
	var keys: Array = ids.keys()
	keys.sort()
	var out := PackedStringArray()
	for key in keys:
		out.append(String(key))
	return out


## 列出全部建筑的摘要（Agent 选建筑时读这个）。
func list_buildings() -> Array:
	var out: Array = []
	for id in list_building_ids():
		var data := load_building(id)
		if data == null:
			out.append({"building_id": id, "ok": false, "error": "metadata 解析失败"})
			continue
		out.append(data.summarize())
	return out


func has_building(building_id: String) -> bool:
	return FileAccess.file_exists(get_metadata_path(building_id))


func get_asset_dir(building_id: String) -> String:
	return "%s/%s" % [ROOT, building_id]


func get_metadata_path(building_id: String) -> String:
	return "%s/%s/%s" % [ROOT, building_id, METADATA_NAME]


func get_spec_path(building_id: String) -> String:
	return "%s/%s/%s" % [ROOT, building_id, SPEC_NAME]


## 取建筑数据（带缓存）；没有返回 null。
func load_building(building_id: String) -> BuildingData:
	if _data_cache.has(building_id):
		return _data_cache[building_id]
	var path := get_metadata_path(building_id)
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("建筑 metadata 不是合法 JSON：%s" % path)
		return null
	var data := BuildingData.from_dictionary(parsed)
	data.source_path = path
	_data_cache[building_id] = data
	return data


func clear_cache() -> void:
	_data_cache.clear()
	_dir_cache.clear()


## 资产的分类文件清单（校验工具与 inspect 用）。
## 返回 `{"visual": [...], "masks": [...], "metadata": [...], "preview": [...], "collision": [...], "other": [...]}`
## 每项是 `{"path", "exists", "size"}`（相对于资产目录的 res:// 路径）。
func list_files(building_id: String) -> Dictionary:
	var out := {"visual": [], "masks": [], "metadata": [], "preview": [], "collision": [], "other": []}
	var base := get_asset_dir(building_id)
	var dir := DirAccess.open(base)
	if dir == null:
		return out
	_walk(base, "", out)
	return out


func _walk(base: String, relative: String, out: Dictionary) -> void:
	var current := base if relative.is_empty() else base.path_join(relative)
	var dir := DirAccess.open(current)
	if dir == null:
		return
	for file in dir.get_files():
		var rel := file if relative.is_empty() else relative.path_join(file)
		if file.ends_with(".import") or file.ends_with(".uid"):
			continue
		var full := base.path_join(rel)
		var entry := {"path": full, "exists": FileAccess.file_exists(full), "size": 0}
		var handle := FileAccess.open(full, FileAccess.READ)
		if handle != null:
			entry["size"] = handle.get_length()
			handle.close()
		var bucket := "other"
		if rel.begins_with("visual/"):
			bucket = "visual"
		elif rel.begins_with("masks/"):
			bucket = "masks"
		elif rel.begins_with("metadata/"):
			bucket = "metadata"
		elif rel.begins_with("preview/"):
			bucket = "preview"
		elif rel.begins_with("collision/"):
			bucket = "collision"
		(out[bucket] as Array).append(entry)
	for sub in dir.get_directories():
		_walk(base, sub if relative.is_empty() else relative.path_join(sub), out)
