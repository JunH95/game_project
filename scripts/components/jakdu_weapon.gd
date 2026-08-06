class_name JakduWeapon
extends Node2D

## 작두 — 근접 자동 부채꼴 베기. 쿨다운마다 최근접 적 방향으로 호(arc) 범위를 벤다.
## 궤도형 칼날이 아니라 "무당이 작두를 휘두르는" 형태(design.md §2).
##
## Area2D 히트박스가 아니라 쿼리 방식을 쓴다: 순간 휘두르기는 겹침 지속 판정(HurtboxComponent)과
## 맞지 않아, 스윙마다 정확히 1회만 타격하려면 그 순간의 적 목록을 직접 훑는 편이 확실하다.
##
## `[고증]` 작두타기(장군신 강림 시 조건부 발동)는 M3에서 이 위에 얹는다. 여기까지는 평상시 근접 공격.

signal swung(direction: Vector2, step: int)

@export var data: WeaponData

## data 가 없을 때 쓰는 기본값(design.md §2 초안 수치).
const FALLBACK_DAMAGE: float = 10.0
const FALLBACK_COOLDOWN: float = 0.8
const FALLBACK_RANGE: float = 90.0
const FALLBACK_ARC: float = 100.0
const FALLBACK_KNOCKBACK: float = 120.0

## 베기 잔상이 남는 시간. 연출 전용이라 판정과는 무관하다.
const SWING_VISUAL_TIME: float = 0.15

## 3연타의 기하 — 사무라이 액션. 같은 부채꼴을 반복하면 아무리 잘 그려도 기계처럼 보인다.
##   0 내려베기 → 1 되돌려베기(반대로 쓸림) → 2 찌르기(좁고 길고 세다)
## 보이는 것과 맞는 것이 같아야 하므로(design.md 2-0) 그림뿐 아니라 **판정 기하도** 같이 바꾼다.
## 찌르기가 강한 대신 좁아 무리 한가운데서는 오히려 덜 담긴다 — 총 DPS는 거의 그대로다.
const STEP_COUNT: int = 3
const STEP_RANGE_MULT: Array[float] = [1.0, 1.0, 1.45]
const STEP_ARC_MULT: Array[float] = [1.0, 1.0, 0.42]
const STEP_DAMAGE_MULT: Array[float] = [1.0, 0.95, 1.3]

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
## 연타의 몇 번째 타인가. 무기가 소유한다 — 그림과 판정이 같은 값을 봐야 어긋나지 않는다.
var _slash_step: int = 0


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
	# 강림 중에는 사방을 베므로 연타가 의미가 없다 — 연타는 겨눈 방향이 있을 때만 돈다.
	_slash_step = 0 if is_taegi_active() else (_slash_step + 1) % STEP_COUNT
	_swing_direction = (target.global_position - global_position).normalized()
	_swing_visual_left = SWING_VISUAL_TIME
	_swing(_swing_direction)
	AudioManager.play(&"jakdu_swing")
	swung.emit(_swing_direction, _slash_step)
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


## 기세가 가득 찼는지. 강림을 부를 수 있는 상태다.
func is_taegi_ready() -> bool:
	return is_taegi_unlocked() and not is_taegi_active() and _gauge >= TAEGI_GAUGE_MAX


## 플레이어가 강림을 부른다. `[고증]` 신은 저절로 오지 않고 불러야 온다.
## 부를 수 없는 상태면 false 를 돌려 호출자가 헛발질을 알 수 있게 한다.
func invoke_taegi() -> bool:
	if not is_taegi_ready():
		return false
	_gauge = 0.0
	_taegi_left = TAEGI_DURATION
	EventBus.taegi_state_changed.emit(true)
	AudioManager.play(&"taegi")
	return true


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
	# 가득 차면 멈춘다. 내리는 것은 플레이어가 정한다 — 자동으로 터지면 판단이 사라지고,
	# 이 게임에서 가장 극적인 순간이 그냥 지나간다.
	_gauge = minf(TAEGI_GAUGE_MAX,
		_gauge + TAEGI_GAIN_PER_HIT * float(counted) * _god_mult(&"taegi_charge_pct"))
	if _gauge >= TAEGI_GAUGE_MAX:
		EventBus.taegi_ready.emit()


## 부채꼴 안의 모든 적을 타격한다.
func _swing(direction: Vector2) -> void:
	var reach := _step_range()
	var reach_sq := reach * reach
	# 반각과 비교하려고 코사인으로 바꿔둔다(정규화 벡터끼리는 내적이 곧 각도의 코사인).
	var half_arc_cos := cos(deg_to_rad(_step_arc_degrees() * 0.5))
	# 데미지는 대상마다 다르다(오행 배율·치명) — 여기서는 기본값만 넘기고 _hit 에서 확정한다.
	var damage := _get_base_damage() * _step_mult(STEP_DAMAGE_MULT)
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
	EventBus.damage_dealt.emit(enemy.global_position, result["amount"], result["is_crit"],
		&"jakdu")
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


