extends Node

## 화면을 PNG 로 떨궈 주는 개발용 하네스. MCP 없이도 눈으로 확인하려고 둔다.
## 실행: godot --path . res://tests/capture_shot.tscn -- --out=<경로> --frames=<수> --zoom=<배율>
##
## 헤드리스로는 못 쓴다(3D 렌더가 없다). 창을 띄워 실제로 그린 뒤 그 프레임을 저장한다.

const MAIN_SCENE: String = "res://scenes/main.tscn"

var _main: Node
var _frame: int = 0
var _out_path: String = "user://shot.png"
var _wait_frames: int = 150
var _zoom: float = 0.0
var _shot_taken: bool = false
var _face_deg: float = 0.0
var _has_face: bool = false
var _force_2d: bool = false
var _hold_cards: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	var scene := load(MAIN_SCENE) as PackedScene
	if scene == null:
		push_error("capture: main.tscn 을 불러오지 못했다.")
		get_tree().quit(1)
		return
	_main = scene.instantiate()
	add_child(_main)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames="):
			_wait_frames = maxi(30, arg.trim_prefix("--frames=").to_int())
		elif arg.begins_with("--zoom="):
			_zoom = arg.trim_prefix("--zoom=").to_float()
		elif arg == "--holdcards":
			_hold_cards = true
		elif arg == "--visual2d":
			_force_2d = true
		elif arg.begins_with("--face="):
			_face_deg = arg.trim_prefix("--face=").to_float()
			_has_face = true


func _process(_delta: float) -> void:
	if _shot_taken:
		return
	_frame += 1
	if get_tree().paused:
		_dismiss_dialog()
		if not (_hold_cards and _frame >= _wait_frames):
			return
		_shot_taken = true
		_capture.call_deferred()
		return
	if _force_2d:
		_force_2d = false
		_swap_to_2d()
	if _zoom > 0.0:
		_force_zoom()
	if _has_face:
		_force_facing()
	if _frame < _wait_frames:
		return
	_shot_taken = true
	_capture.call_deferred()


## 확대해서 봐야 캐릭터 디테일이 판단된다. 게임 설정은 건드리지 않고 이 실행에서만 바꾼다.
func _force_zoom() -> void:
	var nodes := get_tree().get_nodes_in_group(&"player")
	if nodes.is_empty():
		return
	var camera := (nodes[0] as Node).get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		camera.zoom = Vector2(_zoom, _zoom)


## 2D 도형 몸으로 되돌린다. 같은 조건에서 나란히 찍어야 무엇이 나아졌는지 판단할 수 있다.
func _swap_to_2d() -> void:
	var nodes := get_tree().get_nodes_in_group(&"player")
	if nodes.is_empty():
		return
	var player := nodes[0] as Node
	player.set(&"use_3d_visual", false)
	player.call(&"_select_visual")
	var cloth := player.get_node_or_null(^"%ClothBody") as Node2D
	if cloth != null:
		cloth.visible = true


## 어느 쪽을 보게 할지 강제한다. 가만히 서 있으면 플레이어가 방향을 갱신하지 않으므로
## 한 번 넣어 두면 그대로 남는다 — 얼굴을 보려면 이게 필요하다.
func _force_facing() -> void:
	var nodes := get_tree().get_nodes_in_group(&"player")
	if nodes.is_empty():
		return
	(nodes[0] as Node).set(&"_facing", deg_to_rad(_face_deg))


## 신내림 카드가 실제로 떠 있는지. `_pending` 은 아직 고르지 않은 레벨업 횟수다.
func _is_god_select_open() -> bool:
	var dialog := _main.find_child("GodSelect", true, false)
	if dialog == null:
		return false
	var pending: Variant = dialog.get(&"_pending")
	return pending != null and int(pending) > 0


func _dismiss_dialog() -> void:
	# --holdcards 면 신내림 카드는 닫지 않고 띄워 둔다(대가 표시를 눈으로 확인하려는 것).
	# 몸주 선택은 그래도 넘긴다 — 그게 안 닫히면 게임이 시작조차 안 된다.
	if _hold_cards and _is_god_select_open():
		return
	for dialog_name in ["MomjuSelect", "GodSelect"]:
		var dialog := _main.find_child(dialog_name, true, false)
		if dialog == null:
			continue
		var choices := dialog.find_child("Choices", true, false)
		if choices == null or choices.get_child_count() == 0:
			continue
		var button := choices.get_child(0) as Button
		if button != null:
			button.pressed.emit()
			return


func _capture() -> void:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_out_path)
	if err != OK:
		push_error("capture: PNG 저장 실패(%d) — %s" % [err, _out_path])
	else:
		print("capture: 저장 완료 — %s" % _out_path)
	get_tree().quit(0 if err == OK else 1)
