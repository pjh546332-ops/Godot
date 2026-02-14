extends RefCounted
class_name EnemyAI

## 적 간단 AI: 가장 가까운 아군 타겟, 이동 후 공격.

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


static func find_nearest_ally(enemy: BattleUnit3D, allies: Array) -> BattleUnit3D:
	var ec: Vector2i = enemy.grid_cell
	var nearest: BattleUnit3D = null
	var dist: int = 999
	for u in allies:
		if not is_instance_valid(u) or not (u is BattleUnit3D) or u.is_dead():
			continue
		var d: int = manhattan(ec, u.grid_cell)
		if d < dist:
			dist = d
			nearest = u
	return nearest


static func get_attackable_cells(attacker_cell: Vector2i, atk_range: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-atk_range, atk_range + 1):
		for dy in range(-atk_range, atk_range + 1):
			if abs(dx) + abs(dy) <= atk_range and (dx != 0 or dy != 0):
				out.append(Vector2i(attacker_cell.x + dx, attacker_cell.y + dy))
	return out


static func choose_move_toward_target(enemy: BattleUnit3D, target: BattleUnit3D, _pathfinder: PathfindingAStar, range_finder: RangeFinder) -> Vector2i:
	var ec: Vector2i = enemy.grid_cell
	var tc: Vector2i = target.grid_cell
	var atk_range: int = enemy.attack_range
	var move_range: int = enemy.move_range
	var reachable: Array[Vector2i] = range_finder.get_reachable_cells(ec, move_range, true)
	var attack_cells: Array[Vector2i] = get_attackable_cells(tc, atk_range)
	var best: Vector2i = ec
	var best_dist: int = manhattan(ec, tc)
	for cell in reachable:
		if attack_cells.has(cell):
			var d: int = manhattan(cell, tc)
			if d < best_dist:
				best_dist = d
				best = cell
	if best != ec:
		return best
	for cell in reachable:
		var d: int = manhattan(cell, tc)
		if d < best_dist:
			best_dist = d
			best = cell
	return best


static func can_attack_from(attacker_cell: Vector2i, target_cell: Vector2i, atk_range: int) -> bool:
	return manhattan(attacker_cell, target_cell) <= atk_range
