extends Node3D
class_name GridBoard3D

## 격자 보드: 타일 MeshInstance3D + collision. 레이어 1.

const LAYER_FLOOR := 1
const TILE_SIZE: float = 1.0
const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 10

## 코드로 지정한 장애물 (격자 좌표)
const BLOCKED_CELLS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(5, 4), Vector2i(6, 5), Vector2i(7, 7)
]

signal tile_clicked(cell: Vector2i)

var _tiles: Dictionary = {}  ## Vector2i -> MeshInstance3D
var _tile_bodies: Dictionary = {}  ## Vector2i -> StaticBody3D
var _highlight_materials: Dictionary = {}  ## Vector2i -> Material


func _ready() -> void:
	_build_grid()


func _build_grid() -> void:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell := Vector2i(x, y)
			var blocked: bool = BLOCKED_CELLS.has(cell)
			_create_tile(cell, blocked)


func _create_tile(cell: Vector2i, blocked: bool) -> void:
	var parent: Node3D = self
	var pos: Vector3 = Vector3(
		float(cell.x) * TILE_SIZE + TILE_SIZE * 0.5,
		0.0,
		float(cell.y) * TILE_SIZE + TILE_SIZE * 0.5
	)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = LAYER_FLOOR
	body.collision_mask = 0
	body.name = "Tile_%d_%d" % [cell.x, cell.y]
	body.position = pos
	parent.add_child(body)
	_tile_bodies[cell] = body
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(TILE_SIZE * 0.95, 0.2, TILE_SIZE * 0.95)
	shape.shape = box
	body.add_child(shape)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(TILE_SIZE * 0.95, TILE_SIZE * 0.95)
	mesh_node.mesh = quad
	mesh_node.rotation_degrees = Vector3(-90, 0, 0)
	mesh_node.position = Vector3(0, 0.05, 0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.6, 1.0) if not blocked else Color(0.3, 0.2, 0.2, 1.0)
	mesh_node.material_override = mat
	body.add_child(mesh_node)
	_tiles[cell] = mesh_node


func get_cell_at_world(pos: Vector3) -> Vector2i:
	var cx: int = int(floorf(pos.x / TILE_SIZE))
	var cz: int = int(floorf(pos.z / TILE_SIZE))
	return Vector2i(cx, cz)


func get_world_at_cell(cell: Vector2i) -> Vector3:
	return Vector3(
		float(cell.x) * TILE_SIZE + TILE_SIZE * 0.5,
		0.0,
		float(cell.y) * TILE_SIZE + TILE_SIZE * 0.5
	)


func is_blocked(cell: Vector2i) -> bool:
	return BLOCKED_CELLS.has(cell)


func get_blocked_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(BLOCKED_CELLS)
	return out


func highlight_cells(cells: Array[Vector2i], color: Color) -> void:
	_clear_highlights()
	for c in cells:
		if _tiles.has(c):
			var mi: MeshInstance3D = _tiles[c]
			var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D
			if mat:
				_highlight_materials[c] = mat
				var m2: StandardMaterial3D = mat.duplicate()
				m2.albedo_color = color
				mi.material_override = m2


func _clear_highlights() -> void:
	for c in _highlight_materials:
		if _tiles.has(c):
			var mi: MeshInstance3D = _tiles[c]
			mi.material_override = _highlight_materials[c]
	_highlight_materials.clear()


func clear_highlights() -> void:
	_clear_highlights()


func get_tile_body_at(cell: Vector2i) -> StaticBody3D:
	return _tile_bodies.get(cell, null)


func get_cell_from_collider(collider: Object) -> Vector2i:
	var node: Node = collider as Node
	if not node:
		return Vector2i(-1, -1)
	while node:
		if node is StaticBody3D:
			for c in _tile_bodies:
				if _tile_bodies[c] == node:
					return c
			return Vector2i(-1, -1)
		node = node.get_parent()
	return Vector2i(-1, -1)
