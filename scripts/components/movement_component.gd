class_name MovementComponent
extends Node

## CharacterBody2D 를 정규화된 방향으로 이동시키는 재사용 컴포넌트.
## 플레이어는 입력 방향을, 적은 추격 방향을 매 물리 프레임 넘겨준다.

@export var speed: float = 120.0

## 바깥에서 거는 속도 배율(결박 같은 상태이상). speed 를 직접 깎으면 신 수정자 계산과 섞여
## 상태가 풀릴 때 원래 값을 복원하지 못한다. 채널을 나눠 둔다.
var external_multiplier: float = 1.0

var _body: CharacterBody2D


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("MovementComponent 는 CharacterBody2D 의 자식이어야 한다.")


## direction 은 정규화된 방향 벡터(0 이면 정지). 매 _physics_process 에서 호출.
func move(direction: Vector2) -> void:
	if _body == null:
		return
	_body.velocity = direction * speed * external_multiplier
	_body.move_and_slide()
