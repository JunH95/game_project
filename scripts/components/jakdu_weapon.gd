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

## 성장해도 넘지 않는 한계. 쿨이 0 이 되면 매 프레임 판정이 돌고, 각이 360 을 넘으면 의미가 없다.
const MIN_COOLDOWN: float = 0.15
const MAX_ARC: float = 360.0

## `[고증]` 작두타기 — 합 "장군 강림"(작도대신 × 최영장군)이 열어 준다(design.md 3-5).
## 기세가 차오르면 장군신이 내려 잠시 사방을 벤다. 수치는 `[제안]`.
const TAEGI_GAUGE_MAX: float = 100.0
## 한 번 휘둘러 맞힌 적 수에 비례해 찬다. 스윙당 인정 상한을 두지 않으면 무리 한가운데서 즉시 찬다.
const TAEGI_GAIN_PER_HIT: float = 1.0
const TAEGI_MAX_HITS_COUNTED: int = 4
const TAEGI_DURATION: float = 6.0
## 강림 중 보정 — 사방(360°)을 더 세게, 더 자주 벤다.
const TAEGI_DAMAGE_MULT: float = 1.8
const TAEGI_COOLDOWN_MULT: float = 0.6
const TAEGI_KNOCKBACK_MULT: float = 1.5

## 신내림 수정자를 물어볼 GodSystem. 없으면 기본 수치로 동작한다.
var god_system: Node
## 합 성립을 물어볼 SynergySystem. 없으면 작두타기는 열리지 않는다.
var synergy_system: Node

var _gauge: float = 0.0
var _taegi_left: float = 0.0
var _cooldown_left: float = 0.0
var _swing_visual_left: float = 0.0
var _swing_direction: Vector2 = Vector2.RIGHT


func _process(delta: float) -> void:
	_tick_taegi(delta)

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
	AudioManager.play(&"jakdu_swing")
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


## 작두타기가 열려 있는지(합 "장군 강림").
func is_taegi_unlocked() -> bool:
	return synergy_system != null and synergy_system.is_active(&"jakdu_taegi")


func is_taegi_active() -> bool:
	return _taegi_left > 0.0


## HUD 표시용 0.0~1.0.
func get_taegi_ratio() -> float:
	if is_taegi_active():
		return _taegi_left / TAEGI_DURATION
	return _gauge / TAEGI_GAUGE_MAX


func _tick_taegi(delta: float) -> void:
	if _taegi_left <= 0.0:
		return
	_taegi_left -= delta
	if _taegi_left <= 0.0:
		_taegi_left = 0.0
		EventBus.taegi_state_changed.emit(false)


## 맞힌 적 수만큼 기세가 오른다. 충전 속도는 최영장군을 모실수록 빨라진다(taegi_charge_pct).
func _charge_taegi(hit_count: int) -> void:
	if not is_taegi_unlocked() or is_taegi_active() or hit_count <= 0:
		return
	var counted := mini(hit_count, TAEGI_MAX_HITS_COUNTED)
	_gauge += TAEGI_GAIN_PER_HIT * float(counted) * _god_mult(&"taegi_charge_pct")
	if _gauge >= TAEGI_GAUGE_MAX:
		_gauge = 0.0
		_taegi_left = TAEGI_DURATION
		EventBus.taegi_state_changed.emit(true)


## 부채꼴 안의 모든 적을 타격한다.
func _swing(direction: Vector2) -> void:
	var reach := _get_range()
	var reach_sq := reach * reach
	# 반각과 비교하려고 코사인으로 바꿔둔다(정규화 벡터끼리는 내적이 곧 각도의 코사인).
	var half_arc_cos := cos(deg_to_rad(_get_arc_degrees() * 0.5))
	# 데미지는 대상마다 다르다(오행 배율·치명) — 여기서는 기본값만 넘기고 _hit 에서 확정한다.
	var damage := _get_base_damage()
	var knockback := _get_knockback()

	var hits := 0
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
		hits += 1
	_charge_taegi(hits)


