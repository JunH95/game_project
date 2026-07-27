extends CanvasLayer

## 신내림 3택1. 레벨업 때 게임을 멈추고 모실 신을 고르게 한다.
## 이 게임의 핵심 차별점이라 레벨업의 보상은 자동 강화가 아니라 언제나 "선택"이다.

@export var god_system_path: NodePath

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
		button.text = "%s  (%s)\n%s" % [god.display_name, prefix, god.description]
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
