extends Node

## 타격감을 만드는 두 가지 — 히트스톱과 스크린셰이크(design.md 9절·M6).
## 타격감은 그림이 아니라 코드·수치로 만든다는 것이 이 프로젝트의 전제라, 아트보다 먼저 넣는다.
##
## 요청은 항상 "더 센 것이 이긴다". 약한 히트스톱이 강한 것을 덮어쓰면 큰 순간이 작아진다.

## 히트스톱 중 시간 배율. 0 으로 완전히 멈추면 입력까지 씹혀 답답하다.
const HITSTOP_SCALE: float = 0.05
## 한 번에 허용하는 최대 정지 시간. 실수로 길게 넣어도 게임이 멈춘 것처럼 보이지 않게.
const MAX_HITSTOP: float = 0.25

var _hitstop_left: float = 0.0
var _shake_left: float = 0.0
var _shake_total: float = 0.0
var _shake_strength: float = 0.0
var _camera: Camera2D


func _ready() -> void:
	# 시간이 느려진 동안에도 스스로는 실시간으로 돌아야 복구 시점을 셀 수 있다.
	process_mode = Node.PROCESS_MODE_ALWAYS


## 잠깐 시간을 늦춰 타격을 "씹히게" 한다. duration 은 실시간 기준.
func hitstop(duration: float) -> void:
	_hitstop_left = maxf(_hitstop_left, minf(duration, MAX_HITSTOP))
	Engine.time_scale = HITSTOP_SCALE


func shake(strength: float, duration: float) -> void:
	if strength <= _shake_strength and _shake_left > 0.0:
		return
	_shake_strength = strength
	_shake_total = duration
	_shake_left = duration


func _process(delta: float) -> void:
	# Engine.time_scale 이 delta 에도 걸리므로 실시간 값으로 되돌려 센다.
	var real_delta := delta / maxf(0.001, Engine.time_scale)

	if _hitstop_left > 0.0:
		_hitstop_left -= real_delta
		if _hitstop_left <= 0.0:
			Engine.time_scale = 1.0

	_update_shake(real_delta)


func _update_shake(real_delta: float) -> void:
	if _shake_left <= 0.0:
		return
	var camera := _resolve_camera()
	if camera == null:
		_shake_left = 0.0
		return

	_shake_left -= real_delta
	if _shake_left <= 0.0:
		camera.offset = Vector2.ZERO
		_shake_strength = 0.0
		return
	# 남은 시간에 비례해 잦아든다. 일정 세기로 흔들면 끝이 뚝 끊겨 어색하다.
	var falloff := _shake_left / _shake_total
	var amount := _shake_strength * falloff * falloff
	camera.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


## 카메라는 플레이어에 붙어 있고 씬 리로드마다 새로 생긴다. 그때그때 찾는다.
func _resolve_camera() -> Camera2D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	var player := get_tree().get_first_node_in_group(&"player")
	_camera = player.get_node_or_null(^"Camera2D") as Camera2D if player != null else null
	return _camera


## 씬이 바뀌면 남아 있던 효과를 끊는다(관문 재시작 시 시간이 느린 채로 시작하는 사고 방지).
func reset() -> void:
	_hitstop_left = 0.0
	_shake_left = 0.0
	_shake_strength = 0.0
	_camera = null
	Engine.time_scale = 1.0
