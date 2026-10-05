class_name QuestData
extends Resource

## 任务数据（数据驱动，由 编辑器/quest_editor.py 或人工/AI 直接编辑 content/quests/*.json）。
## 任务没有 UI：状态记录在 GameState.quest_state（随存档持久化），
## 完成条件满足后由 QuestSystem 自动推进到下一任务；分支任务按前置条件不同进入不同后续任务。

const _Condition := preload("quest_condition.gd")

var quest_id: String = ""
var name: String = ""
var description: String = ""            # 线索/背景文本（由 NPC 与文本提供）
var start_condition: Dictionary = {}    # 可选：满足后自动接取（如与某 NPC 交谈）
var complete_condition: Dictionary = {} # 完成条件（必须，满足即自动完成）
var rewards: Array = []                 # 奖励列表：[{type, ...}]
var next_quest: String = ""             # 默认后续任务（可选）
var branches: Array = []                # 分支：[{when: 条件, next: 任务id}]，按顺序取首个满足


static func from_dict(d: Dictionary):
	# 用绝对路径加载自身，避免依赖全局 class 缓存（无头测试/新文件均可用）
	var q = load("res://core/quest/quest_data.gd").new()
	q.quest_id = str(d.get("id", ""))
	q.name = str(d.get("name", ""))
	q.description = str(d.get("description", ""))
	var sc = d.get("start", {})
	if sc is Dictionary:
		q.start_condition = sc
	var cc = d.get("complete", {})
	if cc is Dictionary:
		q.complete_condition = cc
	var rw = d.get("rewards", [])
	if rw is Array:
		q.rewards = rw
	q.next_quest = str(d.get("next", ""))
	var br = d.get("branches", [])
	if br is Array:
		q.branches = br
	return q


func validate(problems: Array[String]) -> void:
	if quest_id.is_empty():
		problems.append("缺少 id")
	if name.is_empty():
		problems.append("%s 缺少 name" % quest_id)
	if complete_condition.is_empty():
		problems.append("%s 缺少 complete 条件" % quest_id)
	else:
		_Condition.validate(complete_condition, problems, quest_id)
	if not start_condition.is_empty():
		_Condition.validate(start_condition, problems, quest_id)
	for i in rewards.size():
		var r = rewards[i]
		if not r is Dictionary:
			problems.append("%s rewards[%d] 不是对象" % [quest_id, i])
			continue
		var type := str(r.get("type", ""))
		if not ["coin", "item", "xp", "flag", "card", "equipment", "text"].has(type):
			problems.append("%s rewards[%d] 未知奖励类型：%s" % [quest_id, i, type])
	for i in branches.size():
		var b = branches[i]
		if not b is Dictionary:
			problems.append("%s branches[%d] 不是对象" % [quest_id, i])
			continue
		if not b.has("next"):
			problems.append("%s branches[%d] 缺少 next" % [quest_id, i])
		elif str(b.get("next", "")).is_empty():
			problems.append("%s branches[%d] next 为空" % [quest_id, i])
		if b.has("when"):
			_Condition.validate(b.get("when", {}), problems, quest_id)
