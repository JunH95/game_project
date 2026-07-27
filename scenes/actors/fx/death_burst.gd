extends Node2D

## 적이 흩어지는 순간의 파편. 넋이 풀리는 그림이라 원색이 아니라 적의 색을 그대로 쓴다.
## 수백 번 터지므로 풀링 대상이고, 파티클 노드 대신 직접 그린다(노드 수를 늘리지 않기 위해).

const LIFETIME: float = 0.35
const SHARD_COUNT: int = 7
const SPEED_MIN: float = 90.0
const SPEED_MAX: float = 220.0
## 퍼진 파편이 느려지는 정도. 1에 가까울수록 오래 미끄러진다.
const DRAG: float = 0.86

var _life_left: float = 0.0
var _color: Color = Color(0.85, 0.16, 0.16)
var _offsets: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _radius: float = 3.0


## 스포너가 풀에서 꺼낸 직후 호출한다.
func setup(color: Color, size: float) -> void:
	_color = color
	_radius = clampf(size * 0.35, 2.0, 6.0)
	_life_left = LIFETIME
	_offsets.clear()
	_velocities.clear()
	var base := randf() * TAU
	for i in SHARD_COUNT:
		# 고르게 퍼지되 완전히 규칙적이지 않게 — 정확한 방사형은 인위적으로 보인다.
		var angle := base + TAU * float(i) / float(SHARD_COUNT) + randf_range(-0.35, 0.35)
		_offsets.append(Vector2.ZERO)
		_velocities.append(Vector2.from_angle(angle) * randf_range(SPEED_MIN, SPEED_MAX))
	queue_redraw()


func _pool_reset() -> void:
	_life_left = 0.0


func _process(delta: float) -> void:
	if _life_left <= 0.0:
		return
	_life_left -= delta
	if _life_left <= 0.0:
		ObjectPool.release(self)
		return
	var damp := pow(DRAG, delta * 60.0)
	for i in _offsets.size():
		_velocities[i] *= damp
		_offsets[i] += _velocities[i] * delta
	queue_redraw()


func _draw() -> void:
	if _life_left <= 0.0:
		return
	var t := _life_left / LIFETIME
	var color := Color(_color.r, _color.g, _color.b, t)
	for i in _offsets.size():
		draw_circle(_offsets[i], _radius * t, color)
