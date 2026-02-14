extends RefCounted
class_name PathfindingAStar

## A* 경로 탐색. 격자 기반.

var _width: int
var _height: int
var _blocked: Dictionary = {}  ## Vector2i -> true
var _astar: AStar2D


func setup(width: int, height: int, blocked_cells: Array = []) -> void:
	_width = width
	_height = height
	_blocked.clear()
	for c in blocked_cells:
		_blocked[c] = true
	_rebuild_astar()


func set_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		_blocked[cell] = true
	else:
		_blocked.erase(cell)
	_rebuild_astar()


func _rebuild_astar() -> void:
	_astar = AStar2D.new()
	for x in range(_width):
		for y in range(_height):
			var c := Vector2i(x, y)
			if not _blocked.has(c):
				_astar.add_point(_to_id(c), Vector2(c.x, c.y))
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	for x in range(_width):
		for y in range(_height):
			var c := Vector2i(x, y)
			if _blocked.has(c):
				continue
			var id_from: int = _to_id(c)
			for d in dirs:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or nx >= _width or ny < 0 or ny >= _height:
					continue
				var nc := Vector2i(nx, ny)
				if _blocked.has(nc):
					continue
				var id_to: int = _to_id(nc)
				if not _astar.are_points_connected(id_from, id_to):
					_astar.connect_points(id_from, id_to)


func _to_id(c: Vector2i) -> int:
	return c.y * _width + c.x


func find_path(from: Vector2i, to: Vector2i, extra_blocked: Array = []) -> PackedVector2Array:
	for c in extra_blocked:
		if c != from and c != to:
			_blocked[c] = true
	_rebuild_astar()
	var result: PackedVector2Array = _find_path_internal(from, to)
	for c in extra_blocked:
		_blocked.erase(c)
	_rebuild_astar()
	return result


func _find_path_internal(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if from.x < 0 or from.x >= _width or from.y < 0 or from.y >= _height:
		return PackedVector2Array()
	if to.x < 0 or to.x >= _width or to.y < 0 or to.y >= _height:
		return PackedVector2Array()
	if _blocked.has(from) or _blocked.has(to):
		return PackedVector2Array()
	var id_from: int = _to_id(from)
	var id_to: int = _to_id(to)
	if not _astar.has_point(id_from) or not _astar.has_point(id_to):
		return PackedVector2Array()
	var path_ids: PackedVector2Array = _astar.get_point_path(id_from, id_to)
	var out: PackedVector2Array = PackedVector2Array()
	for p in path_ids:
		out.append(Vector2i(int(p.x), int(p.y)))
	return out


func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= _width or cell.y < 0 or cell.y >= _height:
		return false
	return not _blocked.has(cell)
