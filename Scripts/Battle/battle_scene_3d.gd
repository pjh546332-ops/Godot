extends Node3D

## 3D 전술 TRPG 전투 씬: 격자 보드, 유닛, 이동, A* 경로.

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var light: DirectionalLight3D = $DirectionalLight3D
@onready var camera_rig: Node3D = $CameraRig
@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var grid_board: GridBoard3D = $GridBoard
@onready var units_root: Node3D = $UnitsRoot
@onready var input_raycast: InputRaycast3D = $InputRaycast
@onready var debug_label: Label = $CanvasLayer/Label

const MOVE_DURATION: float = 0.3
const HIGHLIGHT_COLOR: Color = Color(0.3, 0.9, 0.4, 0.8)

var _selected_unit: BattleUnit3D = null
var _reachable_cells: Array[Vector2i] = []
var _pathfinder: PathfindingAStar
var _range_finder: RangeFinder
var _move_tween: Tween
var _is_moving: bool = false
var _deselect_after_move: bool = false  ## 이동 중 우클릭 시 true, 이동 완료 후 해제


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_pathfinding()
	_setup_units()
	_connect_signals()
	_update_debug_label()


func _setup_environment() -> void:
	if world_env:
		if not world_env.environment:
			var env: Environment = Environment.new()
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.2, 0.25, 0.35, 1.0)
			world_env.environment = env
	if light:
		light.rotation_degrees = Vector3(-50, 30, 0)
		light.light_energy = 1.2


func _setup_camera() -> void:
	if not cam:
		return
	var w: int = grid_board.GRID_WIDTH if grid_board else 10
	var h: int = grid_board.GRID_HEIGHT if grid_board else 10
	var cx: float = float(w) * 0.5 * grid_board.TILE_SIZE if grid_board else 5.0
	var cz: float = float(h) * 0.5 * grid_board.TILE_SIZE if grid_board else 5.0
	var target: Vector3 = Vector3(cx, 0, cz)
	var dist: float = 14.0
	var yaw: float = deg_to_rad(45)
	var pitch: float = deg_to_rad(45)
	var dir: Vector3 = Vector3(
		sin(yaw) * cos(pitch),
		-sin(pitch),
		-cos(yaw) * cos(pitch)
	)
	cam.global_position = target - dir * dist
	cam.look_at(target, Vector3.UP)


func _setup_pathfinding() -> void:
	var w: int = grid_board.GRID_WIDTH if grid_board else 10
	var h: int = grid_board.GRID_HEIGHT if grid_board else 10
	var blocked: Array = grid_board.get_blocked_cells() if grid_board else []
	_pathfinder = PathfindingAStar.new()
	_pathfinder.setup(w, h, blocked)
	_range_finder = RangeFinder.new()
	_range_finder.setup(w, h, blocked)


func _setup_units() -> void:
	if not units_root or not grid_board:
		return
	var idx: int = 0
	for u in units_root.get_children():
		if u is BattleUnit3D:
			var start_cell: Vector2i = Vector2i(1 + idx, 1) if idx == 0 else Vector2i(1, 2 + idx)
			while _range_finder.is_blocked(start_cell) or _is_cell_occupied_by_unit(start_cell, u):
				start_cell.x += 1
				if start_cell.x >= grid_board.GRID_WIDTH:
					start_cell.x = 0
					start_cell.y += 1
				if start_cell.y >= grid_board.GRID_HEIGHT:
					break
			u.grid_cell = start_cell
			u.global_position = grid_board.get_world_at_cell(start_cell) + Vector3(0, 0.5, 0)
			_range_finder.set_occupied(start_cell, true)
			if u.has_signal("clicked"):
				u.clicked.connect(_on_unit_clicked.bind(u))
			idx += 1


func _is_cell_occupied_by_unit(cell: Vector2i, exclude: Node) -> bool:
	for u in units_root.get_children():
		if u == exclude:
			continue
		if u is BattleUnit3D and u.grid_cell == cell:
			return true
	return false


func _connect_signals() -> void:
	if input_raycast:
		if input_raycast.has_signal("tile_hit"):
			input_raycast.tile_hit.connect(_on_tile_hit)
		if input_raycast.has_signal("unit_hit"):
			input_raycast.unit_hit.connect(_on_unit_hit_from_raycast)
		if input_raycast.has_signal("cancel_requested"):
			input_raycast.cancel_requested.connect(_on_cancel_requested)
	if input_raycast:
		input_raycast.grid_board = grid_board
		input_raycast.camera = cam
		input_raycast.units_root = units_root


func _on_cancel_requested() -> void:
	if _is_moving:
		_deselect_after_move = true
	else:
		_deselect_unit()


func _on_unit_clicked(unit: BattleUnit3D) -> void:
	if _is_moving:
		return
	_select_unit(unit)


func _on_unit_hit_from_raycast(unit: Node) -> void:
	if _is_moving:
		return
	if unit is BattleUnit3D:
		_select_unit(unit)


func _on_tile_hit(cell: Vector2i) -> void:
	if _is_moving:
		return
	if cell.x < 0 or cell.y < 0:
		_deselect_unit()
		return
	if _selected_unit:
		for c in _reachable_cells:
			if c.x == cell.x and c.y == cell.y:
				_move_unit_to(_selected_unit, cell)
				return
		_deselect_unit()
		return
	_deselect_unit()


func _select_unit(unit: BattleUnit3D) -> void:
	_deselect_unit()
	_selected_unit = unit
	_reachable_cells = _range_finder.get_reachable_cells(unit.grid_cell, unit.move_range, true)
	grid_board.highlight_cells(_reachable_cells, HIGHLIGHT_COLOR)
	_update_debug_label()


func _deselect_unit() -> void:
	_selected_unit = null
	_reachable_cells.clear()
	grid_board.clear_highlights()
	_update_debug_label()


func _move_unit_to(unit: BattleUnit3D, target: Vector2i) -> void:
	var path: PackedVector2Array = _pathfinder.find_path(unit.grid_cell, target)
	if path.size() < 2:
		_deselect_unit()
		return
	_is_moving = true
	_deselect_after_move = false
	if input_raycast:
		input_raycast.input_locked = true
	_range_finder.set_occupied(unit.grid_cell, false)
	_range_finder.set_occupied(target, true)
	unit.set_grid_cell(target)
	_deselect_unit()
	_update_debug_label()
	_animate_move(unit, path)


func _animate_move(unit: BattleUnit3D, path: PackedVector2Array) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_parallel(false)
	for i in range(1, path.size()):
		var cell: Vector2i = Vector2i(path[i].x, path[i].y)
		var tw: Vector3 = grid_board.get_world_at_cell(cell)
		tw.y = 0.5
		_move_tween.tween_property(unit, "global_position", tw, MOVE_DURATION / float(path.size() - 1)).set_ease(Tween.EASE_IN_OUT)
	_move_tween.finished.connect(_on_move_finished)


func _on_move_finished() -> void:
	_is_moving = false
	if input_raycast:
		input_raycast.input_locked = false
	_update_debug_label()
	if _deselect_after_move:
		_deselect_after_move = false
		_deselect_unit()


func _update_debug_label() -> void:
	if not debug_label:
		return
	var s: String = "선택: 없음"
	if _selected_unit:
		var c: Vector2i = _selected_unit.grid_cell
		s = "선택: %s @ (%d,%d)" % [_selected_unit.name, c.x, c.y]
	debug_label.text = s
