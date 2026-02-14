extends Node3D

## 3D 전술 TRPG 전투 씬: 격자 보드, 유닛, 턴, 이동, 공격.

enum Mode { NONE, MOVE, ATTACK }

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var light: DirectionalLight3D = $DirectionalLight3D
@onready var camera_rig: Node3D = $CameraRig
@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var grid_board: GridBoard3D = $GridBoard
@onready var units_root: Node3D = $UnitsRoot
@onready var input_raycast: InputRaycast3D = $InputRaycast
@onready var debug_label: Label = $CanvasLayer/Label
@onready var action_panel: ActionPanel = $CanvasLayer/ActionPanel
@onready var deployment_ui: TrpgDeploymentUI = $CanvasLayer/DeploymentUI

const MOVE_DURATION: float = 0.3
const HIGHLIGHT_COLOR: Color = Color(0.3, 0.9, 0.4, 0.8)
const ATTACK_HIGHLIGHT_COLOR: Color = Color(0.9, 0.2, 0.2, 0.8)

var _selected_unit: BattleUnit3D = null
var _reachable_cells: Array[Vector2i] = []
var _attackable_cells: Array[Vector2i] = []
var _pathfinder: PathfindingAStar
var _range_finder: RangeFinder
var _move_tween: Tween
var _is_moving: bool = false
var _deselect_after_move: bool = false
var _mode: Mode = Mode.NONE

var turn_manager: TurnManager
var _is_ai_turn: bool = false

@export var unlocked_count: int = 4
@export var skip_deployment: bool = false
@export var available_maps: Array[TrpgMapData] = []
var roster: TrpgRoster
var _current_map: TrpgMapData
const UNIT_PAWN_SCENE: PackedScene = preload("res://Modules/TRPG/Scenes/UnitPawn.tscn")


func _ready() -> void:
	roster = TrpgRoster.new()
	roster.unlocked_count = unlocked_count
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	_setup_environment()
	_current_map = _pick_random_map()
	grid_board.apply_map(_current_map)
	_setup_camera()
	_setup_pathfinding()
	if skip_deployment or not deployment_ui:
		var auto_plan: TrpgDeploymentPlan = _create_auto_plan()
		_do_start_battle(auto_plan)
	else:
		deployment_ui.setup(roster, null, _current_map)
		deployment_ui.deployment_confirmed.connect(_on_deployment_confirmed)
		deployment_ui.visible = true


func _create_auto_plan() -> TrpgDeploymentPlan:
	var p: TrpgDeploymentPlan = TrpgDeploymentPlan.new()
	var ids: Array = roster.get_unlocked_ids()
	var idx: int = 0
	for y in range(4):
		for x in range(4):
			if idx >= ids.size():
				break
			p.set_placement(ids[idx], Vector2i(x, y))
			idx += 1
	return p


func _on_deployment_confirmed(plan: TrpgDeploymentPlan) -> void:
	if deployment_ui:
		deployment_ui.visible = false
	_do_start_battle(plan)


func _do_start_battle(plan: TrpgDeploymentPlan) -> void:
	_setup_units(plan)
	_setup_turn_manager()
	_connect_signals()
	_update_debug_label()
	turn_manager.start_battle()


func _ensure_available_maps() -> void:
	if available_maps.size() > 0:
		return
	var paths: Array[String] = [
		"res://Modules/TRPG/Data/Maps/plains.tres",
		"res://Modules/TRPG/Data/Maps/forest.tres",
		"res://Modules/TRPG/Data/Maps/ruins.tres",
		"res://Modules/TRPG/Data/Maps/bridge.tres",
		"res://Modules/TRPG/Data/Maps/arena.tres"
	]
	for p in paths:
		var m: TrpgMapData = load(p) as TrpgMapData
		if m:
			available_maps.append(m)


func _pick_random_map() -> TrpgMapData:
	_ensure_available_maps()
	if available_maps.size() > 0:
		return available_maps[randi() % available_maps.size()]
	var fallback: TrpgMapData = TrpgMapData.new()
	fallback.map_id = "default"
	fallback.width = 10
	fallback.height = 10
	fallback.blocked_cells = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(5, 4)]
	fallback.ally_deploy_anchor = Vector2i(1, 1)
	fallback.deploy_size = Vector2i(4, 4)
	fallback.enemy_spawn = [Vector2i(8, 4), Vector2i(7, 5)]
	return fallback


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


