extends RefCounted
class_name TrpgIds

## TRPG 유닛 ID/클래스 상수. 고정 7인 로스터 매핑.

enum TrpgClass {
	SWORD,    ## 검사
	SHIELD,   ## 방패병
	BRAWLER,  ## 격투가
	ROGUE,    ## 도적
	PRIEST,   ## 사제
	ARCHER,   ## 궁수
	MAGE      ## 마법사
}

const UNIT_IDS: Array[String] = [
	"SWORD", "SHIELD", "BRAWLER", "ROGUE", "PRIEST", "ARCHER", "MAGE"
]

const UNIT_CLASS_NAMES: Dictionary = {
	TrpgClass.SWORD: "검사",
	TrpgClass.SHIELD: "방패병",
	TrpgClass.BRAWLER: "격투가",
	TrpgClass.ROGUE: "도적",
	TrpgClass.PRIEST: "사제",
	TrpgClass.ARCHER: "궁수",
	TrpgClass.MAGE: "마법사"
}

static func id_to_class(id: String) -> int:
	var idx: int = UNIT_IDS.find(id)
	if idx >= 0:
		return idx
	return TrpgClass.SWORD


static func class_to_id(cls: int) -> String:
	if cls >= 0 and cls < UNIT_IDS.size():
		return UNIT_IDS[cls]
	return UNIT_IDS[0]


static func get_class_name(cls: int) -> String:
	return UNIT_CLASS_NAMES.get(cls, "???")
