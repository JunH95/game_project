extends Area2D

## XP 젬. 적이 죽은 자리에 떨어지고, 픽업 자석에 걸리면 플레이어에게 끌려가 수집된다.
## 외형은 PlaceholderArt 의 넋 조각. texture 를 물리면 그쪽이 우선한다.

@export var value: int = 1
## 정식 아트가 들어오면 여기에 물리고, 도형 실루엣은 자동으로 비켜난다.
@export var texture: Texture2D

const RADIUS: float = 4.0
const TINT: Color = Color(0.2, 0.9, 0.9)
## 제자리 회전 속도(라디안/초). 가만히 있는 젬이 눈에 띄어야 주우러 간다.
const SPIN_SPEED: float = 3.4
## 자석에 걸린 뒤 끌려가는 속도(px/s).
const ATTRACT_SPEED: float = 420.0
## 이 거리 안에 들어오면 수집으로 친다.
const COLLECT_DIST: float = 8.0

var _target: Node2D
## 개체마다 다른 위상. 같으면 바닥의 젬이 전부 한 박자로 번쩍여 눈이 아프다.
var _spin: float = 0.0


## 픽업 자석이 호출한다. 이후 플레이어를 향해 끌려간다.
func attract_to(target: Node2D) -> void:
	_target = target


## 풀에서 꺼내질 때. value 와 위치는 호출자가 넣어 준다.
func _pool_reset() -> void:
	_target = null
	_spin = randf() * TAU
	scale = Vector2.ONE
	collision_layer = 128
	set_deferred(&"monitorable", true)
	add_to_group(&"pickup")


## 풀에 반납될 때. 자석이 이미 수집한 젬을 다시 끌어당기지 않게 한다.
func _pool_exit() -> void:
	_target = null
	remove_from_group(&"pickup")
	collision_layer = 0
	set_deferred(&"monitorable", false)


func _process(delta: float) -> void:
	# 회전은 폭만 줄였다 늘렸다 하는 것으로 낸다. transform 이라 다시 그리지 않아도 되고,
	# 실제로 rotation 을 돌리면 마름모라 얇아지는 순간이 없어 회전으로 안 읽힌다.
	_spin += SPIN_SPEED * delta
	scale.x = 0.3 + 0.7 * absf(cos(_spin))

	if _target == null or not is_instance_valid(_target):
		return
	var offset := _target.global_position - global_position
	if offset.length() <= COLLECT_DIST:
		EventBus.xp_collected.emit(value)
		ObjectPool.release(self)
		return
	global_position += offset.normalized() * ATTRACT_SPEED * delta


func _draw() -> void:
	if PlaceholderArt.draw_texture_centered(self, texture, RADIUS * 3.0):
		return
	PlaceholderArt.draw_soul_gem(self, RADIUS, TINT)
