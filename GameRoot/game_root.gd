extends Control

## 게임 플로우 상태 머신. Hub -> Dungeon -> Battle -> Hub 복귀.

enum GameState {
	HUB_NIGHT,
	DUNGEON_DAY,
	BATTLE,
	CUTSCENE
}

signal state_changed(new_state: GameState)

const HUB_SCENE = preload("res://Modules/HUB/Scenes/HubNight.tscn")
const DUNGEON_SCENE = preload("res://Modules/DUNGEON/Scenes/DungeonDay.tscn")
const BATTLE_SCENE = preload("res://Modules/TRPG/Scenes/BattleScene3D.tscn")
const CUTSCENE_SCENE = preload("res://GameRoot/Scenes/CutscenePlaceholder.tscn")

@onready var scene_container: Control = $SceneContainer

var _current_state: GameState = GameState.HUB_NIGHT
var _current_scene: Node = null
var _pending_battle_floor9: bool = false


func _ready() -> void:
	go_to_hub()


func get_current_state() -> GameState:
	return _current_state


func go_to_hub() -> void:
	_transition_to(GameState.HUB_NIGHT, HUB_SCENE)


func go_to_dungeon(from_battle_return: bool = false) -> void:
	if not from_battle_return:
		var ss = get_node_or_null("/root/StateService")
		if ss and ss.has_method("start_run"):
			ss.start_run()
	_transition_to(GameState.DUNGEON_DAY, DUNGEON_SCENE)


func go_to_battle() -> void:
	_pending_battle_floor9 = false
	_transition_to(GameState.BATTLE, BATTLE_SCENE)


func go_to_battle_from_dungeon(is_floor9_boss: bool) -> void:
	_pending_battle_floor9 = is_floor9_boss
	_transition_to(GameState.BATTLE, BATTLE_SCENE)


func go_to_cutscene() -> void:
	_transition_to(GameState.CUTSCENE, CUTSCENE_SCENE)


func _transition_to(new_state: GameState, scene: PackedScene) -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null
	var inst: Node = scene.instantiate()
	scene_container.add_child(inst)
	_current_scene = inst
	_current_state = new_state
	state_changed.emit(new_state)
	_setup_scene_buttons(inst)
	if new_state == GameState.BATTLE:
		await get_tree().process_frame
		_connect_battle_result()
	print("[GameRoot] -> %s" % GameState.keys()[new_state])


func _setup_scene_buttons(inst: Node) -> void:
	if inst.has_method("set_router"):
		inst.set_router(self)
	var hub_btn = _find_button(inst, "BtnToHub")
	if hub_btn:
		hub_btn.pressed.connect(go_to_hub)
	var dungeon_btn = _find_button(inst, "BtnToDungeon")
	if dungeon_btn:
		dungeon_btn.pressed.connect(go_to_dungeon)
	var battle_btn = _find_button(inst, "BtnToBattle")
	if battle_btn:
		battle_btn.pressed.connect(go_to_battle)
	var cutscene_btn = _find_button(inst, "BtnToCutscene")
	if cutscene_btn:
		cutscene_btn.pressed.connect(go_to_cutscene)


func _find_button(node: Node, name_substr: String) -> Button:
	if node is Button and name_substr in node.name:
		return node as Button
	for c in node.get_children():
		var found = _find_button(c, name_substr)
		if found:
			return found
	return null


func _connect_battle_result() -> void:
	if not _current_scene:
		return
	if _current_scene.has_signal("battle_result"):
		if not _current_scene.battle_result.is_connected(_on_battle_result):
			_current_scene.battle_result.connect(_on_battle_result)
		return
	var tm = _current_scene.get_node_or_null("TurnManager")
	if not tm:
		tm = _find_turn_manager(_current_scene)
	if tm and tm.has_signal("battle_ended"):
		if not tm.battle_ended.is_connected(_on_battle_ended_legacy):
			tm.battle_ended.connect(_on_battle_ended_legacy)


func _find_turn_manager(node: Node) -> Node:
	if node.get_class() == "TurnManager" or (node.get_script() and "TurnManager" in str(node.get_script())):
		return node
	for c in node.get_children():
		var found = _find_turn_manager(c)
		if found:
			return found
	return null


func _on_battle_result(won: bool, wiped: bool, loot: Array, meta_gain: int) -> void:
	var ss = get_node_or_null("/root/StateService")
	if wiped:
		if ss and ss.has_method("end_run"):
			ss.end_run(false)
		go_to_hub()
		return
	if won:
		if ss and ss.run:
			ss.run.run_meta_gain += meta_gain
			for item in loot:
				ss.run.run_loot.append(str(item))
		if _pending_battle_floor9:
			_pending_battle_floor9 = false
			if ss and ss.has_method("end_run"):
				ss.end_run(true)
			go_to_hub()
			return
		_pending_battle_floor9 = false
		if ss and ss.run:
			ss.run.pending_battle_won = true
		go_to_dungeon(true)


func _on_battle_ended_legacy(winner_team: int) -> void:
	var won: bool = (winner_team == TurnManager.Team.ALLY)
	var wiped: bool = not won
	var loot: Array = ["더미_전투보상"] if won else []
	var meta_gain: int = 5 if won else 0
	_on_battle_result(won, wiped, loot, meta_gain)
