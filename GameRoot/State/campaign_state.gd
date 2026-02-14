extends Resource
class_name CampaignState

## 영구 저장 상태. 진행일, 해금, 영구자원, 유닛 관계/피로/스토리, 플래그.

var day: int = 1
var unlocked_count: int = 4
var meta_currency: int = 0
var bonds: Dictionary = {}      ## unit_id -> int
var fatigue: Dictionary = {}    ## unit_id -> int (0~100)
var personal_story_progress: Dictionary = {}  ## unit_id -> String or int
var flags: Dictionary = {}      ## String -> bool


func to_dict() -> Dictionary:
	return {
		"day": day,
		"unlocked_count": unlocked_count,
		"meta_currency": meta_currency,
		"bonds": bonds.duplicate(),
		"fatigue": fatigue.duplicate(),
		"personal_story_progress": personal_story_progress.duplicate(),
		"flags": flags.duplicate()
	}


func load_from_dict(d: Dictionary) -> void:
	if d.has("day"):
		day = int(d.day)
	if d.has("unlocked_count"):
		unlocked_count = int(d.unlocked_count)
	if d.has("meta_currency"):
		meta_currency = int(d.meta_currency)
	if d.has("bonds"):
		bonds = _dict_copy(d.bonds)
	if d.has("fatigue"):
		fatigue = _dict_copy(d.fatigue)
	if d.has("personal_story_progress"):
		personal_story_progress = _dict_copy(d.personal_story_progress)
	if d.has("flags"):
		flags.clear()
		for k in d.flags:
			flags[str(k)] = bool(d.flags[k])


static func _dict_copy(src) -> Dictionary:
	var out: Dictionary = {}
	if src is Dictionary:
		for k in src:
			out[k] = src[k]
	return out
