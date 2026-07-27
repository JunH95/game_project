extends Node

## 모시는 신과 스탯 수정자 집계(신내림).
## 각 신은 레벨당 stat_mods 를 주고, 같은 신을 다시 고르면 레벨이 쌓인다(VS식 스택).
## 무기·플레이어는 이 노드에 수정자를 물어보고 자기 수치를 계산한다.
##
## 몸주(런 시작 시 고정되는 주신)는 캐릭터 선택이 생기는 M4에서 갈라낸다.
## 지금은 전부 "모시는 신"으로만 다룬다(design.md 3-1).

## 고를 수 있는 신 목록. 비워 두면 아래 기본 명단을 로드한다(인스펙터에서 덮어쓸 수 있다).
@export var available_gods: Array[GodData] = []

## 레벨업마다 제시하는 선택지 수.
@export var choice_count: int = 3

## MVP 신 명단(design.md 3-4). 신을 추가하면 여기에 경로를 넣는다.
const DEFAULT_GOD_PATHS: PackedStringArray = [
	"res://data/gods/jakdodaesin.tres",
	"res://data/gods/choeyeong.tres",
	"res://data/gods/sansin.tres",
	"res://data/gods/wolgwang.tres",
	"res://data/gods/chilseong.tres",
	"res://data/gods/sinjang.tres",
]

## { god_id: level }
var _served: Dictionary = {}
## 이번 런의 몸주. 시작 무기와 패시브의 출처이고, 기운의 기본값이다(design.md 3-1).
var _momju: GodData = null


func _ready() -> void:
	_served.clear()
	_momju = null
	if available_gods.is_empty():
		_load_default_gods()


func _load_default_gods() -> void:
	for path in DEFAULT_GOD_PATHS:
		var god := load(path) as GodData
		if god == null:
			push_error("신 데이터를 불러오지 못했다: %s" % path)
			continue
		available_gods.append(god)


## 몸주로 고를 수 있는 신 목록(런 시작 화면용). 해금 연동은 M4(신당).
func get_momju_candidates() -> Array[GodData]:
	var candidates: Array[GodData] = []
	for god in available_gods:
		if god != null and god.is_momju:
			candidates.append(god)
	return candidates


func get_momju() -> GodData:
	return _momju


## 런 시작 시 한 번. 몸주는 Lv1 로 모신 상태에서 출발한다(design.md 3-1 — 3택1 풀에도 포함된다).
func set_momju(god: GodData) -> void:
	if god == null:
		push_error("GodSystem.set_momju: god 이 null 이다.")
		return
	_momju = god
	RunManager.momju_id = god.id
	serve(god)
	EventBus.momju_chosen.emit(god)


## 해당 수정자 키의 총합. 신마다 (레벨당 값 × 레벨)을 더하고, 몸주면 패시브를 한 번 더 얹는다.
func get_mod(key: StringName) -> float:
	var total := 0.0
	for god in available_gods:
		if god == null or not _served.has(god.id):
			continue
		if god.stat_mods.has(key):
			total += float(god.stat_mods[key]) * float(_served[god.id])
	# 몸주 패시브는 레벨과 무관하게 한 번만 붙는다.
	if _momju != null and _momju.momju_stat_mods.has(key):
		total += float(_momju.momju_stat_mods[key])
	return total


## 퍼센트 수정자를 배율로. 예: -7 -> 0.93
func get_multiplier(key: StringName) -> float:
	return maxf(0.0, 1.0 + get_mod(key) * 0.01)


func get_level(god_id: StringName) -> int:
	return int(_served.get(god_id, 0))


## 이 무기를 지금 들고 있는지 — 몸주가 준 시작 무기이거나, 모시는 신이 부여했거나(design.md 2-1).
func grants_weapon(weapon_id: StringName) -> bool:
	if _momju != null and _momju.momju_weapon == weapon_id:
		return true
	for god in available_gods:
		if god == null or not _served.has(god.id):
			continue
		if god.grants_weapon == weapon_id:
			return true
	return false


## 지금 실린 기운(design.md 3-3). 모시는 신을 오행별로 묶어 레벨 합이 가장 큰 오행.
## 동률이면 몸주의 오행으로 확정한다 — 런 시작 기운이 몸주 오행인 것도 이 규칙에서 나온다.
func get_element() -> StringName:
	var totals: Dictionary = {}
	for god in available_gods:
		if god == null or not _served.has(god.id) or god.element == &"":
			continue
		totals[god.element] = int(totals.get(god.element, 0)) + int(_served[god.id])

	var best: StringName = &""
	var best_total := 0
	var tied := false
	for element in totals:
		var total: int = totals[element]
		if total > best_total:
			best = element
			best_total = total
			tied = false
		elif total == best_total:
			tied = true
	if tied or best == &"":
		return _momju.element if _momju != null else &""
	return best


func get_served() -> Dictionary:
	return _served.duplicate()


## 이번 레벨업에 제시할 선택지. 만렙인 신은 제외한다.
func roll_choices() -> Array[GodData]:
	var pool: Array[GodData] = []
	for god in available_gods:
		if god != null and get_level(god.id) < god.max_level:
			pool.append(god)
	pool.shuffle()
	return pool.slice(0, mini(choice_count, pool.size()))


## 선택한 신을 모신다(이미 모시는 신이면 레벨 +1).
func serve(god: GodData) -> void:
	if god == null:
		return
	_served[god.id] = get_level(god.id) + 1
	RunManager.served_gods = _served.keys()
	EventBus.god_served.emit(god)
