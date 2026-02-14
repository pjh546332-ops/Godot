extends Resource
class_name TrpgDeploymentPlan

## 배치 결과 저장. unit_id -> Vector2i(deploy cell 0..3)

@export var placements: Dictionary = {}  ## String (unit_id) -> Vector2i


func set_placement(unit_id: String, cell: Vector2i) -> void:
	placements[unit_id] = cell


func get_placement(unit_id: String) -> Vector2i:
	return placements.get(unit_id, Vector2i(-1, -1))


func remove_placement(unit_id: String) -> void:
	placements.erase(unit_id)


func clear_all() -> void:
	placements.clear()


func get_placed_unit_ids() -> Array[String]:
	var out: Array[String] = []
	for id in placements:
		out.append(id)
	return out


func get_unit_at_cell(cell: Vector2i) -> String:
	for unit_id in placements:
		if placements[unit_id] == cell:
			return unit_id
	return ""


func duplicate_plan() -> TrpgDeploymentPlan:
	var p: TrpgDeploymentPlan = TrpgDeploymentPlan.new()
	for k in placements:
		p.placements[k] = placements[k]
	return p
