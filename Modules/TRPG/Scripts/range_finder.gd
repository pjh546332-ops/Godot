extends RefCounted
class_name RangeFinder

## BFS로 이동 가능 범위 계산.

var _width: int
var _height: int
var _blocked: Dictionary = {}
var _occupied: Dictionary = {}  ## Vector2i -> true (유닛이 있는 칸)


func setup(width: int, height: int, blocked_cells: Array = []) -> void:
	_width = width
	_height = height
	_blocked.clear()
	for c in blocked_cells:
		_blocked[c] = true
	_occupied.clear()


func set_occupied(cell: Vector2i, occupied: bool) -> void:
	if occupied:
		_occupied[cell] = true
	else:
		_occupied.erase(cell)


func get_occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _occupied:
		out.append(c)
	return out


func get_reachable_cells(start: Vector2i, max_distance: int, exclude_occupied: bool = true) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array = [[start, 0]]
	visited[start] = true
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	while queue.size() > 0:
		var cur: Vector2i = queue[0][0]
		var dist: int = queue[0][1]
		queue.pop_front()
		if dist > 0 and dist <= max_distance:
			if exclude_occupied and _occupied.has(cur):
				pass
			else:
				out.append(cur)
		if dist >= max_distance:
			continue
		for d in dirs:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or nx >= _width or ny < 0 or ny >= _height:
				continue
			var nc := Vector2i(nx, ny)
			if _blocked.has(nc):
				continue
			if exclude_occupied and _occupied.has(nc) and nc != start:
				continue
			if visited.has(nc):
				continue
			visited[nc] = true
			queue.append([nc, dist + 1])
	return out


func is_blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= _width or cell.y < 0 or cell.y >= _height:
		return true
	return _blocked.has(cell)
