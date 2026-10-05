class_name CharacterVisual
extends Node2D

## 角色表现层。
## 存活素材缺失时使用色块占位；死亡素材缺失时改用独立骨堆形态。
## 尸骸表现不会修改存活贴图颜色。

@export var placeholder_color: Color = Color(0.42, 0.60, 0.90)
@export var block_size: Vector2 = Vector2(40, 40)

var _block: ColorRect
var _sprite: Sprite2D
var _corpse_shape: Polygon2D
var _corpse_bones: Line2D
var visual_state: String = "living_placeholder"


func _ready() -> void:
	_block = ColorRect.new()
	_block.name = "PlaceholderBlock"
	_block.color = placeholder_color
	_block.size = block_size
	# Character 根节点是脚点，YSort、存档与世界交互都以这里为准。
	_block.position = Vector2(-block_size.x * 0.5, -block_size.y)
	add_child(_block)


func set_placeholder_color(color: Color) -> void:
	placeholder_color = color
	if _block != null:
		_block.color = color


## 死亡贴图缺失时的独立尸骸形态：隐藏存活形象，显示扁平骨堆，不做灰度染色。
func show_corpse_placeholder() -> void:
	if _sprite != null:
		_sprite.hide()
	if _block != null:
		_block.hide()
	if _corpse_shape == null:
		_corpse_shape = Polygon2D.new()
		_corpse_shape.name = "CorpseShape"
		_corpse_shape.color = Color("#4b3023")
		_corpse_shape.polygon = PackedVector2Array([
			Vector2(-15, -7), Vector2(-9, -12), Vector2(2, -11),
			Vector2(15, -6), Vector2(11, -1), Vector2(-11, -1),
		])
		add_child(_corpse_shape)
	if _corpse_bones == null:
		_corpse_bones = Line2D.new()
		_corpse_bones.name = "CorpseBones"
		_corpse_bones.default_color = Color("#b7a37b")
		_corpse_bones.width = 2.0
		_corpse_bones.antialiased = false
		_corpse_bones.points = PackedVector2Array([
			Vector2(-8, -9), Vector2(8, -3), Vector2.ZERO,
			Vector2(8, -9), Vector2(-8, -3),
		])
		add_child(_corpse_bones)
	_corpse_shape.show()
	_corpse_bones.show()
	visual_state = "corpse_placeholder"


## 预留接口：未来用真实美术资源替换色块。
func set_texture(texture: Texture2D) -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "CharacterSprite"
		_sprite.centered = true
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.position = Vector2(0, -texture.get_height() * 0.5) if texture != null else Vector2.ZERO
	_sprite.visible = texture != null
	if _block != null:
		_block.hide()
	if _corpse_shape != null:
		_corpse_shape.hide()
	if _corpse_bones != null:
		_corpse_bones.hide()
	visual_state = "texture" if texture != null else "living_placeholder"
