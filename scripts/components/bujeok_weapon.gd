class_name BujeokWeapon
extends Node2D

## 부적 — 원거리 유도 투사체. 쿨다운마다 최근접 적을 향해 발사한다(design.md 2-4).
## 작두가 닿지 않는 것(흩어진 적·먼 적)을 담당한다.
##
## 사거리 제약이 사실상 없어 조준 대상만 있으면 쏜다. 발수(count)는 칠성신 계열이 늘린다.

## 쏜 순간을 알린다. 몸이 던지는 동작을 해야 무기가 혼자 날아가는 것처럼 보이지 않는다.
signal fired(direction: Vector2)

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

## 술법을 여는 순간의 인장이 남는 시간. 연출 전용이라 판정과 무관하다.
const CAST_VISUAL_TIME: float = 0.22

var _cooldown_left: float = 0.0
var _cast_left: float = 0.0
var _cast_direction: Vector2 = Vector2.RIGHT


func _process(delta: float) -> void:
	if _cast_left > 0.0:
		_cast_left -= delta
		queue_redraw()

	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_cooldown_left = _get_cooldown()
	var direction := (target.global_position - global_position).normalized()
	_fire(direction)
	_cast_direction = direction
	_cast_left = CAST_VISUAL_TIME
	fired.emit(direction)
	queue_redraw()


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


## 술법을 여는 인장. 부적은 여태 **던지는 쪽에 아무 흔적이 없어서** 종이가 저절로 날아가는
## 것처럼 보였다 — 근접 두 무기와 달리 손에 무기가 남지 않기 때문이다.
## 그래서 손 앞에 인장을 그린다: 벌어지는 고리 + 사방으로 뻗는 획. 무기가 아니라 술법으로 읽힌다.
func _draw() -> void:
	if _cast_left <= 0.0:
		return
	var t := _cast_left / CAST_VISUAL_TIME
	var origin := _cast_direction * 18.0
	# 고리는 퍼지면서 옅어진다. 제자리에 머무는 원은 표식이지 발동이 아니다.
	var ring := 10.0 + (1.0 - t) * 26.0
	var ink := PlaceholderArt.JUSA
	draw_arc(origin, ring, 0.0, TAU, 24, Color(ink.r, ink.g, ink.b, t * 0.8), 2.0)
	draw_arc(origin, ring * 0.55, 0.0, TAU, 18,
		Color(ink.r, ink.g, ink.b, t * 0.45), 1.5)

	# 부적의 획 — 고리를 가르는 짧은 선 넷. 글자를 흉내내면 지저분해지므로 획만 남긴다.
	var spin := (1.0 - t) * 1.2 + _cast_direction.angle()
	for i in 4:
		var dir := Vector2.from_angle(spin + TAU * float(i) / 4.0)
		draw_line(origin + dir * (ring * 0.45), origin + dir * (ring * 1.15),
			Color(ink.r, ink.g, ink.b, t * 0.65), 2.0)
	# 발사 방향으로 한 줄기. 어디로 날아갔는지가 한 프레임 안에 읽혀야 한다.
	draw_line(origin, origin + _cast_direction * (34.0 * (1.0 - t) + 8.0),
		Color(1.0, 0.95, 0.82, t * 0.7), 2.5)
