extends Node

## TRPG 전투용 물리 레이어/마스크 상수. 한 곳에서 관리. (Autoload: TrpgLayers)

const LAYER_FLOOR := 1
const LAYER_UNIT := 2
## floor(1) | unit(2) - 레이캐스트 감지용
const COLLISION_MASK_FLOOR_AND_UNIT := 3
