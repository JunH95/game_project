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

## step 은 창술 3연타의 몇 번째인지(0~2). 몸이 그에 맞는 자세를 잡는다.
signal swung(direction: Vector2, step: int)

@export var data: WeaponData

## data 가 없을 때 쓰는 기본값.
const FALLBACK_DAMAGE: float = 22.0
const FALLBACK_COOLDOWN: float = 1.4
const FALLBACK_RANGE: float = 115.0
const FALLBACK_KNOCKBACK: float = 160.0

const MIN_COOLDOWN: float = 0.45
## 한 바퀴 도는 데 걸리는 시간. 판정은 즉발이고 이건 연출 길이다.
const SWEEP_TIME: float = 0.26

## 창술 3연타 — 횡소(橫掃) → 역횡소 → 자돌(刺突).
## `[핵심]` 1타와 2타는 **도는 방향이 반대**다. 같은 방향으로 세 번 돌리면 각도를 아무리 바꿔도
## "같은 동작 세 번"으로 보인다(작두 연타를 만들면서 배운 것).
## 3타는 사방 베기를 버리고 **앞으로만 깊게** 찌른다 — 창술의 결정타는 원이 아니라 직선이다.
const STEP_COUNT: int = 3
## 마무리 찌르기는 멀리 닿는 대신 좁다. 총량으로는 넓게 세 번 도는 것보다 손해지만,
## 그 손해가 3연타를 **선택이 아니라 리듬**으로 만든다.
const STEP_RANGE_MULT: Array[float] = [1.0, 1.0, 1.5]
## 판정 각도(도). 앞의 둘은 사방이고 마지막만 좁아진다.
const STEP_ARC_DEG: Array[float] = [360.0, 360.0, 80.0]

## 신내림 수정자를 물어볼 GodSystem. 없으면 기본 수치로 동작한다.
var god_system: Node

var _cooldown_left: float = 0.0
var _sweep_left: float = 0.0
## 이번 휘두름이 시작된 각. 여기서부터 한 바퀴 돈다.
var _sweep_from: float = 0.0
## 창술 연타의 몇 번째 타인지.
var _step: int = 0


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
	_step = (_step + 1) % STEP_COUNT
	var direction := (target.global_position - global_position).normalized()
	_sweep_from = direction.angle()
	_sweep_left = SWEEP_TIME
	_sweep(direction)
	AudioManager.play(&"jakdu_swing")
	swung.emit(direction, _step)
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


## 반경 안의 적을 벤다. 사방을 도는 두 타는 각도 검사가 없고(작두와의 차이),
## 마무리 찌르기만 앞쪽으로 좁힌다.
func _sweep(direction: Vector2) -> void:
	var reach := _step_range()
	var reach_sq := reach * reach
	var damage := _get_base_damage()
	var knockback := _get_knockback()
	var arc := _step_arc_degrees()
	# 반각과 비교하려고 코사인으로 바꿔 둔다. 360 도면 -1 이라 모든 적이 통과한다.
	var half_arc_cos := cos(deg_to_rad(arc * 0.5))

	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - global_position
		if offset.length_squared() > reach_sq:
			continue
		if arc < 360.0 and not offset.is_zero_approx() 				and direction.dot(offset.normalized()) < half_arc_cos:
			continue
		_hit(enemy, damage, knockback, offset)


func _hit(enemy: Node2D, damage: float, knockback: float, offset: Vector2) -> void:
	var health := enemy.get_node_or_null(^"%HealthComponent") as HealthComponent
	if health == null:
		push_error("적에 HealthComponent 가 없어 언월도 데미지를 넣지 못했다: %s" % enemy.name)
		return
	var result := DamageCalc.resolve(damage, god_system, &"eonwoldo_damage_pct", enemy)
	health.take_damage(result["amount"])
	EventBus.damage_dealt.emit(enemy.global_position, result["amount"], result["is_crit"],
		&"eonwoldo")
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


func _step_range() -> float:
	return _get_range() * STEP_RANGE_MULT[clampi(_step, 0, STEP_RANGE_MULT.size() - 1)]


func _step_arc_degrees() -> float:
	return STEP_ARC_DEG[clampi(_step, 0, STEP_ARC_DEG.size() - 1)]


