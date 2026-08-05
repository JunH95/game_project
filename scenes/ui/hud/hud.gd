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

## 대가 표기. 순서를 고정해 둬야 낼 때마다 줄이 뒤섞이지 않는다.
const PRICE_ORDER: Array[StringName] = [
	&"lifespan", &"flesh", &"soul", &"memory", &"humanity"
]
const PRICE_NAMES: Dictionary = {
	&"lifespan": "수명", &"flesh": "살", &"soul": "넋",
	&"memory": "기억", &"humanity": "인간성",
}
const PRICE_COLOR: Color = Color(0.78, 0.24, 0.20)
const HUMANITY_COLOR: Color = Color(0.72, 0.55, 0.85)
## 타이머의 평상시 색. 수명을 내줄수록 여기서 붉은 쪽으로 간다.
const TIME_COLOR: Color = Color(0.878, 0.784, 0.451)

@onready var _time_label: Label = %TimeLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _status_label: Label = %StatusLabel
@onready var _gods_label: Label = %GodsLabel
@onready var _synergy_label: Label = %SynergyLabel
@onready var _price_label: Label = %PriceLabel

var _level_system: Node
var _gate_timer: Node
var _god_system: Node
var _hp: float = 0.0
var _max_hp: float = 0.0
var _synergy_names: PackedStringArray = []
var _jakdu: Node
## 무엇을 내줬는지의 기록. 총량만 보여 주면 "몇 번 냈다"가 되고, 종류가 남아야
## **어느 결말 쪽으로 가고 있는지**가 읽힌다(design.md 3-7-3).
var _price_counts: Dictionary = {}


func _ready() -> void:
	_level_system = _resolve(level_system_path, "LevelSystem")
	_gate_timer = _resolve(gate_timer_path, "GateTimer")
	_god_system = _resolve(god_system_path, "GodSystem")
	EventBus.player_health_changed.connect(_on_health_changed)
	# player_leveled_up 은 신을 고르기 "전"에 오므로 목록이 한 픽씩 밀린다. 실제로 모신 순간을 본다.
	EventBus.god_served.connect(_on_god_served)
	EventBus.synergy_formed.connect(_on_synergy_formed)
	EventBus.price_paid.connect(_on_price_paid)
	_synergy_label.hide()
	_price_label.hide()


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
	_synergy_names.append(synergy.display_name)
	_synergy_label.show()


## 치른 대가는 사라지지 않고 쌓여 보인다. 이 게임의 첫 문장이 화면에 남는 자리다.
func _on_price_paid(kind: StringName, _god: GodData, _detail: String) -> void:
	_price_counts[kind] = int(_price_counts.get(kind, 0)) + 1
	var parts: PackedStringArray = []
	for key: StringName in PRICE_ORDER:
		if not _price_counts.has(key):
			continue
		var count: int = _price_counts[key]
		parts.append(PRICE_NAMES[key] if count == 1 else "%s×%d" % [PRICE_NAMES[key], count])
	_price_label.text = "치른 대가 — " + " · ".join(parts)
	# 인간성만 색이 다르다. 다른 넷은 이 런 안에서 끝나지만 이건 결말을 바꾼다(5-0).
	_price_label.add_theme_color_override(&"font_color",
		HUMANITY_COLOR if _price_counts.has(&"humanity") else PRICE_COLOR)
	_price_label.show()
	# 수명을 내주면 타이머가 붉어진다. 숫자만 줄면 "덜 남았네"지만, 색이 변하면
	# **종착이 가까워졌다**가 된다 — 대가는 보이고 남아야 한다(3-7-3).
	var spent: int = int(_price_counts.get(&"lifespan", 0))
	if spent > 0:
		_time_label.add_theme_color_override(&"font_color",
			TIME_COLOR.lerp(PRICE_COLOR, minf(1.0, float(spent) * 0.34)))


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
	var text := "합 — " + " · ".join(_synergy_names)

	# 작두타기는 열려 있을 때만 기세를 덧붙인다. 언제 터지는지 보이지 않으면 기다릴 수가 없다.
	var jakdu := _resolve_jakdu()
	var color := Color(0.98, 0.82, 0.35)
	if jakdu != null and jakdu.has_method(&"get_taegi_ratio") and jakdu.is_taegi_unlocked():
		var ratio: float = jakdu.get_taegi_ratio()
		if jakdu.is_taegi_active():
			text += "    작두타기! %d%%" % int(ratio * 100.0)
			color = Color(1.0, 0.86, 0.4)
		elif jakdu.has_method(&"is_taegi_ready") and jakdu.is_taegi_ready():
			# 부를 수 있다는 사실과 **어느 키를 누르는지**가 같이 보여야 실제로 쓴다.
			text += "    강림 준비 — [Space]"
			color = Color(1.0, 0.95, 0.72)
		else:
			text += "    기세 %d%%" % int(ratio * 100.0)
			color = Color(0.72, 0.64, 0.42)
	_synergy_label.text = text
	_synergy_label.add_theme_color_override(&"font_color", color)


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
