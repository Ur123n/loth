class_name Character
extends Node2D

## 角色逻辑节点：持有角色数据，处理四向移动。
## 移动输入使用 InputMap 中的 move_* 动作，后续可方便改键。

@export var character_data: CharacterData
@export var move_speed: float = 180.0
@export var input_enabled: bool = true
@export var move_bounds: Rect2 = Rect2()   # 若设置，移动限制在该矩形（地图范围）内；为空则回退到视口限制

const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
const MOVE_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

var _visual: CharacterVisual
var _name_label: Label
var _last_move_action: StringName = &""


func _ready() -> void:
	_visual = CharacterVisual.new()
	_visual.name = "Visual"
	add_child(_visual)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.position = Vector2(-40, -56)
	_name_label.size = Vector2(80, 22)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	add_child(_name_label)

	refresh_visual_from_data()


## 切换小队选中角色时调用：更新姓名与占位色块等表现。
func apply_character_data(data: CharacterData) -> void:
	character_data = data
	refresh_visual_from_data()


func refresh_visual_from_data() -> void:
	if character_data == null:
		_name_label.text = "角色"
		return
	_name_label.text = character_data.character_name
	_visual.set_placeholder_color(character_data.block_color)
	# 美术接口：经 ArtLoader 加载主体贴图；icon/portrait/animation 供后续 UI 与动画使用
	var texture := ArtLoader.load_texture(character_data.art_path)
	if texture != null:
		_visual.set_texture(texture)


## 四向移动：记录最后按下的方向键，保证同一时刻只朝一个方向移动。
func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	for i in MOVE_ACTIONS.size():
		if event.is_action_pressed(MOVE_ACTIONS[i]):
			_last_move_action = MOVE_ACTIONS[i]
			return
		if event.is_action_released(MOVE_ACTIONS[i]) and _last_move_action == MOVE_ACTIONS[i]:
			_last_move_action = _first_pressed_move_action()
			return


func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	var direction := _current_direction()
	if direction == Vector2.ZERO:
		return
	position += direction * move_speed * delta

	# 移动限制：优先地图范围（move_bounds），否则限制在视口内
	if move_bounds.size != Vector2.ZERO:
		position = position.clamp(move_bounds.position, move_bounds.end)
	else:
		var viewport_rect := get_viewport_rect()
		var margin := 24.0
		position = position.clamp(
			viewport_rect.position + Vector2(margin, margin),
			viewport_rect.end - Vector2(margin, margin)
		)


func _current_direction() -> Vector2:
	if _last_move_action == &"":
		return Vector2.ZERO
	var index := MOVE_ACTIONS.find(_last_move_action)
	if index < 0:
		return Vector2.ZERO
	return MOVE_DIRECTIONS[index]


func _first_pressed_move_action() -> StringName:
	for action in MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			return action
	return &""
