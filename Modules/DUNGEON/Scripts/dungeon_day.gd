extends Control

## 낮 던전 탐색. 노드형 맵에서 노드 클릭으로 이동, BATTLE/LOOT/EVENT/BOSS 처리.

@onready var label_floor: Label = $Margin/VBox/LabelFloor
@onready var node_map_container: Control = $Margin/VBox/NodeMapContainer
@onready var node_buttons: HBoxContainer = $Margin/VBox/NodeButtons
@onready var label_status: Label = $Margin/VBox/LabelStatus
@onready var btn_to_hub: Button = $Margin/VBox/BtnToHub

var _router: Node = null
var _state: Node = null
var _graph_nodes: Array[DungeonGraph.DungeonNode] = []
var _layout: Dictionary = {}
var _node_by_id: Dictionary = {}
var _current_node_id: int = 0
var _cleared_nodes: Array[int] = []
const NODE_RADIUS: float = 22.0


func _ready() -> void:
	_state = get_node_or_null("/root/StateService")
	btn_to_hub.pressed.connect(_on_to_hub)
	node_map_container.draw.connect(_on_draw_map)
	node_map_container.gui_input.connect(_on_map_gui_input)
	node_map_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_graph()


func set_router(router: Node) -> void:
	_router = router


func _load_graph() -> void:
	if not _state or not _state.run:
		return
	var run = _state.run
	_graph_nodes = DungeonGraph.generate_test_graph()
	_layout = DungeonGraph.get_node_layout(_graph_nodes, 0)
	_node_by_id.clear()
	for n in _graph_nodes:
		_node_by_id[n.id] = n
	if run.pending_battle_won:
		run.pending_battle_won = false
		_current_node_id = run.node_index
		_cleared_nodes = run.cleared_dungeon_node_ids.duplicate()
		if _current_node_id not in _cleared_nodes:
			_cleared_nodes.append(_current_node_id)
		run.cleared_dungeon_node_ids.clear()
		run.cleared_dungeon_node_ids.assign(_cleared_nodes)
		run.current_dungeon_node_id = _current_node_id
		_state.save_game()
	else:
		_current_node_id = run.current_dungeon_node_id
		_cleared_nodes = run.cleared_dungeon_node_ids.duplicate()
		if _cleared_nodes.is_empty() and _current_node_id == 0:
			run.current_dungeon_node_id = 0
			run.cleared_dungeon_node_ids.clear()
	_rebuild_ui()


func _rebuild_ui() -> void:
	if not label_floor or not _state:
		return
	var run = _state.run
	label_floor.text = "던전 노드 맵"
	label_status.text = "현재 노드: %d | 룻: %s" % [_current_node_id, str(run.run_loot)]
	_clear_node_buttons()
	for n in _graph_nodes:
		var is_cleared: bool = n.id in _cleared_nodes
		var can_go: bool = _current_node_id in _node_by_id and n.id in _node_by_id[_current_node_id].next_ids
		var btn := Button.new()
		btn.name = "NodeBtn_%d" % n.id
		var type_name: String = DungeonGraph.get_type_name(n.type)
		btn.text = "%d:%s" % [n.id, type_name] if not is_cleared else "%d:완료" % n.id
		btn.disabled = not (can_go and not is_cleared)
		if can_go and not is_cleared:
			btn.pressed.connect(_on_node_clicked.bind(n.id))
		node_buttons.add_child(btn)
	node_map_container.queue_redraw()


func _clear_node_buttons() -> void:
	for c in node_buttons.get_children():
		c.queue_free()


