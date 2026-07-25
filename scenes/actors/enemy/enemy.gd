extends CharacterBody2D

## 공용 적. EnemyData 리소스로 스탯·외형을 구성한다(data-driven).
## M1 슬라이스: 플레이어를 추격하고 접촉 데미지를 준다. 처치 시 enemy_died 를 emit.
## 플레이스홀더 외형 = 빨강 원(_draw).

@export var data: EnemyData

## 넉백 감쇠 계수. 클수록 빨리 멎는다(초당 감쇠율).
const KNOCKBACK_DECAY: float = 8.0

var _target: Node2D
var _knockback: Vector2 = Vector2.ZERO

@onready var _movement: MovementComponent = %MovementComponent
@onready var _health: HealthComponent = %HealthComponent
@onready var _hurtbox: HurtboxComponent = %HurtboxComponent
@onready var _hitbox: HitboxComponent = %HitboxComponent
@onready var _body_shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	if data != null:
		_movement.speed = data.move_speed
		_health.setup(data.max_hp)
		_hitbox.damage = data.contact_damage
		var circle := _body_shape.shape as CircleShape2D
		if circle != null:
			circle.radius = data.radius
	_hurtbox.health = _health
	_health.died.connect(_on_died)
	_target = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	# 넉백은 추격 속도와 별개로 감쇠하며 밀어낸다. 남아 있는 동안은 추격보다 우선.
	if not _knockback.is_zero_approx():
		_knockback = _knockback.lerp(Vector2.ZERO, minf(KNOCKBACK_DECAY * delta, 1.0))
		velocity = _knockback
		move_and_slide()
		return

	if _target == null or not is_instance_valid(_target):
		_movement.move(Vector2.ZERO)
		return
	var direction := (_target.global_position - global_position).normalized()
	_movement.move(direction)


## 무기가 호출한다. impulse 는 방향 × 세기(px/s).
func apply_knockback(impulse: Vector2) -> void:
	_knockback = impulse


func _on_died() -> void:
	EventBus.enemy_died.emit(self, global_position)
	queue_free()


func _draw() -> void:
	var r := data.radius if data != null else 8.0
	draw_circle(Vector2.ZERO, r, Color(0.85, 0.16, 0.16))
