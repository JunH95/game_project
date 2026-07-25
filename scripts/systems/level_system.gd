extends Node

## XP 누적과 레벨업. 곡선은 design.md 1절: xp_to_next(level) = 5 + (level - 1) * 4.
## 레벨은 런 상태이므로 RunManager 가 보유하고, 이 노드는 계산만 한다.

var _xp: int = 0


func _ready() -> void:
	# autoload 인 RunManager 는 씬 리로드에도 살아남으므로 런 시작마다 명시적으로 초기화한다.
	RunManager.reset_run()
	_xp = 0
	EventBus.xp_collected.connect(_on_xp_collected)


func _on_xp_collected(amount: int) -> void:
	_xp += amount
	# 한 번에 여러 레벨이 오를 수 있어 while 로 돈다.
	while _xp >= xp_to_next(RunManager.level):
		_xp -= xp_to_next(RunManager.level)
		RunManager.level += 1
		EventBus.player_leveled_up.emit(RunManager.level)


## 현재 레벨에서 다음 레벨까지 필요한 XP.
static func xp_to_next(level: int) -> int:
	return 5 + (level - 1) * 4


## HUD 표시용. 현재 레벨 구간에서 모은 XP.
func get_current_xp() -> int:
	return _xp
