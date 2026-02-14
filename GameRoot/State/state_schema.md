# State Schema

## CampaignState (영구 저장)

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| day | int | 1 | 진행일 |
| unlocked_count | int | 4 | 해금된 유닛 수 (4~7) |
| meta_currency | int | 0 | 영구 자원 |
| bonds | Dictionary | {} | unit_id -> int (유닛별 유대도) |
| fatigue | Dictionary | {} | unit_id -> int (0~100 피로도) |
| personal_story_progress | Dictionary | {} | unit_id -> String or int |
| flags | Dictionary | {} | String -> bool (플래그) |

## RunState (런 전용, 전멸 시 초기화)

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| active | bool | false | 런 진행 중 여부 |
| floor_num | int | 1 | 현재 층 |
| node_index | int | 0 | 현재 노드 인덱스 |
| run_loot | Array[String] | [] | 런 획득 아이템 (전멸 시 삭제) |
| run_meta_gain | int | 0 | 런에서 얻은 영구 자원 (전멸 시 0) |
| used_consumables | Array[String] | [] | 이번 런 사용 소모품 로그 |

## StateService

- **저장 경로**: user://save.json
- **new_game()**: 캠페인 초기화
- **start_run()**: 런 시작, run.active=true
- **end_run(success)**: success=false면 run_loot/run_meta_gain 폐기, fatigue 패널티 적용
- **advance_day()**: campaign.day += 1
