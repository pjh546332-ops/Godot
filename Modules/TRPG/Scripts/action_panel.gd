extends Control
class_name ActionPanel

## 액션 패널: Move / Attack / End Turn, AP/MP 바, 현재 턴 유닛 표시.

const AP_COLOR: Color = Color(1.0, 0.9, 0.2, 1.0)
const MP_COLOR: Color = Color(0.3, 0.9, 0.3, 1.0)
const BAR_DIM_ALPHA: float = 0.2
const BAR_SIZE: int = 12

signal action_move
signal action_attack
signal action_end_turn

@onready var label_unit: Label = $VBox/LabelUnit
@onready var points_row: HBoxContainer = $VBox/PointsRow
@onready var ap_bars: HBoxContainer = $VBox/PointsRow/APBars
@onready var mp_bars: HBoxContainer = $VBox/PointsRow/MPBars
@onready var btn_move: Button = $VBox/ButtonsRow/BtnMove
@onready var btn_attack: Button = $VBox/ButtonsRow/BtnAttack
@onready var btn_end_turn: Button = $VBox/ButtonsRow/BtnEndTurn

var _current_unit: BattleUnit3D = null
var _attack_available: bool = false


func set_attack_available(available: bool) -> void:
	_attack_available = available
	_refresh_buttons()


func _ready() -> void:
	if btn_move:
		btn_move.pressed.connect(_on_move_pressed)
	if btn_attack:
		btn_attack.pressed.connect(_on_attack_pressed)
	if btn_end_turn:
		btn_end_turn.pressed.connect(_on_end_turn_pressed)
	hide()


func set_unit(unit: BattleUnit3D) -> void:
	_current_unit = unit
	_attack_available = false
	if unit:
		label_unit.text = "%s HP:%d/%d" % [unit.name, unit.hp, unit.max_hp]
		_build_bars(unit.base_ap, unit.base_mp)
		_update_bars(unit.ap, unit.mp)
		_refresh_buttons()
		show()
		set_process_input(true)
	else:
		label_unit.text = "-"
		hide()


func refresh(attack_available: bool = false) -> void:
	if _current_unit:
		_attack_available = attack_available
		label_unit.text = "%s HP:%d/%d" % [_current_unit.name, _current_unit.hp, _current_unit.max_hp]
		_update_bars(_current_unit.ap, _current_unit.mp)
		_refresh_buttons()


func set_enabled(enabled: bool) -> void:
	visible = enabled
	if enabled and _current_unit:
		_refresh_buttons()


func _build_bars(base_ap: int, base_mp: int) -> void:
	for c in ap_bars.get_children():
		c.queue_free()
	for c in mp_bars.get_children():
		c.queue_free()
	for i in range(maxi(1, base_ap)):
		var rect: ColorRect = ColorRect.new()
		rect.custom_minimum_size = Vector2(BAR_SIZE, BAR_SIZE)
		rect.color = AP_COLOR
		ap_bars.add_child(rect)
	for i in range(maxi(1, base_mp)):
		var rect: ColorRect = ColorRect.new()
		rect.custom_minimum_size = Vector2(BAR_SIZE, BAR_SIZE)
		rect.color = MP_COLOR
		mp_bars.add_child(rect)


func _update_bars(ap_val: int, mp_val: int) -> void:
	var ap_children: Array = ap_bars.get_children()
	for i in range(ap_children.size()):
		var r: ColorRect = ap_children[i] as ColorRect
		if r:
			r.modulate.a = 1.0 if i < ap_val else BAR_DIM_ALPHA
	var mp_children: Array = mp_bars.get_children()
	for i in range(mp_children.size()):
		var r: ColorRect = mp_children[i] as ColorRect
		if r:
			r.modulate.a = 1.0 if i < mp_val else BAR_DIM_ALPHA


func _refresh_buttons() -> void:
	if not _current_unit:
		return
	if btn_move:
		btn_move.disabled = not _current_unit.can_move()
	if btn_attack:
		btn_attack.disabled = not (_current_unit.can_pay(2) and _attack_available)
	if btn_end_turn:
		btn_end_turn.disabled = false


func _on_move_pressed() -> void:
	action_move.emit()


func _on_attack_pressed() -> void:
	action_attack.emit()


func _on_end_turn_pressed() -> void:
	action_end_turn.emit()
