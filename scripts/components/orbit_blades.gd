class_name OrbitBlades
extends Node2D

## 플레이어 주위를 도는 날. 언월도 본체이자, 합이 여는 궤도(궤도 작두·북두 방벽)의 공용 몸통이다.
## 어느 무기인지 모르게 만들어 두어 data 와 키만 갈아 끼우면 다른 궤도가 된다.
##
## 조준도 발동도 없는 "항상 켜져 있는 방어막"이라, 뒤에서 붙는 적을 신경 쓰지 않아도 되는 값을
## DPS 로 지불한다(design.md 2-5).

## 반경·속도·재타격·기본 damage·기본 count 의 출처.
@export var data: WeaponData
## 기본 damage 에 곱하는 비율. 합이 여는 궤도는 본체보다 약하게 둔다(예: 궤도 작두 0.6).
@export var damage_scale: float = 1.0
## 신 수정자에서 읽을 데미지 키(예: &"jakdu_damage_pct").
@export var damage_key: StringName
## 날 수를 키우는 신 수정자 키. 비우면 성장하지 않는다.
@export var count_mod_key: StringName
## data.count 대신 쓸 고정 날 수. 0 이면 data 를 따른다.
@export var base_count_override: int = 0
@export var blade_color: Color = Color(0.93, 0.93, 0.97, 0.9)
## 이 합이 열려야 동작한다. 비우면 소유자(플레이어)가 켜고 끈다.
@export var required_synergy: StringName

const FALLBACK_DAMAGE: float = 8.0
const FALLBACK_RADIUS: float = 70.0
const FALLBACK_SPEED: float = 2.0
const FALLBACK_REHIT: float = 0.5

## 날 하나의 판정 반지름. 도형 플레이스홀더 크기와 같다.
const BLADE_RADIUS: float = 10.0
const MAX_COUNT: int = 7

var god_system: Node

var _angle: float = 0.0
var _blades: Array[Area2D] = []
## { 적 인스턴스ID: 다시 때릴 수 있게 되는 시각(초) } — 같은 적을 매 프레임 갈지 않도록.
var _cooldowns: Dictionary = {}


## 날은 _ready 가 아니라 첫 활성 프레임에 만든다. 꺼져 있는 궤도는 PROCESS_MODE_DISABLED 라
## _process 가 돌지 않고, 따라서 판정도 존재하지 않는다.
## _ready 에서 만들면 열리지도 않은 궤도의 날이 원점에 남아 스치는 적을 때린다.
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


## 날 수가 바뀌면 통째로 다시 만든다. 최대 7개라 매번 지었다 허물어도 부담이 없다.
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
	_cooldowns[key] = now + _get_rehit_cooldown()

	if hurtbox.health != null:
		var result := DamageCalc.resolve(_get_base_damage(), god_system, damage_key, enemy)
		hurtbox.health.take_damage(result["amount"])
		if enemy.has_method(&"flash_hit"):
			enemy.call(&"flash_hit", result["is_crit"])
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


## 신 수정자·오행·치명은 DamageCalc 가 대상별로 처리한다.
func _get_base_damage() -> float:
	var base := data.base_damage if data != null else FALLBACK_DAMAGE
	return base * damage_scale


func _get_orbit_radius() -> float:
	return data.orbit_radius if data != null else FALLBACK_RADIUS


func _get_orbit_speed() -> float:
	return data.orbit_speed if data != null else FALLBACK_SPEED


func _get_rehit_cooldown() -> float:
	return data.rehit_cooldown if data != null else FALLBACK_REHIT


## 날 수는 정수라 레벨당 소수로 쌓은 뒤 내림한다(design.md 3-4).
func _get_count() -> int:
	var base := base_count_override
	if base <= 0:
		base = data.count if data != null else 2
	var grown := 0
	if count_mod_key != &"":
		grown = int(floorf(_god_add(count_mod_key)))
	return clampi(base + grown, 1, MAX_COUNT)


## 플레이스홀더 = 날. 회전이 눈에 보이도록 진행 방향으로 살짝 기울인다.
func _draw() -> void:
	for blade in _blades:
		var tangent := blade.position.orthogonal().normalized() * BLADE_RADIUS
		var points := PackedVector2Array([
			blade.position + tangent,
			blade.position + tangent.orthogonal() * 0.55,
			blade.position - tangent,
			blade.position - tangent.orthogonal() * 0.55,
		])
		draw_colored_polygon(points, blade_color)
