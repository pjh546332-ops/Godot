extends Node3D
class_name BattleUnit3D

## 전투 유닛: Sprite3D + billboard, 팀/HP/공격, 격자 셀에 위치.

enum Team { ALLY, ENEMY }

signal clicked(unit: BattleUnit3D)
signal died(unit: BattleUnit3D)

@export var team: Team = Team.ALLY
@export var max_hp: int = 10
var hp: int = 10
@export var attack_range: int = 1
@export var attack_damage: int = 3

var grid_cell: Vector2i = Vector2i.ZERO
var move_range: int = 4

var _is_dead: bool = false


func _ready() -> void:
	hp = max_hp
	_setup_shadow()
	_setup_sprite()
	_setup_collision()
	_update_sprite_color()


func _setup_shadow() -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	mesh_inst.mesh = quad
	mesh_inst.rotation_degrees = Vector3(-90, 0, 0)
	mesh_inst.position = Vector3(0, 0.02, 0)
	mesh_inst.name = "Shadow"
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.15, 0.15, 0.15, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _create_shadow_texture()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _create_shadow_texture() -> ImageTexture:
	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx: float = float(size) * 0.5
	var cy: float = float(size) * 0.5
	var r: float = cx - 4
	for y in range(size):
		for x in range(size):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = 1.0 - clamp((d - r) / 10.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _setup_sprite() -> void:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 0.01
	sprite.texture = _create_placeholder_texture()
	sprite.position = Vector3(0, 0.5, 0)
	sprite.name = "Sprite3D"
	add_child(sprite)
	_update_sprite_color()


func _create_placeholder_texture() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.8, 0.4, 1.0))
	for x in range(32):
		for y in range(32):
			if x < 2 or x >= 30 or y < 2 or y >= 30:
				img.set_pixel(x, y, Color(0.2, 0.6, 0.3, 1.0))
	return ImageTexture.create_from_image(img)


func _update_sprite_color() -> void:
	var sprite: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
	if not sprite or not sprite.texture:
		return
	var img: Image = sprite.texture.get_image()
	if not img:
		return
	img = img.duplicate()
	var col: Color = Color(0.3, 0.8, 0.4, 1.0) if team == Team.ALLY else Color(0.8, 0.3, 0.3, 1.0)
	var col_border: Color = Color(0.2, 0.6, 0.3, 1.0) if team == Team.ALLY else Color(0.6, 0.2, 0.2, 1.0)
	img.fill(col)
	for x in range(32):
		for y in range(32):
			if x < 2 or x >= 30 or y < 2 or y >= 30:
				img.set_pixel(x, y, col_border)
	sprite.texture = ImageTexture.create_from_image(img)


func _setup_collision() -> void:
	var area: Area3D = Area3D.new()
	area.collision_layer = TrpgLayers.LAYER_UNIT
	area.collision_mask = 0
	area.name = "ClickArea"
	add_child(area)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 0.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.4, 0)
	area.add_child(shape)
	area.input_event.connect(_on_input_event)


func _on_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)


func set_grid_cell(cell: Vector2i) -> void:
	grid_cell = cell


func get_grid_cell() -> Vector2i:
	return grid_cell


func is_dead() -> bool:
	return _is_dead or hp <= 0


func apply_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_die()


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit(self)
	queue_free()
