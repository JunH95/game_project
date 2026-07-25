extends Node

## 현재 런의 휘발 상태. 런 시작 시 초기화하고 종료 시 폐기한다(런 중간 세이브 없음).
## M0 스텁 — 타이머/레벨/모신 신/킬 진행 로직은 M1 이후에 채운다.

var elapsed_sec: float = 0.0
var level: int = 1
var kills: int = 0
var served_gods: Array = []


## 런 시작 시 호출. autoload 라 씬을 다시 열어도 값이 남으므로 명시적으로 비운다.
func reset_run() -> void:
	elapsed_sec = 0.0
	level = 1
	kills = 0
	served_gods.clear()
