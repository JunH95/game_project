extends CanvasLayer

## 런 종료 화면. 관문 클리어와 사망 양쪽을 하나로 처리한다.
## 일시정지 중에 동작해야 하므로 씬에서 process_mode = ALWAYS 로 둔다.
##
## 원혼 정산과 신당 복귀는 M4(메타 루프). 지금은 결과 표시와 재시작만 한다.

@onready var _title: Label = %TitleLabel
@onready var _stats: Label = %StatsLabel
@onready var _panel: Control = %Panel


func _ready() -> void:
	_panel.hide()
	EventBus.gate_cleared.connect(_on_gate_cleared)
	EventBus.player_died.connect(_on_player_died)


func _on_gate_cleared(_gate_id: StringName) -> void:
	_show("관문을 넘었다", Color(0.88, 0.78, 0.45))


func _on_player_died() -> void:
	_show("넋이 흩어졌다", Color(0.85, 0.25, 0.20))


func _show(title: String, color: Color) -> void:
	if _panel.visible:
		return
	_title.text = title
	_title.add_theme_color_override(&"font_color", color)
	_stats.text = "버틴 시간 %s    처치 %d    레벨 %d" % [
		_format_time(RunManager.elapsed_sec), RunManager.kills, RunManager.level
	]
	_panel.show()
	get_tree().paused = true


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_restart()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
