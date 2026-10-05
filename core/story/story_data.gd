class_name StoryData
extends Resource

## 剧情数据（数据驱动，由 content/stories/*.json 加载）。
## 指令列表保持原始 Dictionary，由 StoryRunner 解释执行；
## 数据校验在 StoryDB.reload() / StoryRunner._ready() 与 tests/story 中进行。

var story_id: String = ""
var title: String = ""
var description: String = ""
var instructions: Array = []
var raw: Dictionary = {}


static func from_dict(data: Dictionary) -> StoryData:
	var story := StoryData.new()
	story.raw = data
	story.story_id = str(data.get("id", ""))
	story.title = str(data.get("title", ""))
	story.description = str(data.get("description", ""))
	var ins = data.get("instructions", [])
	story.instructions = ins if ins is Array else []
	return story


## 校验数据格式；known_types 为空数组时跳过类型检查（由 Runner 注册后校验）。
func validate(problems: Array, known_types: Array = []) -> void:
	if story_id.is_empty():
		problems.append("id 为空")
	if title.is_empty():
		problems.append("title 为空")
	if instructions.is_empty():
		problems.append("instructions 为空")
	for i in instructions.size():
		var ins = instructions[i]
		if not ins is Dictionary:
			problems.append("instructions[%d] 不是对象" % i)
			continue
		_validate_instruction(problems, ins, known_types, i)


func _validate_instruction(problems: Array, ins: Dictionary, known_types: Array, index: int) -> void:
	var type := str(ins.get("type", ""))
	if type.is_empty():
		problems.append("instructions[%d] 缺少 type" % index)
		return
	if type == "parallel":
		var children = ins.get("instructions", [])
		if children is Array:
			for j in children.size():
				if children[j] is Dictionary:
					_validate_instruction(problems, children[j], known_types, index)
		return
	if known_types.size() > 0 and not known_types.has(type):
		problems.append("instructions[%d] 未知类型 %s" % [index, type])
	if type == "if":
		for branch_name in ["then", "else"]:
			var branch = ins.get(branch_name, [])
			if branch is Array:
				for j in branch.size():
					if branch[j] is Dictionary:
						_validate_instruction(problems, branch[j], known_types, index)
