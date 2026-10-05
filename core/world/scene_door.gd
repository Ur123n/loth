class_name SceneDoor
extends Area2D

## Generic exterior/interior scene door. The destination is data, not hardcoded
## game logic. Automatic transition is optional; phase-one doors use E/interact.

signal transition_requested(destination_scene: String, destination_marker: String, actor: Node)

@export_file("*.tscn") var destination_scene: String = ""
@export var destination_marker: String = "spawn"
@export var automatic: bool = false
@export var interact_action: StringName = &"interact"
@export var accepted_group: StringName = &"player"

var _actors_inside: Array[Node] = []
var _transitioning := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if automatic or _actors_inside.is_empty() or _transitioning:
		return
	if event.is_action_pressed(interact_action):
		activate(_actors_inside[0])
		get_viewport().set_input_as_handled()


func can_activate(actor: Node = null) -> bool:
	if destination_scene.is_empty() or not FileAccess.file_exists(destination_scene):
		return false
	if actor == null:
		return true
	return accepted_group.is_empty() or actor.is_in_group(accepted_group)


func describe_transition() -> Dictionary:
	return {
		"scene": destination_scene,
		"marker": destination_marker,
		"exists": FileAccess.file_exists(destination_scene),
	}


func activate(actor: Node = null) -> Error:
	if _transitioning:
		return ERR_BUSY
	if not can_activate(actor):
		push_warning("场景门目标不可用：%s" % destination_scene)
		return ERR_FILE_NOT_FOUND
	_transitioning = true
	transition_requested.emit(destination_scene, destination_marker, actor)
	var error := get_tree().change_scene_to_file(destination_scene)
	if error != OK:
		_transitioning = false
	return error


func _on_body_entered(body: Node) -> void:
	if not can_activate(body):
		return
	if not _actors_inside.has(body):
		_actors_inside.append(body)
	if automatic:
		activate(body)


func _on_body_exited(body: Node) -> void:
	_actors_inside.erase(body)

