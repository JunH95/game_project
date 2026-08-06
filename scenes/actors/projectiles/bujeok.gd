extends Area2D

## 부적 투사체. 발사 후 가장 가까운 적을 향해 완만히 방향을 틀며 날아간다(유도).
## 관통 횟수를 다 쓰거나 수명이 다하면 풀에 반납된다.
## 외형은 PlaceholderArt 의 부적 종이. texture 를 물리면 그쪽이 우선한다.

const SIZE: float = 6.0

## 정식 아트가 들어오면 여기에 물리고, 도형 실루엣은 자동으로 비켜난다.
@export var texture: Texture2D

## 무기의 기본 데미지. 최종값은 명중 시점에 DamageCalc 가 정한다 —
## 오행 배율은 대상이 정해져야 나오고, 치명도 발마다 굴려야 한다.
var damage: float = 14.0
## 발사한 무기의 GodSystem. 명중 시 신 수정자·기운을 물어본다.
var god_system: Node
var speed: float = 320.0
var homing_turn_rate: float = 4.0
var pierce: int = 1
var lifetime: float = 2.5
var knockback: float = 0.0

var _direction: Vector2 = Vector2.RIGHT
var _life_left: float = 0.0
var _pierce_left: int = 0
## 같은 적을 관통 중 여러 번 때리지 않도록 기록한다.
var _hit: Array[Node] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)


## 무기가 발사 직후 호출한다.
func launch(direction: Vector2) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_life_left = lifetime
	_pierce_left = pierce
	_hit.clear()
	rotation = _direction.angle()


func _pool_reset() -> void:
	_hit.clear()
	collision_layer = 32
	set_deferred(&"monitoring", true)
	set_deferred(&"monitorable", true)


func _pool_exit() -> void:
	_hit.clear()
	collision_layer = 0
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		ObjectPool.release(self)
		return

	var target := _find_nearest_enemy()
	if target != null:
		# 목표 방향으로 조금씩 튼다. 즉시 꺾으면 유도가 아니라 순간이동처럼 보인다.
		var desired := (target.global_position - global_position).normalized()
		_direction = _direction.slerp(desired, minf(homing_turn_rate * delta, 1.0)).normalized()
		rotation = _direction.angle()

	global_position += _direction * speed * delta


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq := INF
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy) or _hit.has(enemy):
			continue
		var dist_sq := global_position.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy
	return nearest


func _on_area_entered(area: Area2D) -> void:
	# 적의 hurtbox 를 맞힌다. hurtbox 는 컴포넌트라 소유 액터를 거슬러 올라간다.
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	var enemy := hurtbox.get_parent()
	if enemy == null or _hit.has(enemy):
		return
	_hit.append(enemy)

	if hurtbox.health != null:
		var result := DamageCalc.resolve(damage, god_system, &"bujeok_damage_pct", enemy)
		hurtbox.health.take_damage(result["amount"])
		EventBus.damage_dealt.emit(enemy.global_position, result["amount"], result["is_crit"],
			&"bujeok")
		if enemy.has_method(&"flash_hit"):
			enemy.call(&"flash_hit", result["is_crit"])
	if knockback > 0.0 and enemy.has_method(&"apply_knockback"):
		enemy.call(&"apply_knockback", _direction * knockback)

	_pierce_left -= 1
	if _pierce_left <= 0:
		ObjectPool.release(self)


## 진행 방향이 X 축이 되도록 그린다. 방향 전환은 rotation 이 맡으므로 다시 그릴 필요가 없다.
func _draw() -> void:
	if PlaceholderArt.draw_texture_centered(self, texture, SIZE * 3.0):
		return
	PlaceholderArt.draw_talisman(self, SIZE)
