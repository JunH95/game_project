extends CanvasLayer

## 최소 HUD. 레벨·XP·HP를 텍스트로만 보여준다.
## 정식 HUD(체력바·타이머·킬 카운트)는 M2에서. 지금은 레벨업이 실제로 일어나는지
## 눈으로 확인할 수단이 없어 최소한만 둔다.

@export var level_system_path: NodePath

@onready var _label: Label = %StatusLabel

var _level_system: Node
var _hp: float = 0.0
var _max_hp: float = 0.0


func _ready() -> void:
	if not level_system_path.is_empty():
		_level_system = get_node_or_null(level_system_path)
	if _level_system == null:
		push_error("HUD 에 LevelSystem 이 연결되지 않아 XP 를 표시할 수 없다.")
	EventBus.player_health_changed.connect(_on_health_changed)


func _process(_delta: float) -> void:
	var level := RunManager.level
	var xp := 0
	var need := 0
	if _level_system != null:
		xp = _level_system.get_current_xp()
		need = _level_system.xp_to_next(level)
	_label.text = "Lv %d    XP %d/%d    HP %d/%d" % [level, xp, need, int(_hp), int(_max_hp)]


func _on_health_changed(current: float, maximum: float) -> void:
	_hp = current
	_max_hp = maximum
