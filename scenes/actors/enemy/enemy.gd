extends CharacterBody2D

## 공용 적. EnemyData 리소스로 스탯·외형을 구성한다(data-driven).
## M1 슬라이스: 플레이어를 추격하고 접촉 데미지를 준다. 처치 시 enemy_died 를 emit.
## 외형은 EnemyData.silhouette 이 고르는 PlaceholderArt 실루엣. texture 를 물리면 그쪽이 우선한다.

@export var data: EnemyData

## 넉백 감쇠 계수. 클수록 빨리 멎는다(초당 감쇠율).
const KNOCKBACK_DECAY: float = 8.0

## 이웃을 밀어내는 반경. SeparationArea 의 CircleShape2D 반지름과 맞춘다.
const SEPARATION_RADIUS: float = 20.0
## 추격 방향 대비 분리 조향의 비중. 너무 크면 흩어져 플레이어에게 도달하지 못한다.
const SEPARATION_WEIGHT: float = 0.7
## 이웃이 많아도 분리력이 무한정 커지지 않게 막는 상한.
const SEPARATION_MAX: float = 1.5

## 피격 틴트가 남는 시간. 치명은 더 길게 보여 준다.
const FLASH_TIME: float = 0.09
const FLASH_TIME_CRIT: float = 0.2
const FLASH_COLOR: Color = Color(1.6, 1.6, 1.6)
const FLASH_COLOR_CRIT: Color = Color(1.9, 1.5, 0.5)

## 몸이 흔들리는 주기(초당 라디안)와 폭. 살짝만 준다 — 크게 흔들면 히트박스와 눈이 어긋난다.
const BODY_BOB_SPEED: float = 6.5
const BODY_BOB_AMOUNT: float = 0.09
## 이동 방향으로 도는 속도. 즉시 돌리면 무리 속에서 방향이 덜덜 떨린다.
const TURN_RATE: float = 12.0

var _target: Node2D
var _knockback: Vector2 = Vector2.ZERO
var _flash_left: float = 0.0
var _flash_total: float = 0.0
var _flash_color: Color = FLASH_COLOR
## 개체마다 다른 위상. 같으면 무리 전체가 한 몸처럼 맥동해 기괴해진다.
var _bob_phase: float = 0.0
## 등급별 크기 배율. 숨쉬기 애니메이션이 scale 을 쓰므로 여기에 곱해 둔다.
var _elite_scale: float = 1.0

@onready var _movement: MovementComponent = %MovementComponent
@onready var _health: HealthComponent = %HealthComponent
@onready var _hurtbox: HurtboxComponent = %HurtboxComponent
@onready var _hitbox: HitboxComponent = %HitboxComponent
@onready var _body_shape: CollisionShape2D = %CollisionShape2D
@onready var _separation: Area2D = %SeparationArea
@onready var _skills: EnemySkills = get_node_or_null(^"%EnemySkills")


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
## 관문이 진행될수록 적이 단단해진다(design.md 4-1).
## 잡몹 한 방 킬은 이 장르의 정답이라 그대로 두되, **성장을 멈추면 한 방이 깨지도록** 한다.
## 그래야 damage 를 올리는 이유가 "두 방을 한 방으로"가 아니라 "한 방을 유지하려고"가 된다.
const HP_SCALE_AT_END: float = 2.6
const DAMAGE_SCALE_AT_END: float = 1.8


## 0.0(시작) ~ 1.0(관문 끝). RunManager 가 런 상태를 쥐고 있으므로 거기서 읽는다.
static func difficulty_progress() -> float:
	var total := maxf(1.0, RunManager.gate_duration_sec)
	return clampf(RunManager.elapsed_sec / total, 0.0, 1.0)


func _apply_data() -> void:
	if data == null:
		return
	var t := difficulty_progress()
	_movement.speed = data.move_speed
	_health.setup(data.max_hp * (1.0 + (HP_SCALE_AT_END - 1.0) * t))
	_hitbox.damage = data.contact_damage * (1.0 + (DAMAGE_SCALE_AT_END - 1.0) * t)
	var circle := _body_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = data.radius
	# 엘리트는 눈에 띄어야 한다(design.md 6-4-1). 크기와 테두리 둘로 구분한다 —
	# 같아 보이는데 특수 능력이 있으면 난이도가 아니라 불공정으로 느껴진다.
	_elite_scale = maxf(0.1, data.elite_scale)
	if _skills != null:
		_skills.reset(data)
	queue_redraw()


