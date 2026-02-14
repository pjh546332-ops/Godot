extends RefCounted
class_name TrpgRoster

## 고정 7인 로스터. unlocked_count에 따라 4~7명 합류.

var unlocked_count: int = 4


func get_unlocked_ids() -> Array[String]:
	var out: Array[String] = []
	var n: int = mini(unlocked_count, TrpgIds.UNIT_IDS.size())
	for i in range(n):
		out.append(TrpgIds.UNIT_IDS[i])
	return out


func unlock_next() -> void:
	if unlocked_count < TrpgIds.UNIT_IDS.size():
		unlocked_count += 1


func is_unlocked(id: String) -> bool:
	return id in get_unlocked_ids()
