extends Node

## 신 조합 "합"의 성립을 판정한다(design.md 3-5).
## 두 신을 동시에 모시면 열리고, 각 시스템은 `is_active(effect)`로 자기 몫만 물어본다 —
## 여기서 효과를 직접 실행하지 않는다(무기 로직이 이 노드로 새면 확장할 때마다 여기가 부푼다).

@export var god_system_path: NodePath
## 이 런에서 성립 가능한 합. 비워 두면 아래 기본 명단을 로드한다.
@export var available_synergies: Array[SynergyData] = []

const DEFAULT_SYNERGY_PATHS: PackedStringArray = [
	"res://data/synergies/janggun_gangrim.tres",
	"res://data/synergies/gwedo_jakdu.tres",
	"res://data/synergies/bukdu_bangbyeok.tres",
]

var _god_system: Node
## 이미 성립한 합의 effect 키. 한 번 열리면 런이 끝날 때까지 유지된다.
var _active: Dictionary = {}


func _ready() -> void:
	if not god_system_path.is_empty():
		_god_system = get_node_or_null(god_system_path)
	if _god_system == null:
		push_error("SynergySystem 에 GodSystem 이 연결되지 않아 합을 판정할 수 없다.")
		return
	if available_synergies.is_empty():
		_load_default_synergies()
	_active.clear()
	# player_leveled_up 은 신을 고르기 "전"에 온다. 실제로 모신 순간을 봐야 한다.
	EventBus.god_served.connect(_on_god_served)


func _load_default_synergies() -> void:
	for path in DEFAULT_SYNERGY_PATHS:
		var synergy := load(path) as SynergyData
		if synergy == null:
			push_error("합 데이터를 불러오지 못했다: %s" % path)
			continue
		available_synergies.append(synergy)


## 이 효과 훅이 열려 있는지. 무기·시스템이 이걸 보고 자기 기능을 켠다.
func is_active(effect: StringName) -> bool:
	return _active.has(effect)


## 모신 신이 바뀔 때마다 다시 판정한다.
func _on_god_served(_god: GodData) -> void:
	_evaluate()


func _evaluate() -> void:
	if _god_system == null:
		return
	for synergy in available_synergies:
		if synergy == null or _active.has(synergy.effect):
			continue
		if _god_system.get_level(synergy.god_a) > 0 and _god_system.get_level(synergy.god_b) > 0:
			_active[synergy.effect] = synergy
			EventBus.synergy_formed.emit(synergy)
