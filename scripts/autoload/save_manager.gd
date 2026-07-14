extends Node

## 메타 세이브(원혼/해금/설정 등)를 user://save.json 에 JSON 으로 영속화한다.
## JSON 을 쓰는 이유: 사람이 읽을 수 있어 밸런스 디버깅/버전 마이그레이션이 쉽다.
## M0 인프라 — 아직 호출되지 않지만 원자적 쓰기와 폴백은 미리 올바르게 구현해 둔다.

const SAVE_PATH := "user://save.json"
const TEMP_PATH := "user://save.json.tmp"
const SAVE_VERSION := 1

## 메타 데이터를 저장한다. 성공 시 true.
func save_data(data: Dictionary) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"data": data,
	}
	var json_text := JSON.stringify(payload, "\t")

	# 원자적 쓰기: 임시 파일에 먼저 쓰고 성공했을 때만 실제 경로로 교체한다.
	# 쓰는 도중 크래시가 나도 기존 save.json 이 손상되지 않게 하기 위함.
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("세이브 임시 파일 열기 실패: %s (code %d)" % [TEMP_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(json_text)
	f.close()

	var err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("세이브 파일 교체 실패: %d" % err)
		return false
	return true

## 메타 데이터를 읽는다. 파일이 없거나 손상됐으면 빈 Dictionary 로 폴백한다.
func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("세이브 파일 열기 실패: %s (code %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var json_text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("세이브 파싱 실패 — 기본값으로 폴백")
		return {}

	# 버전 불일치는 지금은 경고만. 마이그레이션은 실제 스키마가 생기면 추가한다.
	var version: int = int((parsed as Dictionary).get("version", 0))
	if version != SAVE_VERSION:
		push_warning("세이브 버전 불일치: 파일 %d vs 현재 %d" % [version, SAVE_VERSION])

	var data: Variant = (parsed as Dictionary).get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
