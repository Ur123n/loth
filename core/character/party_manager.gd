class_name PartyManager
extends RefCounted

## 四人小队管理器（逻辑层）。
## 持有 4 名角色数据、记录当前选中角色、响应 ↑/↓ 切换。
## 地图上只有一个可见实体：被选中的角色代表整个队伍。

signal character_selected(index: int, character: CharacterData)

const PARTY_SIZE := 4

var characters: Array[CharacterData] = []
var current_index: int = 0


func setup(party_characters: Array) -> void:
	characters.clear()
	for entry in party_characters:
		if entry is CharacterData:
			characters.append(entry)
	current_index = 0


func get_current_character() -> CharacterData:
	if characters.is_empty():
		return null
	return characters[current_index]


func select_previous() -> void:
	_cycle(-1)


func select_next() -> void:
	_cycle(1)


func _cycle(offset: int) -> void:
	if characters.is_empty():
		return
	current_index = wrapi(current_index + offset, 0, characters.size())
	character_selected.emit(current_index, characters[current_index])