func _on_draw_map() -> void:
	var sz: Vector2 = node_map_container.size
	if sz.x <= 0 or sz.y <= 0:
		return
	var margin: float = 40.0
	var area: Vector2 = sz - Vector2(margin * 2, margin * 2)
	var current_node: DungeonGraph.DungeonNode = _node_by_id.get(_current_node_id, null)
	var next_ids: Array = current_node.next_ids if current_node else []

	for id in _layout:
		var from_pos: Vector2 = _layout[id] * area + Vector2(margin, margin)
		var node: DungeonGraph.DungeonNode = _node_by_id.get(id, null)
		if not node:
			continue
		for next_id in node.next_ids:
			if next_id not in _layout:
				continue
			var to_pos: Vector2 = _layout[next_id] * area + Vector2(margin, margin)
			var color_line: Color = Color(0.35, 0.4, 0.45, 0.9)
			node_map_container.draw_line(from_pos, to_pos, color_line)
			node_map_container.draw_line(from_pos, to_pos, Color(0.25, 0.28, 0.32, 0.5))

	for id in _layout:
		var pos: Vector2 = _layout[id] * area + Vector2(margin, margin)
		var node: DungeonGraph.DungeonNode = _node_by_id.get(id, null)
		if not node:
			continue
		var is_cleared: bool = id in _cleared_nodes
		var is_current: bool = (id == _current_node_id)
		var can_go: bool = id in next_ids
		var col: Color
		if is_current:
			col = Color(0.2, 0.7, 0.35)
		elif can_go and not is_cleared:
			col = Color(0.95, 0.75, 0.2)
		elif is_cleared:
			col = Color(0.4, 0.45, 0.5)
		else:
			col = Color(0.28, 0.3, 0.35)
		node_map_container.draw_arc(pos, NODE_RADIUS, 0, TAU, 24, col, 2.0)
		node_map_container.draw_circle(pos, NODE_RADIUS - 2, col)
		var type_name: String = DungeonGraph.get_type_name(node.type)
		var label: String = "%d" % id if is_cleared else type_name
		var font: Font = ThemeDB.fallback_font
		var fs: int = 12
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		node_map_container.draw_string(font, pos - Vector2(tw * 0.5, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)


func _on_map_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var ev: InputEventMouseButton = event as InputEventMouseButton
	if not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var sz: Vector2 = node_map_container.size
	var margin: float = 40.0
	var area: Vector2 = sz - Vector2(margin * 2, margin * 2)
	var local: Vector2 = node_map_container.get_local_mouse_position()
	var current_node: DungeonGraph.DungeonNode = _node_by_id.get(_current_node_id, null)
	var next_ids: Array = current_node.next_ids if current_node else []

	for id in _layout:
		var pos: Vector2 = _layout[id] * area + Vector2(margin, margin)
		if local.distance_to(pos) <= NODE_RADIUS:
			if id in next_ids and id not in _cleared_nodes:
				_on_node_clicked(id)
			return


func _on_node_clicked(node_id: int) -> void:
	if node_id not in _node_by_id:
		return
	var n: DungeonGraph.DungeonNode = _node_by_id[node_id]
	match n.type:
		DungeonGraph.NodeType.BATTLE:
			_enter_battle(node_id, false)
		DungeonGraph.NodeType.BOSS:
			_enter_battle(node_id, true)
		DungeonGraph.NodeType.LOOT:
			_do_loot(node_id)
		DungeonGraph.NodeType.EVENT:
			_do_event(node_id)


func _enter_battle(node_id: int, is_boss: bool) -> void:
	if _state and _state.run:
		_state.run.node_index = node_id
		_state.run.cleared_dungeon_node_ids.clear()
		_state.run.cleared_dungeon_node_ids.assign(_cleared_nodes)
		_state.save_game()
	if _router and _router.has_method("go_to_battle_from_dungeon"):
		_router.go_to_battle_from_dungeon(is_boss)
	elif _router:
		_router.go_to_battle()


func _do_loot(node_id: int) -> void:
	if not _state or not _state.run:
		return
	_state.run.run_loot.append("더미_아이템_%d" % (randi() % 100))
	_state.save_game()
	_complete_node(node_id)


func _do_event(node_id: int) -> void:
	if not _state or not _state.campaign:
		return
	var c: CampaignState = _state.campaign
	if randi() % 2 == 0:
		for uid in TrpgIds.UNIT_IDS:
			var f: int = c.fatigue.get(uid, 0)
			c.fatigue[uid] = clampi(f + 10, 0, 100)
	else:
		var uid: String = TrpgIds.UNIT_IDS[randi() % TrpgIds.UNIT_IDS.size()]
		var b: int = c.bonds.get(uid, 0)
		c.bonds[uid] = b + 1
	_state.save_game()
	_complete_node(node_id)


func _complete_node(node_id: int) -> void:
	_cleared_nodes.append(node_id)
	_current_node_id = node_id
	if _state and _state.run:
		_state.run.current_dungeon_node_id = _current_node_id
		_state.run.cleared_dungeon_node_ids.clear()
		_state.run.cleared_dungeon_node_ids.assign(_cleared_nodes)
		_state.save_game()
	var n: DungeonGraph.DungeonNode = _node_by_id.get(node_id, null)
	if n and n.type == DungeonGraph.NodeType.BOSS:
		_advance_after_boss()
	else:
		_rebuild_ui()


func _advance_after_boss() -> void:
	if not _state or not _state.run:
		return
	var run = _state.run
	run.floor_num += 1
	run.node_index = 0
	run.current_dungeon_node_id = 0
	run.cleared_dungeon_node_ids.clear()
	_state.save_game()
	if _state.has_method("end_run"):
		_state.end_run(true)
	if _router and _router.has_method("go_to_hub"):
		_router.go_to_hub()
	else:
		_load_graph()


func _on_to_hub() -> void:
	if _router and _router.has_method("go_to_hub"):
		_router.go_to_hub()
