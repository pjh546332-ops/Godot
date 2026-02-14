extends Control

## 낮 던전 탐색. 층/노드 진행, BATTLE/LOOT/EVENT/BOSS 처리.

const DungeonGraph = preload("res://Modules/DUNGEON/Scripts/dungeon_graph.gd")

@onready var label_floor: Label = $Margin/VBox/LabelFloor
@onready var node_buttons: HBoxContainer = $Margin/VBox/NodeButtons
@onready var label_status: Label = $Margin/VBox/LabelStatus
@onready var btn_to_hub: Button = $Margin/VBox/BtnToHub

var _router: Node = null
var _state: Node = null
var _floor_nodes: Array[DungeonGraph.DungeonNode] = []
var _current_node_idx: int = 0
var _cleared_nodes: Array[int] = []


func _ready() -> void:
	_state = get_node_or_null("/root/StateService")
	btn_to_hub.pressed.connect(_on_to_hub)
	_load_floor()


func set_router(router: Node) -> void:
	_router = router


func _load_floor() -> void:
	if not _state or not _state.run:
		return
	var run = _state.run
	if run.pending_battle_won:
		run.pending_battle_won = false
		_current_node_idx = run.node_index
		_cleared_nodes.append(_current_node_idx)
		_current_node_idx += 1
		run.node_index = _current_node_idx
		run.run_meta_gain += 1
		_state.save_game()
		if _current_node_idx >= DungeonGraph.NODES_PER_FLOOR:
			_advance_floor()
			return
		_floor_nodes = DungeonGraph.generate_floor(run.floor_num)
		_rebuild_ui()
		return
	var floor_num: int = clamp(run.floor_num, 1, DungeonGraph.FLOOR_COUNT)
	_floor_nodes = DungeonGraph.generate_floor(floor_num)
	_current_node_idx = run.node_index
	_cleared_nodes.clear()
	for i in range(_current_node_idx):
		_cleared_nodes.append(i)
	_rebuild_ui()


func _rebuild_ui() -> void:
	if not label_floor or not _state:
		return
	var run = _state.run
	label_floor.text = "던전 %d층" % run.floor_num
	label_status.text = "현재 노드: %d | 룻: %s" % [_current_node_idx, str(run.run_loot)]
	_clear_node_buttons()
	for i in _floor_nodes.size():
		var n: DungeonGraph.DungeonNode = _floor_nodes[i]
		var is_cleared: bool = i in _cleared_nodes
		var is_next: bool = (i == _current_node_idx)
		var btn := Button.new()
		btn.name = "NodeBtn_%d" % i
		var type_name: String = DungeonGraph.get_type_name(n.type)
		btn.text = "%d:%s" % [i, type_name] if not is_cleared else "%d:완료" % i
		btn.disabled = not (is_next and not is_cleared)
		if is_next and not is_cleared:
			btn.pressed.connect(_on_node_clicked.bind(i))
		node_buttons.add_child(btn)


func _clear_node_buttons() -> void:
	for c in node_buttons.get_children():
		c.queue_free()


func _on_node_clicked(node_idx: int) -> void:
	if node_idx < 0 or node_idx >= _floor_nodes.size():
		return
	var n: DungeonGraph.DungeonNode = _floor_nodes[node_idx]
	match n.type:
		DungeonGraph.NodeType.BATTLE:
			_enter_battle(node_idx, false)
		DungeonGraph.NodeType.BOSS:
			var is_floor9: bool = _state.run.floor_num >= DungeonGraph.FLOOR_COUNT
			_enter_battle(node_idx, is_floor9)
		DungeonGraph.NodeType.LOOT:
			_do_loot(node_idx)
		DungeonGraph.NodeType.EVENT:
			_do_event(node_idx)


func _enter_battle(_node_idx: int, is_floor9_boss: bool) -> void:
	if _router and _router.has_method("go_to_battle_from_dungeon"):
		_router.go_to_battle_from_dungeon(is_floor9_boss)
	elif _router:
		_router.go_to_battle()


func _do_loot(node_idx: int) -> void:
	if not _state or not _state.run:
		return
	_state.run.run_loot.append("더미_아이템_%d" % randi() % 100)
	_state.save_game()
	_complete_node(node_idx)


func _do_event(node_idx: int) -> void:
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
	_complete_node(node_idx)


func _complete_node(node_idx: int) -> void:
	_cleared_nodes.append(node_idx)
	_current_node_idx = node_idx + 1
	if _state:
		_state.run.node_index = _current_node_idx
		_state.save_game()
	if _current_node_idx >= _floor_nodes.size():
		_advance_floor()
	else:
		_rebuild_ui()


func _advance_floor() -> void:
	if not _state or not _state.run:
		return
	var run = _state.run
	run.floor_num += 1
	run.node_index = 0
	_state.save_game()
	if run.floor_num > DungeonGraph.FLOOR_COUNT:
		if _state.has_method("end_run"):
			_state.end_run(true)
		if _router and _router.has_method("go_to_hub"):
			_router.go_to_hub()
	else:
		_load_floor()


func _on_to_hub() -> void:
	if _router and _router.has_method("go_to_hub"):
		_router.go_to_hub()
