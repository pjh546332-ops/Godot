extends Control
class_name DungeonMapView

## 노드 맵 표시 + 현재 위치 마커 Tween 이동. 이동 완료 시 node_reached(node_id) emit.

signal node_reached(node_id: int)

const NODE_RADIUS: float = 20.0
const MARGIN: float = 36.0

var _graph_nodes: Array[DungeonGraph.DungeonNode] = []
var _layout: Dictionary = {}
var _node_by_id: Dictionary = {}
var _current_node_id: int = 0
var _cleared_nodes: Array = []
var _moving: bool = false
var _tween: Tween = null

@onready var _marker: Control = $CurrentMarker


func _ready() -> void:
	if not _marker:
		_create_marker()
	else:
		if not _marker.draw.is_connected(_draw_marker):
			_marker.draw.connect(_draw_marker)
		_marker.queue_redraw()
	if _marker:
		_marker.visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _create_marker() -> void:
	_marker = Control.new()
	_marker.name = "CurrentMarker"
	_marker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_marker.custom_minimum_size = Vector2(24, 24)
	_marker.size = Vector2(24, 24)
	add_child(_marker)
	_marker.draw.connect(_draw_marker)


func _draw_marker() -> void:
	var r: float = 12.0
	_marker.draw_circle(Vector2(r, r), r - 2, Color(0.2, 0.85, 0.4))
	_marker.draw_arc(Vector2(r, r), r - 2, 0, TAU, 24, Color(0.1, 0.5, 0.25), 2.0)


func set_data(
	graph_nodes: Array,
	layout: Dictionary,
	current_id: int,
	cleared_ids: Array
) -> void:
	_graph_nodes = graph_nodes
	_layout = layout
	_node_by_id.clear()
	for n in _graph_nodes:
		_node_by_id[n.id] = n
	_current_node_id = current_id
	_cleared_nodes = cleared_ids.duplicate()
	_moving = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_update_marker_position(false)
	queue_redraw()


func _to_screen(uv: Vector2) -> Vector2:
	var area: Vector2 = size - Vector2(MARGIN * 2, MARGIN * 2)
	return uv * area + Vector2(MARGIN, MARGIN)


func _update_marker_position(animate: bool) -> void:
	if not _marker:
		return
	if _current_node_id not in _layout:
		_marker.visible = false
		return
	_marker.visible = true
	var pos: Vector2 = _to_screen(_layout[_current_node_id])
	var center: Vector2 = pos - _marker.size * 0.5
	if animate:
		var from: Vector2 = _marker.position
		_tween = create_tween()
		_tween.set_ease(Tween.EASE_IN_OUT)
		_tween.set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(_marker, "position", center, 0.45)
	else:
		_marker.position = center


func move_to(node_id: int) -> bool:
	if _moving:
		return false
	var current_node: DungeonGraph.DungeonNode = _node_by_id.get(_current_node_id, null)
	if not current_node:
		return false
	if node_id not in current_node.next_ids:
		return false
	if node_id in _cleared_nodes:
		return false
	_moving = true
	var target_pos: Vector2 = _to_screen(_layout[node_id]) - _marker.size * 0.5
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_marker, "position", target_pos, 0.5)
	_tween.tween_callback(_on_move_finished.bind(node_id))
	return true


func _on_move_finished(node_id: int) -> void:
	_moving = false
	_current_node_id = node_id
	node_reached.emit(node_id)
	queue_redraw()


func _draw() -> void:
	var area: Vector2 = size - Vector2(MARGIN * 2, MARGIN * 2)
	if area.x <= 0 or area.y <= 0:
		return
	var current_node: DungeonGraph.DungeonNode = _node_by_id.get(_current_node_id, null)
	var next_ids: Array = current_node.next_ids if current_node else []

	for id in _layout:
		var from_pos: Vector2 = _to_screen(_layout[id])
		var node: DungeonGraph.DungeonNode = _node_by_id.get(id, null)
		if not node:
			continue
		for next_id in node.next_ids:
			if next_id not in _layout:
				continue
			var to_pos: Vector2 = _to_screen(_layout[next_id])
			draw_line(from_pos, to_pos, Color(0.35, 0.4, 0.45, 0.9))

	for id in _layout:
		var pos: Vector2 = _to_screen(_layout[id])
		var node: DungeonGraph.DungeonNode = _node_by_id.get(id, null)
		if not node:
			continue
		var is_cleared: bool = id in _cleared_nodes
		var is_current: bool = (id == _current_node_id)
		var can_go: bool = id in next_ids and not _moving
		var col: Color
		if is_current:
			col = Color(0.2, 0.7, 0.35)
		elif can_go and not is_cleared:
			col = Color(0.95, 0.75, 0.2)
		elif is_cleared:
			col = Color(0.4, 0.45, 0.5)
		else:
			col = Color(0.28, 0.3, 0.35)
		draw_arc(pos, NODE_RADIUS, 0, TAU, 24, col, 2.0)
		draw_circle(pos, NODE_RADIUS - 2, col)
		var type_name: String = DungeonGraph.get_type_name(node.type)
		var label: String = ""
		if id == 0:
			pass
		elif is_cleared:
			label = "%d" % id
		else:
			label = type_name
		if label != "":
			var font: Font = ThemeDB.fallback_font
			var fs: int = 11
			var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, pos - Vector2(tw * 0.5, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)


func _gui_input(event: InputEvent) -> void:
	if _moving:
		return
	if not event is InputEventMouseButton:
		return
	var ev: InputEventMouseButton = event as InputEventMouseButton
	if not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var local: Vector2 = get_local_mouse_position()
	var current_node: DungeonGraph.DungeonNode = _node_by_id.get(_current_node_id, null)
	var next_ids: Array = current_node.next_ids if current_node else []

	for id in _layout:
		var pos: Vector2 = _to_screen(_layout[id])
		if local.distance_to(pos) <= NODE_RADIUS:
			if id in next_ids and id not in _cleared_nodes:
				if move_to(id):
					queue_redraw()
			return


func get_current_node_id() -> int:
	return _current_node_id


func is_moving() -> bool:
	return _moving
