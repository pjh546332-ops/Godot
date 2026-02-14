extends Resource
class_name TrpgMapData

## 맵 데이터 리소스. 격자 크기(9~15), 장애물, 배치 앵커, 스폰 위치.

const MAP_SIZE_MIN: int = 9
const MAP_SIZE_MAX: int = 15

@export var map_id: String = "default"
@export var width: int = 10
@export var height: int = 10
@export var blocked_cells: Array[Vector2i] = []
@export var ally_deploy_anchor: Vector2i = Vector2i(0, 0)  ## 4x4 배치 그리드의 좌상단 타일
@export var deploy_size: Vector2i = Vector2i(4, 4)  ## 배치 그리드 크기 (고정 4x4)
@export var enemy_spawn: Array[Vector2i] = []  ## 적 스폰. 비어 있으면 오른쪽 3열에서 자동 배치
@export var theme: String = "default"


func get_effective_width() -> int:
	return clampi(width, MAP_SIZE_MIN, MAP_SIZE_MAX)


func get_effective_height() -> int:
	return clampi(height, MAP_SIZE_MIN, MAP_SIZE_MAX)


func get_clamped_anchor() -> Vector2i:
	var w: int = get_effective_width()
	var h: int = get_effective_height()
	var dx: int = mini(deploy_size.x, w)
	var dy: int = mini(deploy_size.y, h)
	var ax: int = clampi(ally_deploy_anchor.x, 0, maxi(0, w - dx))
	var ay: int = clampi(ally_deploy_anchor.y, 0, maxi(0, h - dy))
	if ax != ally_deploy_anchor.x or ay != ally_deploy_anchor.y:
		print("[TrpgMapData] ally_deploy_anchor clamped from (%d,%d) to (%d,%d) for map %dx%d" % [ally_deploy_anchor.x, ally_deploy_anchor.y, ax, ay, w, h])
	var clamped: Vector2i = Vector2i(ax, ay)
	_warn_anchor_blocked(clamped, w, h)
	return clamped


func _warn_anchor_blocked(anchor: Vector2i, w: int, h: int) -> void:
	var blocked_count: int = 0
	var total: int = deploy_size.x * deploy_size.y
	for dy in range(deploy_size.y):
		for dx in range(deploy_size.x):
			var cell: Vector2i = anchor + Vector2i(dx, dy)
			if cell.x >= 0 and cell.x < w and cell.y >= 0 and cell.y < h:
				for bc in blocked_cells:
					if bc == cell:
						blocked_count += 1
						break
	if blocked_count > total >> 1:
		print("[TrpgMapData] WARNING: deploy anchor (%d,%d) has %d/%d cells blocked - consider moving anchor" % [anchor.x, anchor.y, blocked_count, total])


func deploy_to_map_cell(deploy_cell: Vector2i) -> Vector2i:
	return get_clamped_anchor() + deploy_cell


func is_deploy_cell_blocked(deploy_cell: Vector2i) -> bool:
	var map_cell: Vector2i = deploy_to_map_cell(deploy_cell)
	for bc in blocked_cells:
		if bc == map_cell:
			return true
	return false


func is_cell_in_bounds(cell: Vector2i) -> bool:
	var w: int = get_effective_width()
	var h: int = get_effective_height()
	return cell.x >= 0 and cell.x < w and cell.y >= 0 and cell.y < h