func _hit(enemy: Node2D, damage: float, knockback: float, offset: Vector2) -> void:
	var health := enemy.get_node_or_null(^"%HealthComponent") as HealthComponent
	if health == null:
		push_error("적에 HealthComponent 가 없어 작두 데미지를 넣지 못했다: %s" % enemy.name)
		return
	var result := DamageCalc.resolve(damage, god_system, &"jakdu_damage_pct", enemy)
	health.take_damage(result["amount"])
	EventBus.damage_dealt.emit(enemy.global_position, result["amount"], result["is_crit"])
	if enemy.has_method(&"flash_hit"):
		enemy.call(&"flash_hit", result["is_crit"])
	if knockback > 0.0 and enemy.has_method(&"apply_knockback"):
		var push := offset.normalized() if not offset.is_zero_approx() else _swing_direction
		enemy.call(&"apply_knockback", push * knockback)


## 신내림 수정자. GodSystem 이 없으면 중립값을 돌려준다.
func _god_mult(key: StringName) -> float:
	return god_system.get_multiplier(key) if god_system != null else 1.0


func _god_add(key: StringName) -> float:
	return god_system.get_mod(key) if god_system != null else 0.0


## 신 수정자·오행·치명은 DamageCalc 가 대상별로 처리한다. 여기서는 무기 자체의 기본값만 준다.
## 강림 중에는 위력이 실린다.
func _get_base_damage() -> float:
	var base := data.base_damage if data != null else FALLBACK_DAMAGE
	return base * TAEGI_DAMAGE_MULT if is_taegi_active() else base


func _get_cooldown() -> float:
	var base := data.cooldown if data != null else FALLBACK_COOLDOWN
	if is_taegi_active():
		base *= TAEGI_COOLDOWN_MULT
	return maxf(MIN_COOLDOWN, base * _god_mult(&"cooldown_pct"))


func _get_range() -> float:
	return data.attack_range if data != null else FALLBACK_RANGE


## 강림 중에는 사방을 벤다 — 작두를 타는 동안은 겨눌 방향이 따로 없다.
func _get_arc_degrees() -> float:
	if is_taegi_active():
		return MAX_ARC
	var base := data.arc_degrees if data != null else FALLBACK_ARC
	return minf(MAX_ARC, base + _god_add(&"jakdu_arc_deg"))


func _get_knockback() -> float:
	var base := data.knockback if data != null else FALLBACK_KNOCKBACK
	if is_taegi_active():
		base *= TAEGI_KNOCKBACK_MULT
	return base * _god_mult(&"knockback_pct")


## 베기 잔상. 원점에서 퍼지는 부채꼴이 아니라 **띠**로 그린다 — 꽉 찬 부채꼴은 장판처럼 보이고,
## 날이 지나간 자리는 원호를 따라 남기 때문이다. 띠 두께가 곧 판정 범위라 보이는 것과 맞는다.
## draw_arc 에 굵은 width 를 주면 고리 조각이 나온다(오목 폴리곤을 피하는 방법이기도 하다).
func _draw() -> void:
	if _swing_visual_left <= 0.0:
		return
	var t := _swing_visual_left / SWING_VISUAL_TIME
	var reach := _get_range()
	var half_arc := deg_to_rad(_get_arc_degrees() * 0.5)
	var base_angle := _swing_direction.angle()
	var from := base_angle - half_arc
	var to := base_angle + half_arc

	const SEGMENTS := 28
	# 강림 중에는 금색 — 지금이 그 순간이라는 걸 한눈에 알아야 한다.
	var tint := PlaceholderArt.GEUMBAK if is_taegi_active() else Color(0.92, 0.95, 1.0)

	# 잔상은 사라지면서 바깥으로 밀려난다. 제자리에서 옅어지기만 하면 베였다는 느낌이 없다.
	var spread := 1.0 + (1.0 - t) * 0.12
	var band_radius := reach * 0.7 * spread
	var band_width := reach * 0.52
	draw_arc(Vector2.ZERO, band_radius, from, to, SEGMENTS,
		Color(tint.r, tint.g, tint.b, t * 0.22), band_width)
	# 날 끝이 지나간 선. 가장 진하게 남겨 베기의 방향이 읽히게 한다.
	draw_arc(Vector2.ZERO, reach * spread, from, to, SEGMENTS,
		Color(tint.r, tint.g, tint.b, t * 0.9), 3.0)
	# 휘두름의 시작·끝을 잇는 짧은 선. 부채꼴의 양 끝이 열려 있으면 띠가 떠 보인다.
	for edge_angle in [from, to]:
		var dir := Vector2.from_angle(edge_angle)
		draw_line(dir * (reach * 0.44), dir * (reach * spread),
			Color(tint.r, tint.g, tint.b, t * 0.45), 2.0)
