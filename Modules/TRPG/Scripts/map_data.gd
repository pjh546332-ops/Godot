extends Resource
class_name TrpgMapData

## 맵 데이터 리소스. 격자 크기, 장애물, 배치 앵커, 스폰 위치.

@export var map_id: String = "default"
@export var width: int = 10
@export var height: int = 10
@export var blocked_cells: Array[Vector2i] = []
@export var ally_deploy_anchor: Vector2i = Vector2i(0, 0)  ## 4x4 배치 그리드의 좌상단 타일
@export var deploy_size: Vector2i = Vector2i(4, 4)  ## 배치 그리드 크기 (고정 4x4)
@export var enemy_spawn: Array[Vector2i] = []  ## 적 스폰. 비어 있으면 오른쪽 3열에서 자동 배치
@export var theme: String = "default"


func deploy_to_map_cell(deploy_cell: Vector2i) -> Vector2i:
	return ally_deploy_anchor + deploy_cell


func is_deploy_cell_blocked(deploy_cell: Vector2i) -> bool:
	var map_cell: Vector2i = deploy_to_map_cell(deploy_cell)
	for bc in blocked_cells:
		if bc == map_cell:
			return true
	return false