## 한 바퀴 도는 큰 호. 작두의 부채꼴과 달리 **원 전체**가 판정이라 그대로 보여 준다.
##
## 창술로 읽히게 하는 것은 잔상이 아니라 **자루**다. 호만 그리면 충격파가 퍼지는 것처럼 보이고
## 손에 장병기를 쥐고 돌린다는 사실이 사라진다. 그래서 매 프레임 원점에서 날까지 이어진
## 자루를 같이 그린다 — 회전의 중심이 몸이라는 것이 이 선 하나로 읽힌다.
func _draw() -> void:
	if _sweep_left <= 0.0:
		return
	var t := _sweep_left / SWEEP_TIME
	if _step == 2:
		_draw_thrust(t)
	else:
		_draw_sweep(t)


## 횡소 / 역횡소. **2타는 반대로 돈다** — 3연타가 눈에 보이는 곳이 여기다.
func _draw_sweep(t: float) -> void:
	var reach := _step_range()
	var color := Color(0.95, 0.93, 0.86, t * 0.85)
	# 남은 시간만큼 호가 짧아진다 — 날이 지나간 자리가 뒤로 사라지는 것처럼 보인다.
	var spin := -1.0 if _step == 1 else 1.0
	var swept := TAU * (1.0 - t) * spin

	# 지나간 자리 — 굵은 띠. 오목 폴리곤을 피하려고 draw_arc 의 width 를 쓴다(9-1).
	draw_arc(Vector2.ZERO, reach * 0.82, _sweep_from, _sweep_from + swept, 40,
		Color(color.r, color.g, color.b, t * 0.30), reach * 0.34)
	# 날 끝 — 지금 어디를 지나는지.
	draw_arc(Vector2.ZERO, reach, _sweep_from, _sweep_from + swept, 40, color, 3.0)

	var dir := Vector2.from_angle(_sweep_from + swept)
	_draw_polearm(dir, reach, t, spin)


## 자돌(刺突) — 창술의 결정타. 돌지 않고 **앞으로 뻗는다.**
## 원을 그리다가 갑자기 직선이 나와야 마무리로 읽힌다.
func _draw_thrust(t: float) -> void:
	var reach := _step_range()
	var dir := Vector2.from_angle(_sweep_from)
	var side := dir.orthogonal()
	# 처음(t=1)에 몸 가까이, 끝(t=0)에 끝까지 뻗는다.
	var extend := lerpf(0.45, 1.0, 1.0 - t)
	var tip := dir * (reach * extend)
	# 찌른 길 — 가늘고 긴 마름모. 부채꼴이 아니라 선이라 방향이 즉시 읽힌다.
	var width := reach * 0.10 * t
	draw_colored_polygon(PackedVector2Array([
		dir * (reach * 0.2), tip * 0.72 + side * width,
		tip, tip * 0.72 - side * width,
	]), Color(0.95, 0.93, 0.86, t * 0.34))
	_draw_polearm(dir, reach * extend, t, 1.0)


## 자루와 초승달 날. 창술로 읽히게 하는 것은 잔상이 아니라 **자루**다 —
## 호만 그리면 충격파가 퍼지는 것처럼 보이고, 손에 장병기를 쥐고 있다는 사실이 사라진다.
func _draw_polearm(dir: Vector2, reach: float, t: float, spin: float) -> void:
	var tip := dir * reach
	# 자루는 뒤쪽으로도 조금 삐져나온다 — 자루 끝이 몸 반대편에 있어야 장병기로 보인다.
	draw_line(-dir * (reach * 0.22), tip * 0.9, Color(0.42, 0.33, 0.26, t * 0.95), 5.0)
	# 초승달 날 — 자루 끝에 옆으로 휘어 붙는다. 언월(偃月)이 이름의 근거다.
	# 도는 방향을 따라 날도 뒤집힌다. 안 뒤집으면 역횡소에서 날등으로 베는 그림이 된다.
	var side := dir.orthogonal() * spin
	draw_colored_polygon(PackedVector2Array([
		tip * 0.88, tip + side * (reach * 0.20), tip + dir * (reach * 0.10),
	]), Color(0.92, 0.94, 1.0, minf(1.0, t + 0.2)))
	draw_circle(tip, 4.0, Color(1.0, 1.0, 1.0, t * 0.9))
