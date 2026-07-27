extends CanvasLayer

## 인런 HUD. 남은 시간·체력·XP·레벨·처치 수와, 지금 모신 신과 실린 기운을 보여준다.
## 오행은 눈에 보이지 않으면 상성이 있는 줄도 모른다(design.md 3-3) — 그래서 상시 표시한다.
## 아이콘·초상 등 정식 아트는 M6 아트 패스에서. 여기까지는 텍스트와 막대뿐이다.

@export var level_system_path: NodePath
@export var gate_timer_path: NodePath
@export var god_system_path: NodePath

## 오행 표기와 색(design.md 9절 팔레트 계열).
const ELEMENT_NAMES: Dictionary = {
	&"metal": "金", &"wood": "木", &"water": "水", &"fire": "火", &"earth": "土"
}
const ELEMENT_COLORS: Dictionary = {
	&"metal": Color(0.85, 0.86, 0.9),
	&"wood": Color(0.45, 0.75, 0.45),
	&"water": Color(0.42, 0.66, 0.88),
	&"fire": Color(0.95, 0.45, 0.28),
	&"earth": Color(0.83, 0.68, 0.38),
}

@onready var _time_label: Label = %TimeLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _status_label: Label = %StatusLabel
@onready var _gods_label: Label = %GodsLabel

var _level_system: Node
var _gate_timer: Node
var _god_system: Node
var _hp: float = 0.0
var _max_hp: float = 0.0


func _ready() -> void:
	_level_system = _resolve(level_system_path, "LevelSystem")
	_gate_timer = _resolve(gate_timer_path, "GateTimer")
	_god_system = _resolve(god_system_path, "GodSystem")
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_leveled_up.connect(_on_leveled_up)


func _resolve(path: NodePath, label: String) -> Node:
	var node: Node = get_node_or_null(path) if not path.is_empty() else null
	if node == null:
		push_error("HUD 에 %s 가 연결되지 않았다." % label)
	return node


func _process(_delta: float) -> void:
	if _gate_timer != null:
		_time_label.text = _format_time(_gate_timer.get_remaining())

	var level := RunManager.level
	var need := 1
	var xp := 0
	if _level_system != null:
		xp = _level_system.get_current_xp()
		need = maxi(1, _level_system.xp_to_next(level))
	_xp_bar.max_value = need
	_xp_bar.value = xp

	_hp_bar.max_value = maxf(1.0, _max_hp)
	_hp_bar.value = _hp
	_status_label.text = "Lv %d    HP %d/%d    처치 %d" % [
		level, int(ceilf(_hp)), int(_max_hp), RunManager.kills
	]


## 신 목록은 레벨업 때만 바뀌므로 매 프레임 다시 만들지 않는다.
func _on_leveled_up(_new_level: int) -> void:
	_refresh_gods.call_deferred()


func _refresh_gods() -> void:
	if _god_system == null:
		return
	var served: Dictionary = _god_system.get_served()
	if served.is_empty():
		_gods_label.text = "모신 신 없음"
		return

	var parts: PackedStringArray = []
	for god in _god_system.available_gods:
		if god == null or not served.has(god.id):
			continue
		parts.append("%s %s·%d" % [
			ELEMENT_NAMES.get(god.element, "?"), god.display_name, int(served[god.id])
		])

	var element: StringName = _god_system.get_element()
	var flow := "기운 %s" % ELEMENT_NAMES.get(element, "—")
	_gods_label.text = "%s    |    %s" % [flow, "  ".join(parts)]
	_gods_label.add_theme_color_override(
		&"font_color", ELEMENT_COLORS.get(element, Color(0.61, 0.58, 0.518))
	)


func _format_time(seconds: float) -> String:
	var total := int(ceilf(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _on_health_changed(current: float, maximum: float) -> void:
	_hp = current
	_max_hp = maximum
