extends Node3D
class_name InputRaycast3D

## 레이캐스트로 타일/유닛 클릭 감지.

signal tile_hit(cell: Vector2i)
signal unit_hit(unit: Node)
## 이동 중 우클릭 시 발행. 이동 취소 없이 "이동 완료 후 해제" 예약.
signal cancel_requested

@export var grid_board: GridBoard3D
@export var camera: Camera3D
@export var units_root: Node3D

## 이동 중일 때 true. battle_scene에서 설정.
var input_locked: bool = false


func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()


func _input(event: InputEvent) -> void:
	if input_locked:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				cancel_requested.emit()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_perform_raycast()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			tile_hit.emit(Vector2i(-1, -1))
	else:
		if event.is_action_pressed("click_select"):
			_perform_raycast()
		elif event.is_action_pressed("click_cancel"):
			tile_hit.emit(Vector2i(-1, -1))


func _perform_raycast() -> void:
	if not camera:
		return
	var from: Vector3 = camera.project_ray_origin(get_viewport().get_mouse_position())
	var dir: Vector3 = camera.project_ray_normal(get_viewport().get_mouse_position())
	var to: Vector3 = from + dir * 1000.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = TrpgLayers.COLLISION_MASK_FLOOR_AND_UNIT
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		tile_hit.emit(Vector2i(-1, -1))
		return
	var collider: Object = result.get("collider", null)
	if not collider:
		tile_hit.emit(Vector2i(-1, -1))
		return
	var node: Node = collider as Node
	if not node:
		tile_hit.emit(Vector2i(-1, -1))
		return
	while node:
		if node is BattleUnit3D:
			unit_hit.emit(node)
			return
		node = node.get_parent()
	if grid_board:
		var cell: Vector2i = grid_board.get_cell_from_collider(collider)
		if cell.x >= 0 and cell.y >= 0:
			tile_hit.emit(cell)
		else:
			tile_hit.emit(Vector2i(-1, -1))
	else:
		tile_hit.emit(Vector2i(-1, -1))