## 연타 보정. 강림 중에는 사방 베기라 보정을 걸지 않는다(좁혔다가는 360도가 무너진다).
func _step_mult(table: Array[float]) -> float:
	if is_taegi_active():
		return 1.0
	return table[clampi(_slash_step, 0, table.size() - 1)]


func _step_range() -> float:
	return _get_range() * _step_mult(STEP_RANGE_MULT)


func _step_arc_degrees() -> float:
	return _get_arc_degrees() * _step_mult(STEP_ARC_MULT)


## 베기 잔상. 날이 **지나간다** — 완성된 부채꼴을 한 장 띄우고 지우면 장판처럼 보이고,
## 어느 쪽으로 벴는지가 사라진다. 그래서 잔상 시간 동안 칼끝이 한쪽 끝에서 반대쪽 끝으로
## 실제로 이동하고, 지나온 자리만 띠로 남긴다. 되돌려베기는 이 이동이 반대로 간다 —
## 3연타가 눈에 보이는 곳이 여기다.
func _draw() -> void:
	if _swing_visual_left <= 0.0:
		return
	var t := _swing_visual_left / SWING_VISUAL_TIME
	# 강림 중에는 금색 — 지금이 그 순간이라는 걸 한눈에 알아야 한다.
	var tint := PlaceholderArt.GEUMBAK if is_taegi_active() else Color(0.92, 0.95, 1.0)
	if not is_taegi_active() and _slash_step == 2:
		_draw_thrust(t, tint)
	else:
		_draw_slash(t, tint)


## 내려베기 / 되돌려베기. 홀수 타는 칼끝이 반대 방향으로 지나간다.
func _draw_slash(t: float, tint: Color) -> void:
	var reach := _step_range()
	var half_arc := deg_to_rad(_step_arc_degrees() * 0.5)
	var base_angle := _swing_direction.angle()
	var reversed := _slash_step == 1
	var start := base_angle + (half_arc if reversed else -half_arc)
	var end := base_angle - (half_arc if reversed else -half_arc)

	# 칼끝의 현재 위치. 처음(t=1)에 시작 끝, 마지막(t=0)에 반대 끝.
	var progress := 1.0 - t
	var edge := lerp_angle(start, end, progress)
	const SEGMENTS := 24
	# 지나간 자리만 띠로. 앞으로 갈 곳은 아직 비어 있어야 방향이 읽힌다.
	draw_arc(Vector2.ZERO, reach * 0.72, start, edge, SEGMENTS,
		Color(tint.r, tint.g, tint.b, t * 0.24), reach * 0.5)
	draw_arc(Vector2.ZERO, reach, start, edge, SEGMENTS,
		Color(tint.r, tint.g, tint.b, t * 0.85), 3.0)
	# 칼날 자체. 안쪽에서 바깥으로 뻗은 선이라 "무언가 손에 들려 있다"가 보인다.
	var blade := Vector2.from_angle(edge)
	draw_line(blade * (reach * 0.32), blade * reach,
		Color(tint.r, tint.g, tint.b, minf(1.0, t + 0.25)), 4.0)
	draw_circle(blade * reach, 4.0, Color(1.0, 1.0, 1.0, t * 0.9))


## 찌르기 — 3타 마무리. 호가 아니라 **직선**이라 한눈에 다르다.
func _draw_thrust(t: float, tint: Color) -> void:
	var reach := _step_range()
	var dir := _swing_direction
	var side := dir.orthogonal()
	# 앞으로 뻗었다가 그 자리에서 옅어진다. 뻗는 동안이 가장 길다.
	var extend := reach * clampf((1.0 - t) * 2.2, 0.35, 1.0)
	var tip := dir * extend
	var root := dir * (reach * 0.22)
	# 창끝 모양 — 뿌리는 넓고 끝은 한 점. 삼각형이라 오목 폴리곤 문제가 없다.
	var half_width := reach * 0.13
	draw_colored_polygon(PackedVector2Array([
		root + side * half_width, tip, root - side * half_width,
	]), Color(tint.r, tint.g, tint.b, t * 0.3))
	draw_line(root, tip, Color(tint.r, tint.g, tint.b, minf(1.0, t + 0.3)), 4.0)
	draw_circle(tip, 5.5, Color(1.0, 1.0, 1.0, t * 0.95))
