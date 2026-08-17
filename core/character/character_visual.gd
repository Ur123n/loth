class_name CharacterVisual
extends Node2D

## 角色表现层。
## 当前缺少美术资源，使用色块占位；预留 set_texture() 接口，
## 日后拿到精灵图后直接替换即可。

@export var placeholder_color: Color = Color(0.42, 0.60, 0.90)
@export var block_size: Vector2 = Vector2(40, 40)

var _block: ColorRect
var _sprite: Sprite2D


func _ready() -> void:
	_block = ColorRect.new()
	_block.name = "PlaceholderBlock"
	_block.color = placeholder_color
	_block.size = block_size
	_block.position = -block_size * 0.5
	add_child(_block)


func set_placeholder_color(color: Color) -> void:
	placeholder_color = color
	if _block != null:
		_block.color = color


## 预留接口：未来用真实美术资源替换色块。
func set_texture(texture: Texture2D) -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "CharacterSprite"
		_sprite.centered = true
		add_child(_sprite)
	_sprite.texture = texture
	if _block != null:
		_block.hide()