func _setup_units(plan: TrpgDeploymentPlan = null) -> void:
	if not units_root or not grid_board or not roster or not _current_map:
		return
	var deploy_plan: TrpgDeploymentPlan = plan if plan else _create_auto_plan()
	for dy in range(_current_map.deploy_size.y):
		for dx in range(_current_map.deploy_size.x):
			var deploy_cell: Vector2i = Vector2i(dx, dy)
			var unit_id: String = deploy_plan.get_unit_at_cell(deploy_cell)
			if unit_id.is_empty():
				continue
			var start_cell: Vector2i = _current_map.deploy_to_map_cell(deploy_cell)
			if _range_finder.is_blocked(start_cell) or _is_cell_occupied_by_unit(start_cell, null):
				start_cell = _find_nearest_free_cell(start_cell)
			var ud: TrpgUnitData = TrpgUnitData.load_for_id(unit_id)
			if not ud:
				continue
			var pawn: Node3D = UNIT_PAWN_SCENE.instantiate()
			if pawn is BattleUnit3D:
				var bu: BattleUnit3D = pawn
				bu.data = ud
				bu.team = BattleUnit3D.Team.ALLY
				bu.name = ud.display_name
				while _range_finder.is_blocked(start_cell) or _is_cell_occupied_by_unit(start_cell, bu):
					start_cell = _find_nearest_free_cell(start_cell)
				bu.grid_cell = start_cell
				_range_finder.set_occupied(start_cell, true)
				units_root.add_child(bu)
				var world_pos: Vector3 = grid_board.get_world_at_cell(start_cell) + Vector3(0, 0.5, 0)
				bu.position = units_root.to_local(world_pos)
				if bu.has_signal("clicked"):
					bu.clicked.connect(_on_unit_clicked)
				if bu.has_signal("died"):
					bu.died.connect(_on_unit_died)
	var enemy_spawns: Array = _current_map.enemy_spawn
	if enemy_spawns.is_empty():
		enemy_spawns = _get_auto_enemy_spawns()
	var enemy_idx: int = 0
	for u in units_root.get_children():
		if u is BattleUnit3D and u.team == BattleUnit3D.Team.ENEMY:
			var start_cell: Vector2i
			if enemy_idx < enemy_spawns.size():
				start_cell = enemy_spawns[enemy_idx]
			else:
				start_cell = _find_nearest_free_cell(Vector2i(_current_map.width - 1, int(_current_map.height / 2)))
			enemy_idx += 1
			while _range_finder.is_blocked(start_cell) or _is_cell_occupied_by_unit(start_cell, u):
				start_cell.x -= 1
				if start_cell.x < 0:
					start_cell.x = _current_map.width - 1
					start_cell.y -= 1
				if start_cell.y < 0:
					break
			u.grid_cell = start_cell
			u.global_position = grid_board.get_world_at_cell(start_cell) + Vector3(0, 0.5, 0)
			_range_finder.set_occupied(start_cell, true)
			if u.has_signal("clicked"):
				u.clicked.connect(_on_unit_clicked)
			if u.has_signal("died"):
				u.died.connect(_on_unit_died)


func _find_nearest_free_cell(from: Vector2i) -> Vector2i:
	var w: int = _current_map.width
	var h: int = _current_map.height
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	var visited: Dictionary = {}
	var queue: Array = [from]
	visited[Vector2i(from.x, from.y)] = true
	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		if c.x >= 0 and c.x < w and c.y >= 0 and c.y < h:
			if not _range_finder.is_blocked(c) and not _is_cell_occupied_by_unit(c, null):
				return c
		for d in dirs:
			var nc: Vector2i = Vector2i(c.x + d.x, c.y + d.y)
			var key: Vector2i = Vector2i(nc.x, nc.y)
			if not visited.get(key, false) and nc.x >= 0 and nc.x < w and nc.y >= 0 and nc.y < h:
				visited[key] = true
				queue.append(nc)
	return from