## 풀에서 꺼내질 때. 스폰 위치와 data 는 호출자가 먼저 넣어 준다.
func _pool_reset() -> void:
	_knockback = Vector2.ZERO
	velocity = Vector2.ZERO
	_flash_left = 0.0
	modulate = Color.WHITE
	rotation = 0.0
	scale = Vector2.ONE
	_elite_scale = 1.0
	_bob_phase = randf() * TAU
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
	# 묶어 둔 채로 죽으면 플레이어가 영영 느려진다. 반납 전에 반드시 푼다.
	if _skills != null:
		_skills.reset(null)
	collision_layer = 0
	_hurtbox.set_deferred(&"monitoring", false)
	_hitbox.set_deferred(&"monitorable", false)
	_separation.set_deferred(&"monitoring", false)


func _physics_process(delta: float) -> void:
	_decay_flash(delta)
	_animate_body(delta)

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


## 살아 있다는 느낌은 transform 으로만 낸다 — queue_redraw 를 부르지 않으므로 마리 수에 비례하는
## 비용이 붙지 않는다. 방향성 있는 실루엣은 진행 방향으로 돌고, 나머지는 제자리에서 숨 쉰다.
func _animate_body(delta: float) -> void:
	if data != null and data.faces_movement:
		if not velocity.is_zero_approx():
			rotation = rotate_toward(rotation, velocity.angle(), TURN_RATE * delta)
		scale = Vector2.ONE * _elite_scale
		return
	_bob_phase += BODY_BOB_SPEED * delta
	var bob := sin(_bob_phase) * BODY_BOB_AMOUNT
	# 가로가 늘면 세로가 줄게 해서 부피가 유지되는 것처럼 보이게 한다.
	scale = Vector2(1.0 + bob, 1.0 - bob) * _elite_scale


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


## 무기가 호출한다. 맞았다는 사실과 치명 여부를 눈에 보이게 한다 —
## 보이지 않는 치명은 없는 기능이다. 정식 데미지 숫자는 M6.
func flash_hit(is_crit: bool) -> void:
	_flash_total = FLASH_TIME_CRIT if is_crit else FLASH_TIME
	_flash_left = _flash_total
	_flash_color = FLASH_COLOR_CRIT if is_crit else FLASH_COLOR
	modulate = _flash_color


## Tween 을 쓰지 않는 이유: 풀에 반납되면 노드가 트리 밖으로 나가 트윈이 어중간하게 남는다.
func _decay_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		modulate = Color.WHITE
		return
	modulate = Color.WHITE.lerp(_flash_color, _flash_left / _flash_total)


func _on_died() -> void:
	# 분열처럼 죽는 순간에만 의미가 있는 스킬은 풀에 반납하기 전에 처리한다.
	if _skills != null:
		_skills.on_died()
	EventBus.enemy_died.emit(self, global_position)
	ObjectPool.release(self)


## 실루엣은 정적으로 그린다 — 수백 마리가 매 프레임 다시 그리면 캔버스 아이템을 그만큼 다시 만든다.
## 살아 있다는 느낌은 _physics_process 의 transform(회전·숨쉬기)이 낸다.
func _draw() -> void:
	var r := data.radius if data != null else 8.0
	# 실루엣이 판정 원보다 조금 커야 몸이 꽉 차 보인다. 텍스처도 같은 비율로 맞춘다.
	if data != null and PlaceholderArt.draw_texture_centered(self, data.texture, r * 2.6):
		return
	var color := data.placeholder_color if data != null else Color(0.85, 0.16, 0.16)
	# 엘리트 테두리 — 실루엣 뒤에 깔아 후광처럼 보이게 한다.
	if data != null and data.outline_color.a > 0.0:
		draw_circle(Vector2.ZERO, r * 1.6, Color(data.outline_color, data.outline_color.a * 0.35))
		draw_arc(Vector2.ZERO, r * 1.35, 0.0, TAU, 28, data.outline_color, 2.0)
	var shape := data.silhouette if data != null else "wraith"
	match shape:
		"rusher":
			PlaceholderArt.draw_rusher(self, r, color)
		"hulk":
			PlaceholderArt.draw_hulk(self, r, color)
		_:
			PlaceholderArt.draw_wraith(self, r, color)
