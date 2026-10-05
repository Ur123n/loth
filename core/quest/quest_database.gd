extends Node
class_name QuestDatabase

## 任务数据库（Autoload：QuestDB）
## 读取 res://content/quests/*.json（每份文件一个任务对象，由 编辑器/quest_editor.py 生成/校验）。
## 基础校验问题以 push_warning 输出。

const QUEST_DIR := "res://content/quests"

const _QuestData := preload("quest_data.gd")

var quests: Dictionary = {}       # quest_id -> QuestData
var problems: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	quests.clear()
	problems.clear()
	var dir := DirAccess.open(QUEST_DIR)
	if dir == null:
		push_warning("[QuestDB] 任务目录不存在：%s" % QUEST_DIR)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path := QUEST_DIR + "/" + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			problems.append("无法读取 %s" % path)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			problems.append("%s 不是有效的任务 JSON" % path)
			continue
		var quest = _QuestData.from_dict(parsed)
		if quest.quest_id.is_empty():
			problems.append("%s 缺少 id" % path)
		if quests.has(quest.quest_id):
			problems.append("任务 id 重复：%s（%s）" % [quest.quest_id, path])
		quests[quest.quest_id] = quest
	for quest_id in quests:
		var quest = quests[quest_id]
		var local: Array[String] = []
		quest.validate(local)
		for p in local:
			problems.append("%s：%s" % [quest_id, p])
	for p in problems:
		push_warning("[QuestDB] %s" % p)


func get_quest(quest_id: String):
	return quests.get(quest_id)


func has_quest(quest_id: String) -> bool:
	return quests.has(quest_id)


## 按 id 排序返回全部任务（自动接取分支按此顺序找首个满足 start 的任务，顺序确定）。
func all_quests() -> Array:
	var ids: Array = []
	for quest_id in quests:
		ids.append(quest_id)
	ids.sort()
	var result: Array = []
	for quest_id in ids:
		result.append(quests[quest_id])
	return result
