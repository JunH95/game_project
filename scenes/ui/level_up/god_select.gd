extends CanvasLayer

## 신내림 3택1. 레벨업 때 게임을 멈추고 모실 신을 고르게 한다.
## 이 게임의 핵심 차별점이라 레벨업의 보상은 자동 강화가 아니라 언제나 "선택"이다.

@export var god_system_path: NodePath

## 대가 이름표(design.md 3-7-2). 여기 없는 키는 데이터 쪽 오타다.
const PRICE_LABELS: Dictionary = {
	&"lifespan": "수명",
	&"flesh": "살",
	&"soul": "넋",
	&"humanity": "인간성",
	&"memory": "기억",
}

## 값을 부르는 신은 붉은 테를 두른다(design.md 3-7-1). 색만 바꾸면 글자에 묻혀
## 급하게 고를 때 안 보인다 — 테두리라야 카드 단위로 눈에 들어온다.
const PRICE_BORDER: Color = Color(0.78, 0.24, 0.20)

@onready var _panel: Control = %Panel
@onready var _buttons: VBoxContainer = %Choices

var _god_system: Node
## 한 번에 여러 레벨이 오를 수 있어 밀린 횟수를 세어 두고 하나씩 처리한다.
var _pending: int = 0


func _ready() -> void:
	if not god_system_path.is_empty():
		_god_system = get_node_or_null(god_system_path)
	if _god_system == null:
		push_error("GodSelect 에 GodSystem 이 연결되지 않아 신을 제시할 수 없다.")
		return
	_panel.hide()
	EventBus.player_leveled_up.connect(_on_leveled_up)


func _on_leveled_up(_new_level: int) -> void:
	_pending += 1
	if not _panel.visible:
		_show_next()


func _show_next() -> void:
	var choices: Array = _god_system.roll_choices()
	if choices.is_empty():
		# 전부 만렙이면 멈춰 세울 이유가 없다.
		_pending = 0
		_resume()
		return

	for child in _buttons.get_children():
		child.queue_free()

	for god: GodData in choices:
		var button := Button.new()
		var level: int = _god_system.get_level(god.id)
		var prefix := "새로 모심" if level == 0 else "Lv %d -> %d" % [level, level + 1]
		var head := "%s  (%s)" % [god.display_name, prefix]
		# 대가는 **고르기 전에** 보여야 한다. 고르고 나서 알게 되면 그건 선택이 아니라 함정이다.
		if god.price_kind != &"":
			head += "   ▲ 대가 · %s" % PRICE_LABELS.get(god.price_kind, "알 수 없음")
			_mark_priced(button)
		button.text = "%s\n%s" % [head, god.description]
		button.custom_minimum_size = Vector2(560, 76)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# 신 일러스트가 들어오면 GodData.icon 만 물리면 여기 뜬다. 없으면 글자만 나온다.
		if god.icon != null:
			button.icon = god.icon
			button.expand_icon = true
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_choice_pressed.bind(god))
		_buttons.add_child(button)

	_panel.show()
	get_tree().paused = true
	# 일시정지 중에는 마우스보다 키보드/패드가 자연스러워 첫 항목에 포커스를 준다.
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()


## 붉은 테. 버튼의 네 가지 상태 전부에 씌우지 않으면 마우스를 올리는 순간 테가 사라진다.
func _mark_priced(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.07, 0.08, 0.92 if state == "normal" else 1.0)
		style.set_border_width_all(2 if state == "normal" else 3)
		style.border_color = PRICE_BORDER
		style.set_corner_radius_all(4)
		style.set_content_margin_all(10.0)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(0.95, 0.86, 0.84))


func _on_choice_pressed(god: GodData) -> void:
	_god_system.serve(god)
	_pending = maxi(0, _pending - 1)
	if _pending > 0:
		_show_next()
	else:
		_panel.hide()
		_resume()


func _resume() -> void:
	get_tree().paused = false
