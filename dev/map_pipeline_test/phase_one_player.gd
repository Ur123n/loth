extends CharacterBody2D

@export var speed := 260.0
@export var camera_zoom := Vector2(0.45, 0.45)


func _ready() -> void:
	add_to_group("player")
	var camera := get_node_or_null(NodePath("Camera2D")) as Camera2D
	if camera != null:
		camera.zoom = camera_zoom


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

