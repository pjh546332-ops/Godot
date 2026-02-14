extends Node3D
class_name GridBoard3D

## 격자 보드: 타일 MeshInstance3D + collision. apply_map으로 맵 데이터 적용.

const TILE_SIZE: float = 1.0

signal tile_clicked(cell: Vector2i)

var GRID_WIDTH: int = 10
var GRID_HEIGHT: int = 10
var _blocked_cells: Array[Vector2i] = []
var _tiles: Dictionary = {}
var _tile_bodies: Dictionary = {}
var _highlight_materials: Dictionary = {}
var _obstacle_meshes: Array[Node3D] = []


func _ready() -> void:
	pass


func apply_map(map: TrpgMapData) -> void:
	_clear_all()
	GRID_WIDTH = map.width
	GRID_HEIGHT = map.height
	_blocked_cells.clear()
	for c in map.blocked_cells:
		_blocked_cells.append(c)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell := Vector2i(x, y)
			var blocked: bool = _is_blocked_cell(cell)
			_create_tile(cell, blocked)
	for c in map.blocked_cells:
		_create_obstacle(c)


func _is_blocked_cell(cell: Vector2i) -> bool:
	for bc in _blocked_cells:
		if bc == cell:
			return true
	return false


func _clear_all() -> void:
	_highlight_materials.clear()
	for c in _tile_bodies:
		var body: StaticBody3D = _tile_bodies[c]
		if is_instance_valid(body):
			body.queue_free()
	_tile_bodies.clear()
	_tiles.clear()
	for obs in _obstacle_meshes:
		if is_instance_valid(obs):
			obs.queue_free()
	_obstacle_meshes.clear()
	_blocked_cells.clear()


func _build_grid_default() -> void:
	if _tiles.size() > 0:
		return
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell := Vector2i(x, y)
			_create_tile(cell, false)


func _create_tile(cell: Vector2i, blocked: bool) -> void:
	var pos: Vector3 = Vector3(
		float(cell.x) * TILE_SIZE + TILE_SIZE * 0.5,
		0.0,
		float(cell.y) * TILE_SIZE + TILE_SIZE * 0.5
	)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = TrpgLayers.LAYER_FLOOR
	body.collision_mask = 0
	body.name = "Tile_%d_%d" % [cell.x, cell.y]
	body.position = pos
	add_child(body)
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
	mat.albedo_color = Color(0.5, 0.5, 0.6, 1.0) if not blocked else Color(0.25, 0.2, 0.2, 1.0)
	mesh_node.material_override = mat
	body.add_child(mesh_node)
	_tiles[cell] = mesh_node


func _create_obstacle(cell: Vector2i) -> void:
	var pos: Vector3 = Vector3(
		float(cell.x) * TILE_SIZE + TILE_SIZE * 0.5,
		TILE_SIZE * 0.5,
		float(cell.y) * TILE_SIZE + TILE_SIZE * 0.5
	)
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(TILE_SIZE * 0.8, TILE_SIZE, TILE_SIZE * 0.8)
	mesh_inst.mesh = box_mesh
	mesh_inst.position = pos
	mesh_inst.name = "Obstacle_%d_%d" % [cell.x, cell.y]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.2, 1.0)
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	_obstacle_meshes.append(mesh_inst)


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
	return _is_blocked_cell(cell)


func get_blocked_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _blocked_cells:
		out.append(c)
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
