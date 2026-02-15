extends Control

## 낮 던전 탐색. 3분할(HSplit) + 노드 맵(Tween 이동). 배치 탭에서 저장 시 campaign.deployment_placements 반영.

const DeploymentUIScene = preload("res://Modules/TRPG/Scenes/DeploymentUI.tscn")

@onready var margin_container: MarginContainer = $MarginContainer
@onready var root_hsplit: HSplitContainer = $MarginContainer/RootHSplit
@onready var left_column: VBoxContainer = $MarginContainer/RootHSplit/LeftColumn
@onready var interactive_panel: PanelContainer = $MarginContainer/RootHSplit/LeftColumn/InteractivePanel
@onready var label_title: Label = $MarginContainer/RootHSplit/LeftColumn/InteractivePanel/VBox/LabelTitle
@onready var texture_rect_encounter: TextureRect = $MarginContainer/RootHSplit/LeftColumn/InteractivePanel/VBox/TextureRectEncounter
@onready var item_buttons_grid: GridContainer = $MarginContainer/RootHSplit/LeftColumn/InteractivePanel/VBox/ItemButtonsGrid
@onready var label_desc: Label = $MarginContainer/RootHSplit/LeftColumn/InteractivePanel/VBox/LabelDesc
@onready var bottom_tabs_panel: PanelContainer = $MarginContainer/RootHSplit/LeftColumn/BottomTabsPanel
@onready var tab_container: TabContainer = $MarginContainer/RootHSplit/LeftColumn/BottomTabsPanel/TabContainer
@onready var deploy_placeholder: Control = $MarginContainer/RootHSplit/LeftColumn/BottomTabsPanel/TabContainer/Tab_Deploy/DeployPlaceholder
@onready var btn_retreat: Button = $MarginContainer/RootHSplit/LeftColumn/BottomTabsPanel/TabContainer/Tab_Retreat/BtnRetreat
@onready var right_map_panel: PanelContainer = $MarginContainer/RootHSplit/RightMapPanel
@onready var map_view: DungeonMapView = $MarginContainer/RootHSplit/RightMapPanel/MapPlaceholder/DungeonMapView

var _router: Node = null
var _state: Node = null
var _graph_nodes: Array[DungeonGraph.DungeonNode] = []
var _layout: Dictionary = {}
var _node_by_id: Dictionary = {}
var _current_node_id: int = 0
var _cleared_nodes: Array[int] = []
var _deployment_ui: TrpgDeploymentUI = null


func _ready() -> void:
	_state = get_node_or_null("/root/StateService")
	btn_retreat.pressed.connect(_on_retreat)
	map_view.node_reached.connect(_on_node_reached)
	_set_tab_titles()
	_build_dummy_item_buttons()
	_setup_deploy_tab()
	_load_graph()


func set_router(router: Node) -> void:
	_router = router


func _set_tab_titles() -> void:
	if tab_container.get_tab_count() >= 4:
		tab_container.set_tab_title(0, "배치")
		tab_container.set_tab_title(1, "인벤토리")
		tab_container.set_tab_title(2, "장비")
		tab_container.set_tab_title(3, "후퇴")


func _build_dummy_item_buttons() -> void:
	for c in item_buttons_grid.get_children():
		c.queue_free()
	for i in range(8):
		var btn: Button = Button.new()
		btn.text = "아이템 %d" % (i + 1)
		btn.custom_minimum_size = Vector2(100, 36)
		item_buttons_grid.add_child(btn)


func _setup_deploy_tab() -> void:
	var dui: TrpgDeploymentUI = DeploymentUIScene.instantiate() as TrpgDeploymentUI
	deploy_placeholder.add_child(dui)
	dui.set_anchors_preset(Control.PRESET_FULL_RECT)
	dui.anchor_right = 1.0
	dui.anchor_bottom = 1.0
	dui.offset_left = 0.0
	dui.offset_top = 0.0
	dui.offset_right = 0.0
	dui.offset_bottom = 0.0
	_deployment_ui = dui
	var roster: TrpgRoster = TrpgRoster.new()
	if _state and _state.campaign:
		roster.unlocked_count = _state.campaign.unlocked_count
	else:
		roster.unlocked_count = 4
	var plan: TrpgDeploymentPlan = _plan_from_campaign()
	dui.setup(roster, plan, null)
	dui.deployment_confirmed.connect(_on_deploy_saved)


