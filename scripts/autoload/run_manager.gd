extends Node

## 현재 런의 휘발 상태. 런 시작 시 초기화하고 종료 시 폐기한다(런 중간 세이브 없음).
## 경과 시간은 GateTimer, 레벨은 LevelSystem, 모신 신은 GodSystem 이 갱신하고
## 여기서는 보유만 한다. 처치 수만 이 노드가 직접 센다(런 전역 통계라 소유자가 없음).

var elapsed_sec: float = 0.0
## 이번 관문의 길이(초). GateTimer 가 채운다. 적 난이도 스케일링이 진행도를 재는 기준이라
## 여기 두어야 적이 타이머 노드를 직접 찾지 않는다.
var gate_duration_sec: float = 300.0
var level: int = 1
var kills: int = 0
var served_gods: Array = []
## 이번 런의 몸주 id. 런 시작 화면에서 정해진다(design.md 3-1).
var momju_id: StringName = &""
## 인간성을 몇 번 내줬는지(design.md 3-7). **결말이 이걸 본다**(5-0) —
## 다른 대가는 이 런 안에서 끝나지만 이것만 끝에서 청구된다. 그래서 런 상태로 들고 있다.
var humanity_paid: int = 0


func _ready() -> void:
	# 처치 수는 런 전역 통계라 특정 씬이 아니라 여기서 센다.
	EventBus.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: Node2D, _world_position: Vector2) -> void:
	kills += 1


## 런 시작 시 호출. autoload 라 씬을 다시 열어도 값이 남으므로 명시적으로 비운다.
func reset_run() -> void:
	elapsed_sec = 0.0
	gate_duration_sec = 300.0
	level = 1
	kills = 0
	served_gods.clear()
	momju_id = &""
	humanity_paid = 0
