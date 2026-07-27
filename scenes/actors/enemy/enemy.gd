extends CharacterBody2D

## 공용 적. EnemyData 리소스로 스탯·외형을 구성한다(data-driven).
## M1 슬라이스: 플레이어를 추격하고 접촉 데미지를 준다. 처치 시 enemy_died 를 emit.
## 플레이스홀더 외형 = 빨강 원(_draw).

@export var data: EnemyData

## 넉백 감쇠 계수. 클수록 빨리 멎는다(초당 감쇠율).
const KNOCKBACK_DECAY: float = 8.0

## 이웃을 밀어내는 반경. SeparationArea 의 CircleShape2D 반지름과 맞춘다.
const SEPARATION_RADIUS: float = 20.0
## 추격 방향 대비 분리 조향의 비중. 너무 크면 흩어져 플레이어에게 도달하지 못한다.
const SEPARATION_WEIGHT: float = 0.7
## 이웃이 많아도 분리력이 무한정 커지지 않게 막는 상한.
const SEPARATION_MAX: float = 1.5

var _target: Node2D
var _knockback: Vector2 = Vector2.ZERO

@onready var _movement: MovementComponent = %MovementComponent
@onready var _health: HealthComponent = %HealthComponent
@onready var _hurtbox: HurtboxComponent = %HurtboxComponent
@onready var _hitbox: HitboxComponent = %HitboxComponent
@onready var _body_shape: CollisionShape2D = %CollisionShape2D
@onready var _separation: Area2D = %SeparationArea


func _ready() -> void:
	_hurtbox.health = _health
	_health.died.connect(_on_died)
	# 씬의 CircleShape2D 는 인스턴스끼리 공유된다. 적마다 반지름이 다르므로 복제해서 쓴다.
	if _body_shape.shape != null:
		_body_shape.shape = _body_shape.shape.duplicate()
	_apply_data()


## 스폰 직후 스포너가 호출한다. 풀에서 꺼낸 개체는 이전 종류의 스탯을 들고 있으므로
## data 를 갈아끼운 뒤 반드시 다시 반영해야 한다.
func setup(new_data: EnemyData) -> void:
	data = new_data
	_apply_data()


## data 의 스탯·외형을 노드에 반영한다. 최초 _ready 와 풀 재사용 양쪽에서 부른다.
func _apply_data() -> void:
	if data == null:
		return
	_movement.speed = data.move_speed
	_health.setup(data.max_hp)
	_hitbox.damage = data.contact_damage
	var circle := _body_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = data.radius
	queue_redraw()


## 풀에서 꺼내질 때. 스폰 위치와 data 는 호출자가 먼저 넣어 준다.
func _pool_reset() -> void:
	_knockback = Vector2.ZERO
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	_apply_data()
	_target = get_tree().get_first_node_in_group("player")
	add_to_group(&"enemy")
	collision_layer = 4
	_hurtbox.set_deferred(&"monitoring", true)
	_hitbox.set_deferred(&"monitorable", true)
	_separation.set_deferred(&"monitoring", true)


## 풀에 반납될 때. 그룹에 남아 있으면 죽은 적이 무기 판정에 계속 잡힌다.
func _pool_exit() -> void:
	remove_from_group(&"enemy")
	collision_layer = 0
	_hurtbox.set_deferred(&"monitoring", false)
	_hitbox.set_deferred(&"monitorable", false)
	_separation.set_deferred(&"monitoring", false)


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
	# 추격 방향에 이웃을 밀어내는 힘을 섞는다. 하드 충돌로 막으면 한 점으로 몰린 무리가
	# 벽이 되어 플레이어에게 닿지 못하므로, 겹침은 허용하되 서로 퍼지게만 한다.
	var chase := (_target.global_position - global_position).normalized()
	var direction := (chase + _separation_push() * SEPARATION_WEIGHT).normalized()
	_movement.move(direction)


## 반경 안의 다른 적에게서 멀어지는 방향. 가까울수록 강하다.
func _separation_push() -> Vector2:
	var push := Vector2.ZERO
	for body in _separation.get_overlapping_bodies():
		if body == self:
			continue
		var offset := global_position - body.global_position
		var dist := offset.length()
		if dist <= 0.001:
			continue
		push += (offset / dist) * (1.0 - dist / SEPARATION_RADIUS)
	return push.limit_length(SEPARATION_MAX)


## 무기가 호출한다. impulse 는 방향 × 세기(px/s).
func apply_knockback(impulse: Vector2) -> void:
	_knockback = impulse


func _on_died() -> void:
	EventBus.enemy_died.emit(self, global_position)
	ObjectPool.release(self)


func _draw() -> void:
	var r := data.radius if data != null else 8.0
	var color := data.placeholder_color if data != null else Color(0.85, 0.16, 0.16)
	draw_circle(Vector2.ZERO, r, color)