func _plan_from_campaign() -> TrpgDeploymentPlan:
	var p: TrpgDeploymentPlan = TrpgDeploymentPlan.new()
	if not _state or not _state.campaign:
		return p
	var camp = _state.campaign
	if not camp.get("deployment_placements"):
		return p
	for unit_id in camp.deployment_placements:
		var v = camp.deployment_placements[unit_id]
		if v is Array and v.size() >= 2:
			p.set_placement(str(unit_id), Vector2i(int(v[0]), int(v[1])))
	return p


func _on_deploy_saved(plan: TrpgDeploymentPlan) -> void:
	if not _state or not _state.campaign:
		return
	var camp = _state.campaign
	camp.deployment_placements.clear()
	for unit_id in plan.placements:
		var cell: Vector2i = plan.placements[unit_id]
		camp.deployment_placements[str(unit_id)] = [cell.x, cell.y]
	_state.save_game()
	label_desc.text = "배치를 저장했습니다."


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
	label_title.text = "탐색"
	label_desc.text = "현재 노드: %d | 룻: %s" % [_current_node_id, str(_state.run.run_loot) if _state and _state.run else ""]
	texture_rect_encounter.visible = false
	map_view.set_data(_graph_nodes, _layout, _current_node_id, _cleared_nodes)


func _on_node_reached(node_id: int) -> void:
	if node_id not in _node_by_id:
		return
	var n: DungeonGraph.DungeonNode = _node_by_id[node_id]
	match n.type:
		DungeonGraph.NodeType.BATTLE:
			_show_encounter_then_battle(node_id, false)
		DungeonGraph.NodeType.BOSS:
			_show_encounter_then_battle(node_id, true)
		DungeonGraph.NodeType.LOOT:
			_do_loot(node_id)
		DungeonGraph.NodeType.EVENT:
			_do_event(node_id)
		DungeonGraph.NodeType.START:
			_rebuild_ui()


func _show_encounter_then_battle(node_id: int, is_boss: bool) -> void:
	texture_rect_encounter.visible = true
	label_desc.text = "조우!"
	await get_tree().create_timer(0.7).timeout
	texture_rect_encounter.visible = false
	_enter_battle(node_id, is_boss)


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
	label_desc.text = "보물을 획득했습니다."
	_complete_node(node_id)


func _do_event(node_id: int) -> void:
	if not _state or not _state.campaign:
		return
	var c: CampaignState = _state.campaign
	if randi() % 2 == 0:
		for uid in TrpgIds.UNIT_IDS:
			var f: int = c.fatigue.get(uid, 0)
			c.fatigue[uid] = clampi(f + 10, 0, 100)
		label_desc.text = "이벤트: 피로도가 올랐습니다."
	else:
		var uid: String = TrpgIds.UNIT_IDS[randi() % TrpgIds.UNIT_IDS.size()]
		var b: int = c.bonds.get(uid, 0)
		c.bonds[uid] = b + 1
		label_desc.text = "이벤트: 유대가 올랐습니다."
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
	var node: DungeonGraph.DungeonNode = _node_by_id.get(node_id, null)
	if node and node.type == DungeonGraph.NodeType.BOSS:
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


func _on_retreat() -> void:
	if _state and _state.has_method("end_run"):
		_state.end_run(true)
	if _router and _router.has_method("go_to_hub"):
		_router.go_to_hub()


func _on_to_hub() -> void:
	if _router and _router.has_method("go_to_hub"):
		_router.go_to_hub()
