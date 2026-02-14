extends RefCounted
class_name DungeonGraph

## 던전 층 그래프 생성. 노드 타입 및 인접 관계.

enum NodeType {
	BATTLE,
	LOOT,
	EVENT,
	BOSS
}

const NODES_PER_FLOOR: int = 3
const FLOOR_COUNT: int = 9


class DungeonNode:
	var id: int
	var type: DungeonGraph.NodeType
	var next_ids: Array[int] = []

	func _init(p_id: int, p_type: DungeonGraph.NodeType, p_next: Array[int] = []) -> void:
		id = p_id
		type = p_type
		next_ids.assign(p_next)


## 층 번호(1~9)에 대한 그래프 생성. 노드 0->1->2 선형.
static func generate_floor(floor_num: int) -> Array[DungeonNode]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var nodes: Array[DungeonNode] = []
	var is_last_floor: bool = (floor_num >= FLOOR_COUNT)
	# 노드 0: 진입 (EVENT)
	nodes.append(DungeonNode.new(0, NodeType.EVENT, [1]))
	# 노드 1: BATTLE/LOOT/EVENT 랜덤
	var mid_type: NodeType = _rand_mid_type(rng)
	nodes.append(DungeonNode.new(1, mid_type, [2]))
	# 노드 2: 마지막 층이면 BOSS, 아니면 BATTLE/LOOT/EVENT
	var last_type: NodeType = NodeType.BOSS if is_last_floor else _rand_mid_type(rng)
	nodes.append(DungeonNode.new(2, last_type, []))
	return nodes


static func _rand_mid_type(rng: RandomNumberGenerator) -> NodeType:
	var choices: Array[NodeType] = [NodeType.BATTLE, NodeType.LOOT, NodeType.EVENT]
	return choices[rng.randi() % choices.size()]


static func get_type_name(t: NodeType) -> String:
	match t:
		NodeType.BATTLE:
			return "전투"
		NodeType.LOOT:
			return "보물"
		NodeType.EVENT:
			return "이벤트"
		NodeType.BOSS:
			return "보스"
	return "?"
