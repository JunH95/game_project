class_name JakduWeapon
extends Node2D

## 작두 — 근접 자동 부채꼴 베기. 쿨다운마다 최근접 적 방향으로 호(arc) 범위를 벤다.
## 궤도형 칼날이 아니라 "무당이 작두를 휘두르는" 형태(design.md §2).
##
## Area2D 히트박스가 아니라 쿼리 방식을 쓴다: 순간 휘두르기는 겹침 지속 판정(HurtboxComponent)과
## 맞지 않아, 스윙마다 정확히 1회만 타격하려면 그 순간의 적 목록을 직접 훑는 편이 확실하다.
##
## `[고증]` 작두타기(장군신 강림 시 조건부 발동)는 M3에서 이 위에 얹는다. 여기까지는 평상시 근접 공격.

signal swung(direction: Vector2)

@export var data: WeaponData

## data 가 없을 때 쓰는 기본값(design.md §2 초안 수치).
const FALLBACK_DAMAGE: float = 10.0
const FALLBACK_COOLDOWN: float = 0.8
const FALLBACK_RANGE: float = 90.0
const FALLBACK_ARC: float = 100.0
const FALLBACK_KNOCKBACK: float = 120.0

## 베기 잔상이 남는 시간. 연출 전용이라 판정과는 무관하다.
const SWING_VISUAL_TIME: float = 0.15

var _cooldown_left: float = 0.0
var _swing_visual_left: float = 0.0
var _swing_direction: Vector2 = Vector2.RIGHT


func _process(delta: float) -> void:
	if _swing_visual_left > 0.0:
		_swing_visual_left -= delta
		queue_redraw()

	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return

	var target := _find_nearest_enemy()
	if target == null:
		return

	_cooldown_left = _get_cooldown()
	_swing_direction = (target.global_position - global_position).normalized()
	_swing_visual_left = SWING_VISUAL_TIME
	_swing(_swing_direction)
	swung.emit(_swing_direction)
	queue_redraw()


## 사거리 안에서 가장 가까운 적을 찾는다. 없으면 null.
func _find_nearest_enemy() -> Node2D:
	var reach := _get_range()
	var nearest: Node2D = null
	var nearest_dist_sq := reach * reach
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist_sq := global_position.distance_squared_to(enemy.global_position)
		if dist_sq <= nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy
	return nearest


## 부채꼴 안의 모든 적을 타격한다.
func _swing(direction: Vector2) -> void:
	var reach := _get_range()
	var reach_sq := reach * reach
	# 반각과 비교하려고 코사인으로 바꿔둔다(정규화 벡터끼리는 내적이 곧 각도의 코사인).
	var half_arc_cos := cos(deg_to_rad(_get_arc_degrees() * 0.5))
	var damage := _get_damage()
	var knockback := _get_knockback()

	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - global_position
		if offset.length_squared() > reach_sq:
			continue
		# 정확히 겹친 적은 방향이 정의되지 않으므로 각도 검사를 건너뛰고 무조건 맞힌다.
		if not offset.is_zero_approx() and direction.dot(offset.normalized()) < half_arc_cos:
			continue
		_hit(enemy, damage, knockback, offset)


func _hit(enemy: Node2D, damage: float, knockback: float, offset: Vector2) -> void:
	var health := enemy.get_node_or_null(^"%HealthComponent") as HealthComponent
	if health == null:
		push_error("적에 HealthComponent 가 없어 작두 데미지를 넣지 못했다: %s" % enemy.name)
		return
	health.take_damage(damage)
	if knockback > 0.0 and enemy.has_method(&"apply_knockback"):
		var push := offset.normalized() if not offset.is_zero_approx() else _swing_direction
		enemy.call(&"apply_knockback", push * knockback)


func _get_damage() -> float:
	return data.base_damage if data != null else FALLBACK_DAMAGE


func _get_cooldown() -> float:
	return data.cooldown if data != null else FALLBACK_COOLDOWN


func _get_range() -> float:
	return data.attack_range if data != null else FALLBACK_RANGE


func _get_arc_degrees() -> float:
	return data.arc_degrees if data != null else FALLBACK_ARC


func _get_knockback() -> float:
	return data.knockback if data != null else FALLBACK_KNOCKBACK


## 플레이스홀더 연출 = 흰 호(design.md §9). 휘두른 직후 잠깐 나타났다 사라진다.
func _draw() -> void:
	if _swing_visual_left <= 0.0:
		return
	var alpha := _swing_visual_left / SWING_VISUAL_TIME
	var half_arc := deg_to_rad(_get_arc_degrees() * 0.5)
	var base_angle := _swing_direction.angle()
	draw_arc(
		Vector2.ZERO,
		_get_range(),
		base_angle - half_arc,
		base_angle + half_arc,
		24,
		Color(1.0, 1.0, 1.0, alpha),
		3.0
	)
