extends Control

## 밤 거점. 유닛 선택, 교류/휴식/하루종료/던전출발.

## TrpgIds, TrpgUnitData는 TRPG 모듈 class_name으로 사용

@onready var unit_list: ItemList = $Margin/VBox/UnitList
@onready var label_selected: Label = $Margin/VBox/LabelSelected
@onready var btn_interact: Button = $Margin/VBox/Actions/BtnInteract
@onready var btn_rest: Button = $Margin/VBox/Actions/BtnRest
@onready var btn_end_day: Button = $Margin/VBox/Actions/BtnEndDay
@onready var btn_dungeon: Button = $Margin/VBox/Actions/BtnDungeon
@onready var dialog_dummy: AcceptDialog = $DialogDummy

var _router: Node = null
var _state: Node = null


func _ready() -> void:
	_state = get_node_or_null("/root/StateService")
	_refresh_unit_list()
	_update_selection_display()
	btn_interact.pressed.connect(_on_interact)
	btn_rest.pressed.connect(_on_rest)
	btn_end_day.pressed.connect(_on_end_day)
	btn_dungeon.pressed.connect(_on_dungeon)
	unit_list.item_selected.connect(_on_unit_selected)
	dialog_dummy.confirmed.connect(_on_dummy_dialog_closed)


func set_router(router: Node) -> void:
	_router = router


func _refresh_unit_list() -> void:
	if not unit_list or not _state:
		return
	var campaign = _state.campaign
	var uc: int = campaign.unlocked_count if campaign else 4
	unit_list.clear()
	for i in TrpgIds.UNIT_IDS.size():
		var uid: String = TrpgIds.UNIT_IDS[i]
		var ud: TrpgUnitData = TrpgUnitData.load_for_id(uid)
		var name_str: String = ud.display_name if ud else uid
		var is_unlocked: bool = (i < uc)
		var f: int = 0
		if campaign and campaign.fatigue.has(uid):
			f = campaign.fatigue[uid]
		var text: String = "%s (피로:%d)" % [name_str, f]
		if not is_unlocked:
			text += " [잠금]"
		unit_list.add_item(text)
		unit_list.set_item_disabled(i, not is_unlocked)


func _update_selection_display() -> void:
	if not label_selected:
		return
	var idx: int = unit_list.get_selected_items()[0] if unit_list.get_selected_items().size() > 0 else -1
	if idx < 0 or idx >= TrpgIds.UNIT_IDS.size():
		label_selected.text = "선택: 없음"
		btn_interact.disabled = true
		return
	var uid: String = TrpgIds.UNIT_IDS[idx]
	var ud: TrpgUnitData = TrpgUnitData.load_for_id(uid)
	label_selected.text = "선택: %s" % (ud.display_name if ud else uid)
	var uc: int = _state.campaign.unlocked_count if _state and _state.campaign else 4
	btn_interact.disabled = (idx >= uc)


func _on_unit_selected(_idx: int) -> void:
	_update_selection_display()


func _get_selected_unit_id() -> String:
	var idx: int = unit_list.get_selected_items()[0] if unit_list.get_selected_items().size() > 0 else -1
	if idx < 0 or idx >= TrpgIds.UNIT_IDS.size():
		return ""
	return TrpgIds.UNIT_IDS[idx]


func _is_selected_unlocked() -> bool:
	var idx: int = unit_list.get_selected_items()[0] if unit_list.get_selected_items().size() > 0 else -1
	var uc: int = _state.campaign.unlocked_count if _state and _state.campaign else 4
	return idx >= 0 and idx < uc


func _on_interact() -> void:
	if not _state or not _state.campaign:
		return
	var uid: String = _get_selected_unit_id()
	if uid.is_empty() or not _is_selected_unlocked():
		return
	var c: CampaignState = _state.campaign
	var f: int = c.fatigue.get(uid, 0)
	c.fatigue[uid] = clampi(f - 20, 0, 100)
	var b: int = c.bonds.get(uid, 0)
	c.bonds[uid] = b + 1
	_state.save_game()
	if _check_main_story_trigger():
		if _router and _router.has_method("go_to_cutscene"):
			_router.go_to_cutscene()
	else:
		dialog_dummy.dialog_text = "짧은 대화 후 관계가 조금 가까워졌다."
		dialog_dummy.popup_centered()
	_refresh_unit_list()
	_update_selection_display()


func _check_main_story_trigger() -> bool:
	if not _state or not _state.campaign:
		return false
	var c: CampaignState = _state.campaign
	if c.day == 3:
		return true
	if c.flags.get("story_trigger", false):
		return true
	return false


func _on_dummy_dialog_closed() -> void:
	pass


func _on_rest() -> void:
	if not _state or not _state.campaign:
		return
	var c: CampaignState = _state.campaign
	var uc: int = c.unlocked_count
	for i in min(uc, TrpgIds.UNIT_IDS.size()):
		var uid: String = TrpgIds.UNIT_IDS[i]
		var f: int = c.fatigue.get(uid, 0)
		c.fatigue[uid] = clampi(f - 10, 0, 100)
	_state.save_game()
	_refresh_unit_list()
	_update_selection_display()


func _on_end_day() -> void:
	if _state and _state.has_method("advance_day"):
		_state.advance_day()
	_refresh_unit_list()
	_update_selection_display()


func _on_dungeon() -> void:
	if _router and _router.has_method("go_to_dungeon"):
		_router.go_to_dungeon()
