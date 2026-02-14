extends Resource
class_name RunState

## 런 전용 상태. 전멸/귀환 시 초기화.

var active: bool = false
var floor_num: int = 1
var node_index: int = 0
var run_loot: Array[String] = []       ## 런 획득 아이템 (전멸 시 삭제)
var run_meta_gain: int = 0             ## 런에서 얻은 영구 자원 (전멸 시 0)
var used_consumables: Array[String] = []  ## 이번 런 사용 소모품 로그
var pending_battle_won: bool = false   ## 전투 승리 후 Dungeon 복귀 시 노드 완료용


func reset() -> void:
	active = false
	floor_num = 1
	node_index = 0
	run_loot.clear()
	run_meta_gain = 0
	used_consumables.clear()
	pending_battle_won = false
