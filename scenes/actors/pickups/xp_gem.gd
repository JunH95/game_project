extends Area2D

## XP 젬. 적이 죽은 자리에 떨어지고, 픽업 자석에 걸리면 플레이어에게 끌려가 수집된다.
## 플레이스홀더 외형 = 청록 다이아(design.md 9절).

@export var value: int = 1

const RADIUS: float = 4.0
## 자석에 걸린 뒤 끌려가는 속도(px/s).
const ATTRACT_SPEED: float = 420.0
## 이 거리 안에 들어오면 수집으로 친다.
const COLLECT_DIST: float = 8.0

var _target: Node2D


## 픽업 자석이 호출한다. 이후 플레이어를 향해 끌려간다.
func attract_to(target: Node2D) -> void:
	_target = target


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var offset := _target.global_position - global_position
	if offset.length() <= COLLECT_DIST:
		EventBus.xp_collected.emit(value)
		queue_free()
		return
	global_position += offset.normalized() * ATTRACT_SPEED * delta


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -RADIUS), Vector2(RADIUS, 0.0), Vector2(0.0, RADIUS), Vector2(-RADIUS, 0.0)
	])
	draw_colored_polygon(points, Color(0.2, 0.9, 0.9))
