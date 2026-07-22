extends CharacterBody2D

## 플레이어. M1 슬라이스에서는 8방향 이동만 담당한다.
## 체력·피격(i-frame)·픽업 자석은 이후 조각에서 컴포넌트로 붙인다.
## 플레이스홀더 외형 = 흰 원(_draw). 아트 패스 때 Sprite2D 로 교체한다.

const RADIUS: float = 12.0

@onready var _movement: MovementComponent = %MovementComponent


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_movement.move(direction)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