func _get_auto_enemy_spawns() -> Array:
	var out: Array = []
	var right_start: int = maxi(0, _current_map.width - 3)
	for x in range(right_start, _current_map.width):
		for y in range(_current_map.height):
			var c: Vector2i = Vector2i(x, y)
			if not grid_board.is_blocked(c):
				out.append(c)
	return out


func _setup_turn_manager() -> void:
	var allies: Array = []
	var enemies: Array = []
	for u in units_root.get_children():
		if u is BattleUnit3D:
			if u.team == BattleUnit3D.Team.ALLY:
				allies.append(u)
			else:
				enemies.append(u)
	turn_manager.set_units(allies, enemies)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.battle_ended.connect(_on_battle_ended)


func _is_cell_occupied_by_unit(cell: Vector2i, exclude: Node) -> bool:
	for u in units_root.get_children():
		if u == exclude:
			continue
		if u is BattleUnit3D and is_instance_valid(u) and not u.is_dead() and u.grid_cell == cell:
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
	if action_panel:
		if action_panel.has_signal("action_move"):
			action_panel.action_move.connect(_on_action_move)
		if action_panel.has_signal("action_attack"):
			action_panel.action_attack.connect(_on_action_attack)
		if action_panel.has_signal("action_end_turn"):
			action_panel.action_end_turn.connect(_on_action_end_turn)


func _on_unit_died(unit: BattleUnit3D) -> void:
	_range_finder.set_occupied(unit.grid_cell, false)
	if turn_manager:
		turn_manager.remove_unit(unit)


func _on_turn_started(unit: BattleUnit3D) -> void:
	_mode = Mode.NONE
	_selected_unit = null
	_clear_highlights()
	if unit and unit.team == BattleUnit3D.Team.ALLY:
		action_panel.set_unit(unit)
		action_panel.set_attack_available(_has_attackable_enemy(unit))
		action_panel.set_enabled(true)
		_is_ai_turn = false
		if input_raycast:
			input_raycast.input_locked = false
	else:
		action_panel.set_unit(null)
		action_panel.set_enabled(false)
		_is_ai_turn = true
		if input_raycast:
			input_raycast.input_locked = true
		_call_enemy_ai(unit)


func _on_turn_ended(_unit: BattleUnit3D) -> void:
	pass


func _on_round_started(_round_index: int) -> void:
	_update_debug_label()


func _on_battle_ended(winner_team: TurnManager.Team) -> void:
	_is_ai_turn = true
	if input_raycast:
		input_raycast.input_locked = true
	action_panel.set_enabled(false)
	var msg: String = "승리!" if winner_team == TurnManager.Team.ALLY else "패배!"
	debug_label.text = "전투 종료 - %s" % msg
	print("[BattleScene3D] Battle ended - %s" % msg)


func _call_enemy_ai(unit: BattleUnit3D) -> void:
	if not unit or unit.team != BattleUnit3D.Team.ENEMY:
		_end_turn()
		return
	_run_enemy_ai(unit)


func _run_enemy_ai(enemy: BattleUnit3D) -> void:
	var allies: Array = []
	for u in units_root.get_children():
		if u is BattleUnit3D and u.team == BattleUnit3D.Team.ALLY and is_instance_valid(u) and not u.is_dead():
			allies.append(u)
	if allies.is_empty():
		_end_turn()
		return
	var target: BattleUnit3D = EnemyAI.find_nearest_ally(enemy, allies)
	if not target:
		_end_turn()
		return
	var ec: Vector2i = enemy.grid_cell
	var tc: Vector2i = target.grid_cell
	if EnemyAI.can_attack_from(ec, tc, enemy.attack_range):
		_do_attack(enemy, target)
		await get_tree().create_timer(0.4).timeout
		_end_turn()
		return
	var move_cell: Vector2i = EnemyAI.choose_move_toward_target(enemy, target, _pathfinder, _range_finder)
	if move_cell != ec and enemy.pay_move_token():
		_range_finder.set_occupied(ec, false)
		_range_finder.set_occupied(move_cell, true)
		enemy.set_grid_cell(move_cell)
		var path: PackedVector2Array = _pathfinder.find_path(ec, move_cell, _get_occupied_for_path(ec, move_cell))
		if path.size() >= 2:
			_is_moving = true
			_animate_move(enemy, path)
			if _move_tween:
				await _move_tween.finished
			else:
				await get_tree().process_frame
		_is_moving = false
		ec = enemy.grid_cell
	if EnemyAI.can_attack_from(ec, tc, enemy.attack_range) and is_instance_valid(target) and not target.is_dead():
		_do_attack(enemy, target)
		await get_tree().create_timer(0.4).timeout
	_end_turn()


