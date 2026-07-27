extends CanvasLayer

## 몸주 선택. 런이 시작되기 전에 게임을 멈추고 모실 주신을 고르게 한다(design.md 3-1-2).
## 몸주가 시작 무기를 정하므로 런의 성격이 여기서 갈린다 — 그래서 오행·무기·패시브를 같이 보여 준다.
##
## `[고증]` 원래 몸주는 고르는 것이 아니라 내려온다. 첫 플레이 프롤로그(내림굿)와
## 신당 해금은 세이브가 필요해 M4 에서 붙인다. 지금은 후보 전체를 제시한다.

@export var god_system_path: NodePath

const ELEMENT_NAMES: Dictionary = {
	&"metal": "金", &"wood": "木", &"water": "水", &"fire": "火", &"earth": "土"
}
const WEAPON_NAMES: Dictionary = {
	&"jakdu": "작두 — 부채꼴 즉발",
	&"bujeok": "부적 — 유도 투사체",
	&"eonwoldo": "언월도 — 궤도 회전",
}

@onready var _panel: Control = %Panel
@onready var _buttons: VBoxContainer = %Choices

var _god_system: Node


func _ready() -> void:
	if not god_system_path.is_empty():
		_god_system = get_node_or_null(god_system_path)
	if _god_system == null:
		push_error("MomjuSelect 에 GodSystem 이 연결되지 않아 몸주를 제시할 수 없다.")
		_panel.hide()
		return
	# 다른 노드들이 _ready 를 마친 뒤 멈춰야 초기화가 끝난 상태로 대기한다.
	_show.call_deferred()


func _show() -> void:
	var candidates: Array = _god_system.get_momju_candidates()
	if candidates.is_empty():
		push_error("몸주 후보가 없다. GodData.is_momju 를 확인할 것.")
		_panel.hide()
		return

	for child in _buttons.get_children():
		child.queue_free()

	for god: GodData in candidates:
		var button := Button.new()
		button.text = "%s  %s\n%s\n%s" % [
			ELEMENT_NAMES.get(god.element, "?"),
			god.display_name,
			WEAPON_NAMES.get(god.momju_weapon, str(god.momju_weapon)),
			_passive_text(god),
		]
		button.custom_minimum_size = Vector2(560, 96)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# 몸주 일러스트가 들어오면 GodData.icon 만 물리면 여기 뜬다. 없으면 글자만 나온다.
		if god.icon != null:
			button.icon = god.icon
			button.expand_icon = true
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_choice_pressed.bind(god))
		_buttons.add_child(button)

	_panel.show()
	get_tree().paused = true
	(_buttons.get_child(0) as Button).grab_focus()


## 몸주 패시브를 사람이 읽을 문장으로. 수치는 데이터에 있으므로 여기서 조립한다.
func _passive_text(god: GodData) -> String:
	if god.momju_stat_mods.is_empty():
		return god.description
	var parts: PackedStringArray = []
	for key in god.momju_stat_mods:
		var value: float = float(god.momju_stat_mods[key])
		match key:
			&"jakdu_damage_pct":
				parts.append("작두 위력 +%d%%" % int(value))
			&"bujeok_count":
				parts.append("부적 발수 +%d" % int(value))
			&"eonwoldo_count":
				parts.append("언월도 날 +%d" % int(value))
			_:
				parts.append("%s %+.0f" % [key, value])
	return "몸주 패시브: " + " · ".join(parts)


func _on_choice_pressed(god: GodData) -> void:
	_god_system.set_momju(god)
	_panel.hide()
	get_tree().paused = false
