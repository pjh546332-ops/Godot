extends Resource
class_name TrpgUnitData

## TRPG 유닛 데이터 리소스. 스탯/스프라이트 템플릿.

@export var unit_id: String = "SWORD"
@export var display_name: String = "검사"
@export var unit_class: int = 0  ## TrpgIds.TrpgClass
@export var max_hp: int = 10
@export var attack_damage: int = 3
@export var attack_range: int = 1
@export var move_range: int = 4
@export var base_ap: int = 3
@export var base_mp: int = 1
@export var sprite_texture: Texture2D


static func load_for_id(id: String) -> TrpgUnitData:
	var path: String = "res://Modules/TRPG/Data/Units/%s.tres" % id.to_lower()
	return load(path) as TrpgUnitData
