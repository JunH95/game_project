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
@onready var _synergy_label: Label = %SynergyLabel

var _level_system: Node
var _gate_timer: Node
var _god_system: Node
var _hp: float = 0.0
var _max_hp: float = 0.0
var _synergy_name: String = ""
var _jakdu: Node


func _ready() -> void:
	_level_system = _resolve(level_system_path, "LevelSystem")
	_gate_timer = _resolve(gate_timer_path, "GateTimer")
	_god_system = _resolve(god_system_path, "GodSystem")
	EventBus.player_health_changed.connect(_on_health_changed)
	# player_leveled_up 은 신을 고르기 "전"에 오므로 목록이 한 픽씩 밀린다. 실제로 모신 순간을 본다.
	EventBus.god_served.connect(_on_god_served)
	EventBus.synergy_formed.connect(_on_synergy_formed)
	_synergy_label.hide()


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
	_update_synergy_label()


## 신 목록은 신을 모실 때만 바뀌므로 매 프레임 다시 만들지 않는다.
func _on_god_served(_god: GodData) -> void:
	_refresh_gods()


## 합이 열리는 순간은 이 게임에서 가장 기분 좋은 지점이다. 조용히 지나가면 안 된다.
func _on_synergy_formed(synergy: SynergyData) -> void:
	_synergy_name = synergy.display_name
	_synergy_label.show()


## 작두타기 게이지. 언제 터지는지 보이지 않으면 기다릴 수가 없다.
## 플레이어 내부 노드를 직접 읽는 대신 그룹으로 한 번만 찾아 둔다.
func _resolve_jakdu() -> Node:
	if _jakdu != null and is_instance_valid(_jakdu):
		return _jakdu
	var player := get_tree().get_first_node_in_group(&"player")
	_jakdu = player.get_node_or_null(^"%JakduWeapon") if player != null else null
	return _jakdu


func _update_synergy_label() -> void:
	if not _synergy_label.visible:
		return
	var jakdu := _resolve_jakdu()
	if jakdu == null or not jakdu.has_method(&"get_taegi_ratio") or not jakdu.is_taegi_unlocked():
		_synergy_label.text = "합 — %s" % _synergy_name
		return
	var ratio: float = jakdu.get_taegi_ratio()
	if jakdu.is_taegi_active():
		_synergy_label.text = "합 — %s   작두타기! %d%%" % [_synergy_name, int(ratio * 100.0)]
		_synergy_label.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.4))
	else:
		_synergy_label.text = "합 — %s   기세 %d%%" % [_synergy_name, int(ratio * 100.0)]
		_synergy_label.add_theme_color_override(&"font_color", Color(0.72, 0.64, 0.42))


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
