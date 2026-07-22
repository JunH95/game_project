extends CharacterBody2D

## 공용 적. EnemyData 리소스로 스탯·외형을 구성한다(data-driven).
## M1 슬라이스: 플레이어를 추격하고 접촉 데미지를 준다. 처치 시 enemy_died 를 emit.
## 플레이스홀더 외형 = 빨강 원(_draw).

@export var data: EnemyData

var _target: Node2D

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


func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_movement.move(Vector2.ZERO)
		return
	var direction := (_target.global_position - global_position).normalized()
	_movement.move(direction)


func _on_died() -> void:
	EventBus.enemy_died.emit(self, global_position)
	queue_free()


func _draw() -> void:
	var r := data.radius if data != null else 8.0
	draw_circle(Vector2.ZERO, r, Color(0.85, 0.16, 0.16))
