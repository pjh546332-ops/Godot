extends Control
class_name ActionPanel

## 액션 패널: Move / Attack / Wait 버튼, 현재 턴 유닛 표시.

signal action_move
signal action_attack
signal action_wait

@onready var label_unit: Label = $VBox/LabelUnit
@onready var btn_move: Button = $VBox/HBox/BtnMove
@onready var btn_attack: Button = $VBox/HBox/BtnAttack
@onready var btn_wait: Button = $VBox/HBox/BtnWait


func _ready() -> void:
	if btn_move:
		btn_move.pressed.connect(_on_move_pressed)
	if btn_attack:
		btn_attack.pressed.connect(_on_attack_pressed)
	if btn_wait:
		btn_wait.pressed.connect(_on_wait_pressed)
	hide()


func set_unit(unit: BattleUnit3D) -> void:
	if unit:
		label_unit.text = "%s HP:%d/%d" % [unit.name, unit.hp, unit.max_hp]
		show()
		set_process_input(true)
	else:
		label_unit.text = "-"
		hide()


func set_enabled(enabled: bool) -> void:
	visible = enabled
	if btn_move:
		btn_move.disabled = not enabled
	if btn_attack:
		btn_attack.disabled = not enabled
	if btn_wait:
		btn_wait.disabled = not enabled


func _on_move_pressed() -> void:
	action_move.emit()


func _on_attack_pressed() -> void:
	action_attack.emit()


func _on_wait_pressed() -> void:
	action_wait.emit()
