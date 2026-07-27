class_name BujeokWeapon
extends Node2D

## 부적 — 원거리 유도 투사체. 쿨다운마다 최근접 적을 향해 발사한다(design.md 2-4).
## 작두가 닿지 않는 것(흩어진 적·먼 적)을 담당한다.
##
## 사거리 제약이 사실상 없어 조준 대상만 있으면 쏜다. 발수(count)는 칠성신 계열이 늘린다.

@export var data: WeaponData
@export var projectile_scene: PackedScene

## data 가 없을 때 쓰는 기본값(design.md 2-4).
const FALLBACK_DAMAGE: float = 14.0
const FALLBACK_COOLDOWN: float = 1.2

## 성장해도 넘지 않는 한계. 발수는 북두칠성 7 이 상한이다.
const MIN_COOLDOWN: float = 0.2
const MAX_COUNT: int = 7
## 발수가 2 이상일 때 부채꼴로 흩어 쏘는 총 각도.
const SPREAD_DEGREES: float = 24.0

## 신내림 수정자를 물어볼 GodSystem. 없으면 기본 수치로 동작한다.
var god_system: Node

var _cooldown_left: float = 0.0


func _process(delta: float) -> void:
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_cooldown_left = _get_cooldown()
	_fire((target.global_position - global_position).normalized())


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq := INF
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist_sq := global_position.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy
	return nearest


func _fire(direction: Vector2) -> void:
	if projectile_scene == null:
		push_error("BujeokWeapon 에 projectile_scene 이 없어 발사할 수 없다.")
		return
	var count := _get_count()
	# 여러 발은 부채꼴로 흩어 쏜다. 한 점에 겹쳐 쏘면 발수가 늘어난 게 보이지 않는다.
	var spread := deg_to_rad(SPREAD_DEGREES)
	var base := direction.angle() - spread * 0.5
	var step := spread / float(maxi(1, count - 1))

	for i in count:
		var angle := base + step * float(i) if count > 1 else direction.angle()
		var projectile := ObjectPool.acquire(projectile_scene, get_tree().current_scene)
		if projectile == null:
			return
		projectile.global_position = global_position
		projectile.damage = _get_base_damage()
		projectile.god_system = god_system
		projectile.speed = data.projectile_speed if data != null else 320.0
		projectile.homing_turn_rate = data.homing_turn_rate if data != null else 4.0
		projectile.pierce = data.pierce if data != null else 1
		projectile.lifetime = data.lifetime if data != null else 2.5
		projectile.knockback = (data.knockback if data != null else 0.0) * _god_mult(&"knockback_pct")
		projectile.launch(Vector2.from_angle(angle))


func _god_mult(key: StringName) -> float:
	return god_system.get_multiplier(key) if god_system != null else 1.0


func _god_add(key: StringName) -> float:
	return god_system.get_mod(key) if god_system != null else 0.0


## 신 수정자·오행·치명은 명중 시점에 DamageCalc 가 처리한다(투사체가 들고 간다).
func _get_base_damage() -> float:
	return data.base_damage if data != null else FALLBACK_DAMAGE


func _get_cooldown() -> float:
	var base := data.cooldown if data != null else FALLBACK_COOLDOWN
	return maxf(MIN_COOLDOWN, base * _god_mult(&"cooldown_pct"))


## 발수는 정수라 레벨당 소수로 쌓은 뒤 내림한다(design.md 3-4).
func _get_count() -> int:
	var base := data.count if data != null else 1
	return clampi(base + int(floorf(_god_add(&"bujeok_count"))), 1, MAX_COUNT)
