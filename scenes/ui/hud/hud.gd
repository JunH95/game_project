extends CanvasLayer

## 최소 HUD. 남은 시간·레벨·XP·HP·처치 수를 텍스트로만 보여준다.
## 정식 HUD(체력바·아이콘·신 목록)는 M2에서. 지금은 진행 상황을 눈으로 확인할
## 수단이 없어 최소한만 둔다.

@export var level_system_path: NodePath
@export var gate_timer_path: NodePath

@onready var _label: Label = %StatusLabel

var _level_system: Node
var _gate_timer: Node
var _hp: float = 0.0
var _max_hp: float = 0.0


func _ready() -> void:
	if not level_system_path.is_empty():
		_level_system = get_node_or_null(level_system_path)
	if _level_system == null:
		push_error("HUD 에 LevelSystem 이 연결되지 않아 XP 를 표시할 수 없다.")
	if not gate_timer_path.is_empty():
		_gate_timer = get_node_or_null(gate_timer_path)
	if _gate_timer == null:
		push_error("HUD 에 GateTimer 가 연결되지 않아 남은 시간을 표시할 수 없다.")
	EventBus.player_health_changed.connect(_on_health_changed)


func _process(_delta: float) -> void:
	var level := RunManager.level
	var xp := 0
	var need := 0
	if _level_system != null:
		xp = _level_system.get_current_xp()
		need = _level_system.xp_to_next(level)
	var remaining := 0.0
	if _gate_timer != null:
		remaining = _gate_timer.get_remaining()
	_label.text = "남은 시간 %s    Lv %d    XP %d/%d    HP %d/%d    처치 %d" % [
		_format_time(remaining), level, xp, need, int(_hp), int(_max_hp), RunManager.kills
	]


func _format_time(seconds: float) -> String:
	var total := int(ceilf(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _on_health_changed(current: float, maximum: float) -> void:
	_hp = current
	_max_hp = maximum
