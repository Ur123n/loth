extends SceneTree

## 全项目 GDScript 编译自检：递归发现并加载每个 .gd，避免新增脚本漏进硬编码清单。
## 运行：godot --headless --path C:\游戏 --script tests\dev\test_script_compile.gd

const SCRIPT_ROOTS: Array[String] = ["res://core", "res://ui", "res://world", "res://demo", "res://maps/godot/tools", "res://tests"]

var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var paths := PackedStringArray()
	for root_path in SCRIPT_ROOTS:
		_collect_scripts(root_path, paths)
	paths.sort()
	for p in paths:
		var s = load(p)
		var can_compile := s != null
		if can_compile and s is GDScript:
			can_compile = (s as GDScript).can_instantiate()
		if not can_compile:
			_failed += 1
			print("FAIL  ", p)
		else:
			print("OK    ", p)
	print("RESULT: scripts=%d failed=%d" % [paths.size(), _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _collect_scripts(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_failed += 1
		print("FAIL  无法扫描目录：", path)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			var child := path.path_join(name)
			if dir.current_is_dir():
				_collect_scripts(child, out)
			elif name.ends_with(".gd"):
				out.append(child)
		name = dir.get_next()
	dir.list_dir_end()
