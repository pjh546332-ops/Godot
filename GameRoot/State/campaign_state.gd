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
var deployment_placements: Dictionary = {}  ## unit_id (string) -> [x, y] (4x4 배치 좌표)


func to_dict() -> Dictionary:
	var placements_serialized: Dictionary = {}
	for k in deployment_placements:
		var v = deployment_placements[k]
		if v is Array and v.size() >= 2:
			placements_serialized[k] = [int(v[0]), int(v[1])]
		elif v is Vector2i:
			placements_serialized[k] = [v.x, v.y]
	return {
		"day": day,
		"unlocked_count": unlocked_count,
		"meta_currency": meta_currency,
		"bonds": bonds.duplicate(),
		"fatigue": fatigue.duplicate(),
		"personal_story_progress": personal_story_progress.duplicate(),
		"flags": flags.duplicate(),
		"deployment_placements": placements_serialized
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
	if d.has("deployment_placements") and d.deployment_placements is Dictionary:
		deployment_placements.clear()
		for k in d.deployment_placements:
			var v = d.deployment_placements[k]
			if v is Array and v.size() >= 2:
				deployment_placements[str(k)] = [int(v[0]), int(v[1])]


static func _dict_copy(src) -> Dictionary:
	var out: Dictionary = {}
	if src is Dictionary:
		for k in src:
			out[k] = src[k]
	return out
