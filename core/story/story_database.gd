extends Node

## 剧情数据库（Autoload：StoryDB）
## 读取 res://content/stories/*.json；每份文件一个剧情对象。
## 基础校验问题以 push_warning 输出；指令类型校验在 StoryRunner 注册完成后进行。

const STORY_DIR := "res://content/stories"

var stories: Dictionary = {}       # story_id -> StoryData
var problems: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	stories.clear()
	problems.clear()
	var dir := DirAccess.open(STORY_DIR)
	if dir == null:
		push_warning("[StoryDB] 剧情目录不存在：%s" % STORY_DIR)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		if file_name == "triggers.json":
			continue    # 触发器配置由 StoryTrigger 加载，不是剧情本体
		var path := STORY_DIR + "/" + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			problems.append("无法读取 %s" % path)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			problems.append("%s 不是有效的剧情 JSON" % path)
			continue
		var story := StoryData.from_dict(parsed)
		if story.story_id.is_empty():
			problems.append("%s 缺少 id" % path)
		if stories.has(story.story_id):
			problems.append("剧情 id 重复：%s（%s）" % [story.story_id, path])
		stories[story.story_id] = story
	for story_id in stories:
		var story: StoryData = stories[story_id]
		var local: Array[String] = []
		story.validate(local)
		for p in local:
			problems.append("%s：%s" % [story_id, p])
	for p in problems:
		push_warning("[StoryDB] %s" % p)


## StoryRunner 注册完指令后调用：按已知类型列表做完整校验。
func validate_known_types(known_types: Array) -> void:
	for story_id in stories:
		var story: StoryData = stories[story_id]
		var local: Array[String] = []
		story.validate(local, known_types)
		for p in local:
			push_warning("[StoryDB] %s：%s" % [story_id, p])


func get_story(story_id: String) -> StoryData:
	return stories.get(story_id)


func has_story(story_id: String) -> bool:
	return stories.has(story_id)