func _get_occupied_for_path(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var out: Array = []
	for c in _range_finder.get_occupied_cells():
		if c != from_cell and c != to_cell:
			out.append(c)
	return out


func _do_attack(attacker: BattleUnit3D, target: BattleUnit3D) -> void:
	if not is_instance_valid(target) or target.is_dead():
		return
	if not attacker.pay(2):
		return
	target.apply_damage(attacker.attack_damage)
	debug_label.text = "%s -> %s (%d 데미지)" % [attacker.name, target.name, attacker.attack_damage]
	print("[BattleScene3D] %s attacks %s for %d damage" % [attacker.name, target.name, attacker.attack_damage])


func _end_turn() -> void:
	turn_manager.end_current_turn()


func _on_action_move() -> void:
	var cu: BattleUnit3D = turn_manager.get_current_unit()
	if not cu or cu.team != BattleUnit3D.Team.ALLY or not cu.can_move():
		return
	_mode = Mode.MOVE
	_selected_unit = cu
	_reachable_cells = _range_finder.get_reachable_cells(cu.grid_cell, cu.move_range, true)
	grid_board.highlight_cells(_reachable_cells, HIGHLIGHT_COLOR)
	_attackable_cells.clear()
	_update_debug_label()


func _on_action_attack() -> void:
	var cu: BattleUnit3D = turn_manager.get_current_unit()
	if not cu or cu.team != BattleUnit3D.Team.ALLY or not cu.can_pay(2):
		return
	_mode = Mode.ATTACK
	_selected_unit = cu
	_reachable_cells.clear()
	_attackable_cells = _get_attackable_cells(cu)
	action_panel.set_attack_available(_count_enemies_in_cells(_attackable_cells) > 0)
	grid_board.highlight_cells(_attackable_cells, ATTACK_HIGHLIGHT_COLOR)
	_update_debug_label()


func _get_attackable_cells(attacker: BattleUnit3D) -> Array[Vector2i]:
	var arr: Array = EnemyAI.get_attackable_cells(attacker.grid_cell, attacker.attack_range)
	var out: Array[Vector2i] = []
	out.assign(arr)
	return out


func _has_attackable_enemy(unit: BattleUnit3D) -> bool:
	if not unit or unit.team != BattleUnit3D.Team.ALLY:
		return false
	var cells: Array[Vector2i] = _get_attackable_cells(unit)
	return _count_enemies_in_cells(cells) > 0


func _count_enemies_in_cells(cells: Array[Vector2i]) -> int:
	var n: int = 0
	for u in units_root.get_children():
		if u is BattleUnit3D and u.team == BattleUnit3D.Team.ENEMY and is_instance_valid(u) and not u.is_dead():
			var c: Vector2i = u.grid_cell
			for cell in cells:
				if cell.x == c.x and cell.y == c.y:
					n += 1
					break
	return n


func _on_action_end_turn() -> void:
	_mode = Mode.NONE
	_selected_unit = null
	_clear_highlights()
	_end_turn()


func _on_cancel_requested() -> void:
	if _is_moving:
		_deselect_after_move = true
	else:
		_mode = Mode.NONE
		_selected_unit = null
		_clear_highlights()
		if action_panel and turn_manager.get_current_unit():
			var cu: BattleUnit3D = turn_manager.get_current_unit()
			action_panel.refresh(_has_attackable_enemy(cu))
		_update_debug_label()


func _on_unit_clicked(unit: BattleUnit3D) -> void:
	if _is_moving or _is_ai_turn:
		return
	var cu: BattleUnit3D = turn_manager.get_current_unit()
	if not cu or cu.team != BattleUnit3D.Team.ALLY:
		return
	if _mode == Mode.ATTACK and _selected_unit and unit.team == BattleUnit3D.Team.ENEMY:
		var tc: Vector2i = unit.grid_cell
		for c in _attackable_cells:
			if c.x == tc.x and c.y == tc.y:
				_do_attack(_selected_unit, unit)
				_mode = Mode.NONE
				_selected_unit = null
				_clear_highlights()
				if action_panel:
					action_panel.refresh(_has_attackable_enemy(cu))
				_update_debug_label()
				return
		return
	if unit == cu:
		if _mode == Mode.NONE:
			_selected_unit = cu
			_update_debug_label()
		return
	_selected_unit = null
	_clear_highlights()
	_update_debug_label()


func _on_unit_hit_from_raycast(unit: Node) -> void:
	if _is_moving or _is_ai_turn:
		return
	if unit is BattleUnit3D:
		_on_unit_clicked(unit)


func _on_tile_hit(cell: Vector2i) -> void:
	if _is_moving or _is_ai_turn:
		return
	if cell.x < 0 or cell.y < 0:
		_mode = Mode.NONE
		_selected_unit = null
		_clear_highlights()
		if action_panel and turn_manager.get_current_unit():
			var cu: BattleUnit3D = turn_manager.get_current_unit()
			action_panel.refresh(_has_attackable_enemy(cu))
		_update_debug_label()
		return
	if _mode == Mode.MOVE and _selected_unit:
		for c in _reachable_cells:
			if c.x == cell.x and c.y == cell.y:
				_move_unit_to(_selected_unit, cell)
				return
	_mode = Mode.NONE
	_selected_unit = null
	_clear_highlights()
	_update_debug_label()


func _select_unit(_unit: BattleUnit3D) -> void:
	pass


func _clear_highlights() -> void:
	_reachable_cells.clear()
	_attackable_cells.clear()
	grid_board.clear_highlights()


func _deselect_unit() -> void:
	_selected_unit = null
	_clear_highlights()


func _move_unit_to(unit: BattleUnit3D, target: Vector2i) -> void:
	if not unit.pay_move_token():
		return
	var path: PackedVector2Array = _pathfinder.find_path(unit.grid_cell, target, _get_occupied_for_path(unit.grid_cell, target))
	if path.size() < 2:
		unit.mp = mini(unit.base_mp, unit.mp + 1)
		_mode = Mode.NONE
		_selected_unit = null
		_clear_highlights()
		_update_debug_label()
		return
	_is_moving = true
	_deselect_after_move = false
	if input_raycast:
		input_raycast.input_locked = true
	_range_finder.set_occupied(unit.grid_cell, false)
	_range_finder.set_occupied(target, true)
	unit.set_grid_cell(target)
	_mode = Mode.NONE
	_selected_unit = null
	_clear_highlights()
	_update_debug_label()
	_animate_move(unit, path)


func _animate_move(unit: BattleUnit3D, path: PackedVector2Array) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_parallel(false)
	for i in range(1, path.size()):
		var cell: Vector2i = Vector2i(int(path[i].x), int(path[i].y))
		var tw: Vector3 = grid_board.get_world_at_cell(cell)
		tw.y = 0.5
		_move_tween.tween_property(unit, "global_position", tw, MOVE_DURATION / float(path.size() - 1)).set_ease(Tween.EASE_IN_OUT)
	_move_tween.finished.connect(_on_move_finished)


func _on_move_finished() -> void:
	_is_moving = false
	if input_raycast and not _is_ai_turn:
		input_raycast.input_locked = false
	_update_debug_label()
	if _deselect_after_move:
		_deselect_after_move = false
		_deselect_unit()
	if not _is_ai_turn:
		if action_panel and turn_manager.get_current_unit():
			var cu: BattleUnit3D = turn_manager.get_current_unit()
			action_panel.refresh(_has_attackable_enemy(cu))


func _update_debug_label() -> void:
	if not debug_label:
		return
	var cu: BattleUnit3D = turn_manager.get_current_unit() if turn_manager else null
	var s: String = "턴: 없음"
	if cu:
		s = "턴: %s @ (%d,%d) HP:%d/%d %s" % [cu.name, cu.grid_cell.x, cu.grid_cell.y, cu.hp, cu.max_hp, cu.get_points_text()]
	debug_label.text = s
