extends Node

## 独立摄像机控制器（Autoload：CameraCtrl）
## 提供移动 / 跟随 / 缩放 / 震屏 / 复位等指令，供剧情系统与编辑器直接驱动。
## 摄像机节点挂在 root 下，跨场景存活；ensure_camera() 在无摄像机时创建一个
## 位于视口中心、zoom=1 的 Camera2D（与不挂摄像机的画面一致，不改变现有表现）。
## 所有方法立即返回；需要等待完成时由调用方 await 返回的 Tween。

const DEFAULT_POSITION := Vector2(640, 360)
const DEFAULT_ZOOM := Vector2.ONE

var camera: Camera2D
var _follow_target: Node2D
var _follow_offset: Vector2 = Vector2.ZERO
var _shake_amplitude: float = 0.0


func _process(_delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if _shake_amplitude > 0.01:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amplitude
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
	if _follow_target != null and is_instance_valid(_follow_target):
		camera.position = _follow_target.global_position + _follow_offset


## 确保当前有可用的摄像机；场景已自带摄像机时复用（不抢占）。
func ensure_camera() -> Camera2D:
	if camera != null and is_instance_valid(camera):
		return camera
	var existing := get_viewport().get_camera_2d()
	if existing != null:
		camera = existing
		return camera
	var cam := Camera2D.new()
	cam.name = "StoryCamera2D"
	cam.position = DEFAULT_POSITION
	cam.zoom = DEFAULT_ZOOM
	cam.tree_entered.connect(func() -> void: cam.make_current())
	get_tree().root.add_child.call_deferred(cam)
	camera = cam
	return camera


## 镜头移动到目标位置；可选 zoom 同步缩放。返回 Tween，blocking 指令可 await。
func move_to(target: Vector2, duration: float = 1.0, transition: int = Tween.TRANS_SINE,
		easing: int = Tween.EASE_IN_OUT, zoom: Variant = null) -> Tween:
	ensure_camera()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(camera, "position", target, maxf(duration, 0.0)) \
		.set_trans(transition).set_ease(easing)
	if zoom != null:
		tween.tween_property(camera, "zoom", _to_zoom(zoom), maxf(duration, 0.0)) \
			.set_trans(transition).set_ease(easing)
	return tween


func snap_to(target: Vector2) -> void:
	ensure_camera()
	camera.position = target


## 跟随某个节点（持续跟随，直到 unfollow / reset）。
func follow_node(node: Node2D, offset: Vector2 = Vector2.ZERO) -> void:
	ensure_camera()
	_follow_target = node
	_follow_offset = offset
	if node != null:
		camera.position = node.global_position + offset


func unfollow() -> void:
	_follow_target = null


func zoom_to(zoom: Variant, duration: float = 1.0, transition: int = Tween.TRANS_SINE,
		easing: int = Tween.EASE_IN_OUT) -> Tween:
	ensure_camera()
	var tween := create_tween()
	tween.tween_property(camera, "zoom", _to_zoom(zoom), maxf(duration, 0.0)) \
		.set_trans(transition).set_ease(easing)
	return tween


## 震屏：强度随时间衰减到 0。返回 Tween，blocking 指令可 await。
func shake(strength: float, duration: float = 1.0) -> Tween:
	ensure_camera()
	_shake_amplitude = maxf(strength, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "_shake_amplitude", 0.0, maxf(duration, 0.0))
	return tween


## 复位到默认位置 / 缩放，停止跟随与震屏。
func reset() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	_follow_target = null
	_shake_amplitude = 0.0
	camera.offset = Vector2.ZERO
	var tween := create_tween().set_parallel(true)
	tween.tween_property(camera, "position", DEFAULT_POSITION, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", DEFAULT_ZOOM, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _to_zoom(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(float(value), float(value))
