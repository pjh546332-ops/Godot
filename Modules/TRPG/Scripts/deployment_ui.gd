extends Control
class_name TrpgDeploymentUI

## 전투 전 배치 UI. 4x4 그리드, 해금 유닛 배치, Auto/Clear/Start Battle.

signal deployment_confirmed(plan: TrpgDeploymentPlan)

const GRID_COLS: int = 4
const GRID_ROWS: int = 4
const CELL_SIZE: int = 64
const TILE_GAP: int = 4

@onready var unit_list: VBoxContainer = $MainHBox/UnitListPanel/MarginContainer/VBox/ScrollContainer/UnitList
@onready var grid_container: GridContainer = $MainHBox/DeployPanel/GridArea/GridContainer
@onready var btn_auto: Button = $MainHBox/DeployPanel/ButtonRow/BtnAuto
@onready var btn_clear: Button = $MainHBox/DeployPanel/ButtonRow/BtnClear
@onready var btn_start: Button = $MainHBox/DeployPanel/ButtonRow/BtnStart
@onready var label_selected: Label = $MainHBox/DeployPanel/LabelSelected

var roster: TrpgRoster
var plan: TrpgDeploymentPlan
var map: TrpgMapData
var _selected_unit_id: String = ""
var _cell_buttons: Array[Button] = []
var _unit_item_buttons: Array[Button] = []


func _ready() -> void:
	if not roster:
		roster = TrpgRoster.new()
		roster.unlocked_count = 4
	if not plan:
		plan = TrpgDeploymentPlan.new()
	_build_unit_list()
	_build_grid()
	_connect_buttons()
	_refresh_ui()


func setup(p_roster: TrpgRoster, p_plan: TrpgDeploymentPlan = null, p_map: TrpgMapData = null) -> void:
	roster = p_roster
	plan = p_plan if p_plan else TrpgDeploymentPlan.new()
	map = p_map
	if is_node_ready():
		_build_unit_list()
		_build_grid()
		_refresh_ui()


func _build_unit_list() -> void:
	if not unit_list:
		return
	for c in unit_list.get_children():
		c.queue_free()
	_unit_item_buttons.clear()
	for unit_id in roster.get_unlocked_ids():
		var ud: TrpgUnitData = TrpgUnitData.load_for_id(unit_id)
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(120, 48)
		btn.text = ud.display_name if ud else unit_id
		btn.set_meta("unit_id", unit_id)
		btn.pressed.connect(_on_unit_item_pressed.bind(unit_id))
		unit_list.add_child(btn)
		_unit_item_buttons.append(btn)


func _is_front_row(cell_x: int) -> bool:
	return cell_x >= 2


func _build_grid() -> void:
	if not grid_container:
		return
	for c in grid_container.get_children():
		c.queue_free()
	_cell_buttons.clear()
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var cell: Vector2i = Vector2i(x, y)
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			btn.set_meta("cell", cell)
			btn.pressed.connect(_on_cell_pressed.bind(cell))
			_apply_cell_style(btn, cell)
			grid_container.add_child(btn)
			_cell_buttons.append(btn)


func _is_cell_forbidden(cell: Vector2i) -> bool:
	return map and map.is_deploy_cell_blocked(cell)


func _apply_cell_style(btn: Button, cell: Vector2i) -> void:
	var cell_x: int = cell.x
	if _is_cell_forbidden(cell):
		btn.add_theme_color_override("font_color", Color(0.5, 0.2, 0.2))
		btn.add_theme_color_override("font_hover_color", Color(0.7, 0.3, 0.3))
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.2, 0.2))
	elif _is_front_row(cell_x):
		btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.9))
	else:
		btn.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(0.9, 0.95, 1))


func _connect_buttons() -> void:
	if btn_auto:
		btn_auto.pressed.connect(_on_auto_pressed)
	if btn_clear:
		btn_clear.pressed.connect(_on_clear_pressed)
	if btn_start:
		btn_start.pressed.connect(_on_start_pressed)


func _on_unit_item_pressed(unit_id: String) -> void:
	_selected_unit_id = unit_id
	_refresh_ui()


func _on_cell_pressed(cell: Vector2i) -> void:
	if _is_cell_forbidden(cell):
		return
	var existing: String = plan.get_unit_at_cell(cell)
	if existing != "":
		plan.remove_placement(existing)
		_selected_unit_id = ""
	elif _selected_unit_id != "":
		var prev_cell: Vector2i = plan.get_placement(_selected_unit_id)
		if prev_cell.x >= 0:
			plan.remove_placement(_selected_unit_id)
		plan.set_placement(_selected_unit_id, cell)
		_selected_unit_id = ""
	_refresh_ui()


func _on_auto_pressed() -> void:
	plan.clear_all()
	var ids: Array = roster.get_unlocked_ids()
	var idx: int = 0
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			if idx >= ids.size():
				break
			var cell: Vector2i = Vector2i(x, y)
			if _is_cell_forbidden(cell):
				continue
			plan.set_placement(ids[idx], cell)
			idx += 1
		if idx >= ids.size():
			break
	_selected_unit_id = ""
	_refresh_ui()


func _on_clear_pressed() -> void:
	plan.clear_all()
	_selected_unit_id = ""
	_refresh_ui()


func _on_start_pressed() -> void:
	deployment_confirmed.emit(plan)


func _refresh_ui() -> void:
	for btn in _cell_buttons:
		var cell: Vector2i = btn.get_meta("cell")
		var forbidden: bool = _is_cell_forbidden(cell)
		btn.disabled = forbidden
		if forbidden:
			btn.text = "X"
			continue
		var uid: String = plan.get_unit_at_cell(cell)
		if uid != "":
			var ud: TrpgUnitData = TrpgUnitData.load_for_id(uid)
			btn.text = ud.display_name if ud else uid
		else:
			btn.text = ""
	for btn in _unit_item_buttons:
		var uid: String = btn.get_meta("unit_id")
		var placed: bool = plan.get_placement(uid).x >= 0
		btn.disabled = placed
	if label_selected:
		if _selected_unit_id != "":
			var ud: TrpgUnitData = TrpgUnitData.load_for_id(_selected_unit_id)
			label_selected.text = "선택: %s (칸 클릭)" % (ud.display_name if ud else _selected_unit_id)
		else:
			label_selected.text = "선택: 없음 (유닛 클릭 후 칸 클릭)"


func get_plan() -> TrpgDeploymentPlan:
	return plan
