extends Node

## 캠페인/런 상태 관리. JSON 저장/로드. Autoload "StateService"로 등록.

const SAVE_PATH: String = "user://save.json"
const FATIGUE_PENALTY_ON_DEATH: int = 20

var campaign  ## CampaignState
var run  ## RunState

const _CampaignStateScript = preload("res://GameRoot/State/campaign_state.gd")
const _RunStateScript = preload("res://GameRoot/State/run_state.gd")
const _TrpgIds = preload("res://Modules/TRPG/Scripts/trpg_ids.gd")


func _ready() -> void:
	campaign = _CampaignStateScript.new()
	run = _RunStateScript.new()
	if not load_game():
		new_game()


func new_game() -> void:
	campaign = _CampaignStateScript.new()
	campaign.day = 1
	campaign.unlocked_count = 4
	campaign.meta_currency = 0
	campaign.bonds.clear()
	campaign.fatigue.clear()
	campaign.personal_story_progress.clear()
	campaign.flags.clear()
	run.reset()
	save_game()
	print("[StateService] new_game")


func start_run() -> void:
	run.reset()
	run.active = true
	run.floor_num = 1
	run.node_index = 0
	save_game()
	print("[StateService] start_run")


func end_run(success: bool) -> void:
	if success:
		campaign.meta_currency += run.run_meta_gain
		# run_loot는 추후 인벤토리 등에 반영 가능
	else:
		_apply_fatigue_penalty()
	run.reset()
	save_game()
	print("[StateService] end_run success=%s" % success)


func _apply_fatigue_penalty() -> void:
	var unit_ids: Array = _TrpgIds.UNIT_IDS
	for id in unit_ids:
		var uid: String = str(id)
		var cur: int = campaign.fatigue.get(uid, 0)
		campaign.fatigue[uid] = mini(100, cur + FATIGUE_PENALTY_ON_DEATH)


func advance_day() -> void:
	campaign.day += 1
	save_game()
	print("[StateService] advance_day -> %d" % campaign.day)


func save_game() -> void:
	var data: Dictionary = {
		"campaign": campaign.to_dict()
	}
	var json_str: String = JSON.stringify(data)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
	else:
		push_error("[StateService] save failed: %s" % FileAccess.get_open_error())


func _campaign_from_dict(d: Dictionary):
	var s = _CampaignStateScript.new()
	s.load_from_dict(d)
	return s


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: Error = json.parse(json_str)
	if err != OK:
		push_error("[StateService] load parse error: %s" % json.get_error_message())
		return false
	var data = json.data
	if data is Dictionary and data.has("campaign"):
		campaign = _campaign_from_dict(data.campaign)
		run.reset()
		print("[StateService] load_game")
		return true
	return false
