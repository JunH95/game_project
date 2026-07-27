class_name EonwoldoWeapon
extends Node2D

## 언월도 — 플레이어 주위를 상시 도는 날. 조준도 발동도 없는 "항상 켜져 있는 방어막"이다(design.md 2-5).
## 뒤에서 붙는 적을 신경 쓰지 않아도 되는 값을 DPS 로 지불한다.
##
## 날은 최대 6개라 풀링 대상이 아니다. 날 수가 바뀔 때만 다시 만든다.

@export var data: WeaponData

const FALLBACK_DAMAGE: float = 8.0
const FALLBACK_RADIUS: float = 70.0
const FALLBACK_SPEED: float = 2.0
const FALLBACK_RETRIGGER: float = 0.5

## 날 하나의 판정 반지름. 도형 플레이스홀더 크기와 같다.
const BLADE_RADIUS: float = 10.0
const MAX_COUNT: int = 6

var god_system: Node

var _angle: float = 0.0
var _blades: Array[Area2D] = []
## { 적 인스턴스ID: 다시 때릴 수 있게 되는 시각(초) } — 같은 적을 매 프레임 갈지 않도록.
var _cooldowns: Dictionary = {}


## 날은 _ready 가 아니라 첫 활성 프레임에 만든다. 몸주가 언월도를 주지 않았으면 이 노드는
## PROCESS_MODE_DISABLED 라 _process 가 돌지 않고, 따라서 판정도 존재하지 않는다.
## _ready 에서 만들면 꺼진 무기의 날이 원점에 남아 스치는 적을 때린다.
func _process(delta: float) -> void:
	var count := _get_count()
	if count != _blades.size():
		_rebuild_blades(count)

	_angle = wrapf(_angle + _get_orbit_speed() * delta, 0.0, TAU)
	var radius := _get_orbit_radius()
	var step := TAU / float(maxi(1, _blades.size()))
	for i in _blades.size():
		_blades[i].position = Vector2.from_angle(_angle + step * float(i)) * radius

	_expire_cooldowns()
	queue_redraw()


## 날 수가 바뀌면 통째로 다시 만든다. 최대 6개라 매번 지었다 허물어도 부담이 없다.
func _rebuild_blades(count: int) -> void:
	for blade in _blades:
		blade.queue_free()
	_blades.clear()

	for i in count:
		var blade := Area2D.new()
		# 부적과 같은 계약: player_hitbox 레이어에서 enemy_hurtbox 를 감지한다(design.md 13절).
		blade.collision_layer = 32
		blade.collision_mask = 16
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = BLADE_RADIUS
		shape.shape = circle
		blade.add_child(shape)
		blade.area_entered.connect(_on_blade_area_entered)
		add_child(blade)
		_blades.append(blade)


func _on_blade_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	var enemy := hurtbox.get_parent()
	if enemy == null:
		return
	var key := enemy.get_instance_id()
	var now := _now()
	if float(_cooldowns.get(key, -1.0)) > now:
		return
	_cooldowns[key] = now + _get_retrigger()

	if hurtbox.health != null:
		hurtbox.health.take_damage(_get_damage())
	var knockback: float = (data.knockback if data != null else 0.0) * _god_mult(&"knockback_pct")
	if knockback > 0.0 and enemy.has_method(&"apply_knockback"):
		var push: Vector2 = (enemy.global_position - global_position).normalized()
		enemy.call(&"apply_knockback", push * knockback)


## 죽은 적의 쿨다운이 계속 쌓이면 딕셔너리가 무한히 커진다.
func _expire_cooldowns() -> void:
	var now := _now()
	for key in _cooldowns.keys():
		if float(_cooldowns[key]) <= now:
			_cooldowns.erase(key)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _god_mult(key: StringName) -> float:
	return god_system.get_multiplier(key) if god_system != null else 1.0


func _god_add(key: StringName) -> float:
	return god_system.get_mod(key) if god_system != null else 0.0


func _get_damage() -> float:
	var base := data.base_damage if data != null else FALLBACK_DAMAGE
	return base * _god_mult(&"eonwoldo_damage_pct")


func _get_orbit_radius() -> float:
	return data.orbit_radius if data != null else FALLBACK_RADIUS


func _get_orbit_speed() -> float:
	return data.orbit_speed if data != null else FALLBACK_SPEED


func _get_retrigger() -> float:
	return data.retrigger_cooldown if data != null else FALLBACK_RETRIGGER


## 날 수는 정수라 레벨당 소수로 쌓은 뒤 내림한다(design.md 3-4).
func _get_count() -> int:
	var base := data.count if data != null else 2
	return clampi(base + int(floorf(_god_add(&"eonwoldo_count"))), 1, MAX_COUNT)


## 플레이스홀더 = 흰 날. 회전이 눈에 보이도록 진행 방향으로 살짝 기울인다.
func _draw() -> void:
	for blade in _blades:
		var tangent := blade.position.orthogonal().normalized() * BLADE_RADIUS
		var points := PackedVector2Array([
			blade.position + tangent,
			blade.position + tangent.orthogonal() * 0.55,
			blade.position - tangent,
			blade.position - tangent.orthogonal() * 0.55,
		])
		draw_colored_polygon(points, Color(0.93, 0.93, 0.97, 0.9))
