extends CanvasLayer

## 일시정지. Esc(pause 액션)로 열고 닫는다.
## 레벨업 선택이나 런 결과가 떠 있는 동안에는 열리면 안 된다 — 그쪽이 이미 트리를
## 멈춰 두었는데 여기서 해제하면 선택 화면 뒤로 게임이 흘러간다.

@onready var _panel: Control = %Panel

var _open: bool = false


func _ready() -> void:
	_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	# 다른 화면이 멈춰 둔 상태면 건드리지 않는다.
	if not _open and get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	_toggle()


func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	get_tree().paused = _open
