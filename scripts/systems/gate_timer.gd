extends Node

## 관문 타이머. 5분을 버티면 관문 클리어(design.md 5절).
## 레벨업 UI 가 트리를 일시정지하면 이 노드도 함께 멈춘다(process_mode 기본 상속) —
## 선택 화면에서 시간이 흐르면 안 되므로 의도한 동작이다.
##
## 3:00 저승사자 미니보스와 관문별 데이터(GateData)는 M5 에서 이 위에 얹는다.

## 관문 길이(초). 스폰 램프(spawn_director.ramp_duration)와 맞춘다.
@export var duration_sec: float = 300.0
@export var gate_id: StringName = &"hwatang"

var _finished: bool = false


func _ready() -> void:
	RunManager.elapsed_sec = 0.0


func _process(delta: float) -> void:
	if _finished:
		return
	RunManager.elapsed_sec += delta
	if RunManager.elapsed_sec >= duration_sec:
		RunManager.elapsed_sec = duration_sec
		_finished = true
		EventBus.gate_cleared.emit(gate_id)


## 남은 시간(초). HUD 표시용.
func get_remaining() -> float:
	return maxf(0.0, duration_sec - RunManager.elapsed_sec)
