extends Node
class_name TurnManager

## 턴 매니저: 아군/적 라운드 진행, 승패 판정.

enum Team { ALLY, ENEMY }

signal turn_started(unit: BattleUnit3D)
signal turn_ended(unit: BattleUnit3D)
signal round_started(round_index: int)
signal battle_ended(winner_team: Team)

var _ally_units: Array[BattleUnit3D] = []
var _enemy_units: Array[BattleUnit3D] = []
var _current_round: int = 1
var _current_turn_index: int = 0
var _turn_order: Array[BattleUnit3D] = []
var _is_battle_over: bool = false


func set_units(ally_list: Array, enemy_list: Array) -> void:
	_ally_units.clear()
	_enemy_units.clear()
	for u in ally_list:
		if u is BattleUnit3D and is_instance_valid(u):
			_ally_units.append(u)
	for u in enemy_list:
		if u is BattleUnit3D and is_instance_valid(u):
			_enemy_units.append(u)
	_build_turn_order()


func _build_turn_order() -> void:
	_turn_order.clear()
	for u in _ally_units:
		if is_instance_valid(u) and not u.is_dead():
			_turn_order.append(u)
	for u in _enemy_units:
		if is_instance_valid(u) and not u.is_dead():
			_turn_order.append(u)


func start_battle() -> void:
	_is_battle_over = false
	_build_turn_order()
	_current_round = 1
	_current_turn_index = 0
	round_started.emit(_current_round)
	if _turn_order.size() > 0:
		var first: BattleUnit3D = _turn_order[_current_turn_index]
		if first and first.has_method("reset_turn_points"):
			first.reset_turn_points()
		turn_started.emit(first)
	else:
		_check_battle_end()


func get_current_unit() -> BattleUnit3D:
	if _current_turn_index < 0 or _current_turn_index >= _turn_order.size():
		return null
	var u: BattleUnit3D = _turn_order[_current_turn_index]
	if not is_instance_valid(u) or u.is_dead():
		return null
	return u


func end_turn() -> void:
	end_current_turn()


## 수동 턴 종료 API. 현재 턴 유닛을 종료하고 다음 턴으로 넘긴다.
func end_current_turn() -> void:
	var current: BattleUnit3D = get_current_unit()
	if current:
		turn_ended.emit(current)
	_remove_dead_from_order()
	_current_turn_index += 1
	if _current_turn_index >= _turn_order.size():
		_current_round += 1
		_current_turn_index = 0
		_build_turn_order()
		round_started.emit(_current_round)
	if _turn_order.size() > 0 and _current_turn_index < _turn_order.size():
		var next: BattleUnit3D = _turn_order[_current_turn_index]
		if next and next.has_method("reset_turn_points"):
			next.reset_turn_points()
		turn_started.emit(next)
	else:
		_check_battle_end()


func _remove_dead_from_order() -> void:
	var i: int = 0
	while i < _turn_order.size():
		var u: BattleUnit3D = _turn_order[i]
		if not is_instance_valid(u) or u.is_dead():
			_turn_order.remove_at(i)
			if _current_turn_index >= i and _current_turn_index > 0:
				_current_turn_index -= 1
		else:
			i += 1


func _check_battle_end() -> void:
	if _is_battle_over:
		return
	var ally_alive: int = 0
	for u in _ally_units:
		if is_instance_valid(u) and not u.is_dead():
			ally_alive += 1
	var enemy_alive: int = 0
	for u in _enemy_units:
		if is_instance_valid(u) and not u.is_dead():
			enemy_alive += 1
	if ally_alive <= 0:
		_is_battle_over = true
		battle_ended.emit(Team.ENEMY)
	elif enemy_alive <= 0:
		_is_battle_over = true
		battle_ended.emit(Team.ALLY)


func remove_unit(unit: BattleUnit3D) -> void:
	var idx: int = _turn_order.find(unit)
	if idx >= 0:
		_turn_order.remove_at(idx)
		if _current_turn_index >= idx and _current_turn_index > 0:
			_current_turn_index -= 1
	_check_battle_end()


func get_current_round() -> int:
	return _current_round
