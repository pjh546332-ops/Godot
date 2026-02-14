extends Node
class_name TrpgBattleCameraController

## 전투 카메라: 고정 각도(45° 내려다보기), 팬(드래그), 줌(휠). 회전(ArcShot) 없음.

@export var camera_rig: Node3D
@export var cam: Camera3D
@export var grid_board: GridBoard3D

const PITCH_DEG: float = 45.0
const YAW_DEG: float = 45.0
const DIST_MIN: float = 10.0
const DIST_MAX: float = 24.0
const DIST_LERP_MIN: float = 10.0
const DIST_LERP_MAX: float = 18.0
const PAN_SENSITIVITY: float = 0.008
const ZOOM_SENSITIVITY: float = 2.0

var _target_position: Vector3 = Vector3.ZERO
var _distance: float = 14.0
var _view_direction: Vector3
var _bounds: AABB
var _panning: bool = false
var _last_mouse: Vector2


func _ready() -> void:
	var yaw: float = deg_to_rad(YAW_DEG)
	var pitch: float = deg_to_rad(PITCH_DEG)
	_view_direction = Vector3(
		sin(yaw) * cos(pitch),
		-sin(pitch),
		-cos(yaw) * cos(pitch)
	).normalized()
	_update_camera_transform()


func set_map_size(width: int, height: int) -> void:
	if not grid_board:
		return
	_bounds = grid_board.get_world_bounds()
	var tile: float = grid_board.TILE_SIZE
	var cx: float = float(width) * 0.5 * tile
	var cz: float = float(height) * 0.5 * tile
	_target_position = Vector3(cx, 0, cz)
	var map_scale: float = float(maxi(width, height))
	_distance = clampf(lerpf(DIST_LERP_MIN, DIST_LERP_MAX, (map_scale - 9.0) / 6.0), DIST_MIN, DIST_MAX)
	_clamp_target_to_bounds()
	_update_camera_transform()


func set_bounds_from_board() -> void:
	if grid_board:
		_bounds = grid_board.get_world_bounds()


func _clamp_target_to_bounds() -> void:
	if _bounds.size == Vector3.ZERO:
		return
	_target_position.x = clampf(_target_position.x, _bounds.position.x, _bounds.position.x + _bounds.size.x)
	_target_position.z = clampf(_target_position.z, _bounds.position.z, _bounds.position.z + _bounds.size.z)
	_target_position.y = 0.0


func _update_camera_transform() -> void:
	if not camera_rig or not cam:
		return
	camera_rig.global_position = _target_position
	camera_rig.rotation = Vector3.ZERO
	cam.position = -_view_direction * _distance
	cam.look_at(camera_rig.global_position + Vector3(0, 0.01, 0), Vector3.UP)


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_panning = true
				_last_mouse = mb.position
			else:
				_panning = false
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - ZOOM_SENSITIVITY, DIST_MIN, DIST_MAX)
			_update_camera_transform()
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + ZOOM_SENSITIVITY, DIST_MIN, DIST_MAX)
			_update_camera_transform()
			return true
	if event is InputEventMouseMotion and _panning:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = mm.position - _last_mouse
		_last_mouse = mm.position
		set_bounds_from_board()
		var right: Vector3 = Vector3(_view_direction.z, 0, -_view_direction.x).normalized()
		var forward: Vector3 = Vector3(-right.z, 0, right.x)
		if forward.length() > 0.001:
			forward = forward.normalized()
		var move: float = PAN_SENSITIVITY * _distance
		_target_position += right * (-delta.x * move) + forward * (-delta.y * move)
		_target_position.y = 0.0
		_clamp_target_to_bounds()
		_update_camera_transform()
		return true
	return false


func _input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()
