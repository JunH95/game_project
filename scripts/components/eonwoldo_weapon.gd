class_name EonwoldoWeapon
extends Node2D

## 언월도 — 몸을 돌려 사방을 쓸어 베는 대형 근접 무기(design.md 2-5).
##
## `[개정 이력]` 처음에는 궤도 회전(항상 켜져 있는 방어막)이었다. 폐기한 이유는
## **몸주의 정체성 무기인데 캐릭터가 아무 동작도 하지 않아서**다 — 최영장군을 골랐는데
## 날만 빙빙 도는 것을 보고 있게 된다. 지금은 실제로 몸을 돌려 휘두른다.
##
## 작두와의 구분은 여전히 기하학이다(2-0):
##   작두   = 앞쪽 부채꼴. 좁고 빠르다.
##   언월도 = 사방 360도. 넓고 느리고 무겁다.
## 궤도 회전 자체는 사라지지 않았다 — 합이 여는 궤도(궤도 작두·북두 방벽)가 `OrbitBlades` 로 남는다.

signal swung(direction: Vector2)

@export var data: WeaponData

## data 가 없을 때 쓰는 기본값.
const FALLBACK_DAMAGE: float = 22.0
const FALLBACK_COOLDOWN: float = 1.4
const FALLBACK_RANGE: float = 115.0
const FALLBACK_KNOCKBACK: float = 160.0

const MIN_COOLDOWN: float = 0.45
## 한 바퀴 도는 데 걸리는 시간. 판정은 즉발이고 이건 연출 길이다.
const SWEEP_TIME: float = 0.26

## 신내림 수정자를 물어볼 GodSystem. 없으면 기본 수치로 동작한다.
var god_system: Node

var _cooldown_left: float = 0.0
var _sweep_left: float = 0.0
## 이번 휘두름이 시작된 각. 여기서부터 한 바퀴 돈다.
var _sweep_from: float = 0.0


func _process(delta: float) -> void:
	if _sweep_left > 0.0:
		_sweep_left -= delta
		queue_redraw()

	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return

	var target := _find_nearest_enemy()
	if target == null:
		return

	_cooldown_left = _get_cooldown()
	var direction := (target.global_position - global_position).normalized()
	_sweep_from = direction.angle()
	_sweep_left = SWEEP_TIME
	_sweep()
	AudioManager.play(&"jakdu_swing")
	swung.emit(direction)
	queue_redraw()


## 사거리 안에서 가장 가까운 적. 사방을 베므로 방향은 연출용이고 판정에는 쓰지 않는다.
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


## 반경 안의 모든 적을 벤다. 각도 검사가 없다는 것이 작두와의 차이다.
func _sweep() -> void:
	var reach := _get_range()
	var reach_sq := reach * reach
	var damage := _get_base_damage()
	var knockback := _get_knockback()

	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - global_position
		if offset.length_squared() > reach_sq:
			continue
		_hit(enemy, damage, knockback, offset)


func _hit(enemy: Node2D, damage: float, knockback: float, offset: Vector2) -> void:
	var health := enemy.get_node_or_null(^"%HealthComponent") as HealthComponent
	if health == null:
		push_error("적에 HealthComponent 가 없어 언월도 데미지를 넣지 못했다: %s" % enemy.name)
		return
	var result := DamageCalc.resolve(damage, god_system, &"eonwoldo_damage_pct", enemy)
	health.take_damage(result["amount"])
	EventBus.damage_dealt.emit(enemy.global_position, result["amount"], result["is_crit"])
	if enemy.has_method(&"flash_hit"):
		enemy.call(&"flash_hit", result["is_crit"])
	if knockback > 0.0 and enemy.has_method(&"apply_knockback"):
		var push := offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
		enemy.call(&"apply_knockback", push * knockback)


func _god_mult(key: StringName) -> float:
	return god_system.get_multiplier(key) if god_system != null else 1.0


func _god_add(key: StringName) -> float:
	return god_system.get_mod(key) if god_system != null else 0.0


func _get_base_damage() -> float:
	return data.base_damage if data != null else FALLBACK_DAMAGE


## 날이 늘수록 빨라진다 — 궤도 시절의 "날 수"를 휘두름 속도로 옮겼다.
## 최영장군을 깊이 모실수록 더 자주 쓸어 담는다.
func _get_cooldown() -> float:
	var base := data.cooldown if data != null else FALLBACK_COOLDOWN
	var blades := floorf(_god_add(&"eonwoldo_count"))
	return maxf(MIN_COOLDOWN, base * _god_mult(&"cooldown_pct") * pow(0.88, blades))


func _get_range() -> float:
	var base := data.attack_range if data != null else FALLBACK_RANGE
	return base + _god_add(&"eonwoldo_arc_deg") * 0.4


func _get_knockback() -> float:
	var base := data.knockback if data != null else FALLBACK_KNOCKBACK
	return base * _god_mult(&"knockback_pct")


## 한 바퀴 도는 큰 호. 작두의 부채꼴과 달리 **원 전체**가 판정이라 그대로 보여 준다.
func _draw() -> void:
	if _sweep_left <= 0.0:
		return
	var t := _sweep_left / SWEEP_TIME
	var reach := _get_range()
	# 남은 시간만큼 호가 짧아진다 — 날이 지나간 자리가 뒤로 사라지는 것처럼 보인다.
	var swept := TAU * (1.0 - t)
	var color := Color(0.95, 0.93, 0.86, t * 0.85)

	# 지나간 자리 — 굵은 띠. 오목 폴리곤을 피하려고 draw_arc 의 width 를 쓴다(9-1).
	draw_arc(Vector2.ZERO, reach * 0.82, _sweep_from, _sweep_from + swept, 40,
		Color(color.r, color.g, color.b, t * 0.30), reach * 0.34)
	# 날 끝 — 지금 어디를 지나는지.
	draw_arc(Vector2.ZERO, reach, _sweep_from, _sweep_from + swept, 40, color, 3.0)
	var tip := Vector2.from_angle(_sweep_from + swept) * reach
	draw_circle(tip, 5.0, Color(1.0, 1.0, 1.0, t * 0.9))
