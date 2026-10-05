class_name DialogueHistory
extends RefCounted

## 对话历史：记录会话内已展示完成的台词（说话人 / 文本 / 头像 / 颜色），
## 供历史面板回看；start_session() 时清空。跨会话持久化由 GameState 的剧情 Flag 负责。

var lines: Array[Dictionary] = []


func append_line(speaker: String, text: String, avatar_path: String, color: Color) -> void:
	if text.is_empty():
		return
	lines.append({
		"speaker": speaker,
		"text": text,
		"avatar": avatar_path,
		"color": color,
	})


func clear() -> void:
	lines.clear()


func size() -> int:
	return lines.size()
