extends Node

## 무보(대시)와 작두 3연타를 헤드리스로 확인하는 스모크 테스트.
## 실행: godot --headless --path . res://tests/smoke_dash_combo.tscn
##
## 그림은 확인할 수 없으므로 **상태가 실제로 바뀌는지**만 본다 — 눌렀는데 아무 일도
## 일어나지 않는 종류의 회귀가 가장 조용히 지나가기 때문이다.
##
## `--script` 가 아니라 씬으로 도는 이유: `--script` 모드는 autoload 를 등록하지 않아
## AudioManager 를 참조하는 무기 스크립트가 컴파일조차 되지 않는다. 그러면 테스트가
## 게임과 다른 것을 재게 된다. 실제 main.tscn 을 자식으로 띄워 배선을 그대로 쓴다.

const MAIN_SCENE: String = "res://scenes/main.tscn"
## 스폰이 돌아 적이 사거리에 들어오기까지 기다릴 상한.
const MAX_FRAMES: int = 3600

var _frame: int = 0
var _main: Node
var _player: CharacterBody2D
var _jakdu: JakduWeapon
var _dash_from: Vector2 = Vector2.ZERO
var _dash_frame: int = -1
var _seen_steps: Array[int] = []
var _last_step: int = -1
var _dash_ok: bool = false
var _done: bool = false
var _failures: int = 0


func _ready() -> void:
	# 몸주 선택이 트리를 멈춰 세우므로 테스트 노드만은 멈춤과 무관하게 돌아야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene := load(MAIN_SCENE) as PackedScene
	if scene == null:
		_fail("main.tscn 을 불러오지 못했다.")
		_finish()
		return
	_main = scene.instantiate()
	add_child(_main)


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1

	if get_tree().paused:
		_dismiss_dialog()
		return

	if _player == null:
		_player = _find_player()
		if _player == null:
			if _frame > 300:
				_fail("플레이어를 찾지 못했다.")
				_finish()
			return
		_jakdu = _player.get_node_or_null(^"JakduWeapon") as JakduWeapon
		if _jakdu == null:
			_fail("JakduWeapon 을 찾지 못했다.")
			_finish()
			return

	_tick_dash()
	_tick_chain()

	if _dash_ok and _seen_steps.size() >= 4:
		_finish()
		return
	if _frame > MAX_FRAMES:
		if not _dash_ok:
			_fail("무보를 시간 내에 확인하지 못했다.")
		if _seen_steps.size() < 4:
			_fail("작두가 %d 번밖에 휘둘러지지 않아 연타를 확인하지 못했다." % _seen_steps.size())
		_finish()


## 멈춰 세운 선택 화면(몸주·레벨업)을 첫 후보로 넘긴다. 사람 손 대신 버튼을 눌러 준다.
## 어느 화면인지 따지지 않는다 — 테스트가 보려는 것은 전투지 UI 가 아니다.
func _dismiss_dialog() -> void:
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
	if _frame > 600:
		_fail("멈춘 화면을 넘기지 못해 런이 진행되지 않는다.")
		_finish()


## 대시를 한 번 걸고, 10프레임 뒤 실제로 이동했는지 잰다.
func _tick_dash() -> void:
	if _dash_frame < 0:
		if not _player.call(&"_try_dash"):
			_fail("무보가 발동하지 않았다(쿨다운 초기값 확인).")
			_dash_frame = 0
			return
		_dash_from = _player.global_position
		_dash_frame = _frame
		return
	if _dash_ok or _dash_frame == 0 or _frame - _dash_frame != 10:
		return
	var moved: float = _dash_from.distance_to(_player.global_position)
	# 평상시 이동속도(120px/s)로 10프레임이면 20px 남짓이다. 그 두 배를 넘어야 무보다.
	if moved < 45.0:
		_fail("무보가 몸을 옮기지 못했다: %.1f px" % moved)
	else:
		_dash_ok = true
	if _player.call(&"_try_dash"):
		_fail("쿨다운 중인데 무보가 다시 나갔다.")


## 휘두를 때마다 연타 번호를 모은다. 1→2→0→1 로 돌아야 한다.
func _tick_chain() -> void:
	var step: int = _jakdu.get(&"_slash_step")
	var swinging: bool = _jakdu.get(&"_swing_visual_left") > 0.0
	if not swinging or step == _last_step:
		return
	_last_step = step
	_seen_steps.append(step)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _seen_steps.size() >= 4:
		var expected: Array[int] = [1, 2, 0, 1]
		var head: Array = _seen_steps.slice(0, 4)
		if head != expected:
			_fail("연타가 순환하지 않는다: %s" % [head])
	if _failures > 0:
		push_error("스모크 테스트 실패 %d 건" % _failures)
	else:
		print("스모크 통과 — 무보 이동 확인, 작두 연타 %s" % [_seen_steps])
	# 종료 시 찍히는 leak/resource 경고는 런 도중에 끊어서 나는 것이라 게임 쪽 문제가 아니다.
	# 판정은 종료 코드와 위 한 줄로 한다.
	get_tree().quit(1 if _failures > 0 else 0)


func _find_player() -> CharacterBody2D:
	var nodes := get_tree().get_nodes_in_group(&"player")
	return nodes[0] as CharacterBody2D if not nodes.is_empty() else null


func _fail(message: String) -> void:
	_failures += 1
	push_error("  - " + message)
