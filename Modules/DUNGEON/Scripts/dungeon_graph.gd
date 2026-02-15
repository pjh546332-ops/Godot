extends RefCounted
class_name DungeonGraph

## 던전 층 그래프 생성. 노드 타입 및 인접 관계.

enum NodeType {
	START,
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
		NodeType.START:
			return ""
		NodeType.BATTLE:
			return "전투"
		NodeType.LOOT:
			return "보물"
		NodeType.EVENT:
			return "이벤트"
		NodeType.BOSS:
			return "보스"
	return "?"


## 노드형 던전 맵: 고정 레이아웃 10~15노드. 하단 시작 → 중간 분기 → 상단 보스 1개.
static func generate_test_graph() -> Array[DungeonNode]:
	var nodes: Array[DungeonNode] = []
	# 하단 시작(0) → 1,2. Node 0은 START(맨 아래, 텍스트 없음).
	nodes.append(DungeonNode.new(0, NodeType.START, [1, 2]))
	nodes.append(DungeonNode.new(1, NodeType.BATTLE, [3, 4]))
	nodes.append(DungeonNode.new(2, NodeType.LOOT, [4, 5]))
	nodes.append(DungeonNode.new(3, NodeType.EVENT, [6]))
	nodes.append(DungeonNode.new(4, NodeType.BATTLE, [6, 7]))
	nodes.append(DungeonNode.new(5, NodeType.LOOT, [7]))
	nodes.append(DungeonNode.new(6, NodeType.BATTLE, [8]))
	nodes.append(DungeonNode.new(7, NodeType.EVENT, [8, 9]))
	nodes.append(DungeonNode.new(8, NodeType.LOOT, [10]))
	nodes.append(DungeonNode.new(9, NodeType.BATTLE, [10]))
	nodes.append(DungeonNode.new(10, NodeType.BOSS, []))
	return nodes


## BFS로 행 할당 후, 행별로 x 위치 분배. id → Vector2 (맵 그리기용).
static func get_node_layout(nodes: Array[DungeonNode], start_id: int) -> Dictionary:
	var id_to_node: Dictionary = {}
	for n in nodes:
		id_to_node[n.id] = n
	var row_by_id: Dictionary = {}
	var queue: Array = [start_id]
	row_by_id[start_id] = 0
	var qidx: int = 0
	while qidx < queue.size():
		var cur: int = queue[qidx]
		qidx += 1
		var node: DungeonNode = id_to_node.get(cur, null)
		if not node:
			continue
		var next_row: int = row_by_id[cur] + 1
		for nid in node.next_ids:
			if nid not in row_by_id:
				row_by_id[nid] = next_row
				queue.append(nid)
	var row_to_ids: Dictionary = {}
	for id in row_by_id:
		var r: int = row_by_id[id]
		if r not in row_to_ids:
			row_to_ids[r] = []
		row_to_ids[r].append(id)
	for r in row_to_ids:
		row_to_ids[r].sort()
	var layout: Dictionary = {}
	var row_count: int = row_to_ids.size()
	for r in range(row_count):
		var ids_in_row: Array = row_to_ids.get(r, [])
		var n_in_row: int = ids_in_row.size()
		for i in range(n_in_row):
			var nid: int = ids_in_row[i]
			# x: 0~1 보간, y: 아래(0) ~ 위(1)
			var x: float = (float(i) + 0.5) / max(1, n_in_row) if n_in_row > 0 else 0.5
			var y: float = 1.0 - float(r) / max(1, row_count - 1) if row_count > 1 else 0.5
			layout[nid] = Vector2(x, y)
	return layout
