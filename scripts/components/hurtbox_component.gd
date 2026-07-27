class_name HurtboxComponent
extends Area2D

## 겹쳐 있는 HitboxComponent 로부터 데미지를 받아 연결된 HealthComponent 에 전달한다.
## 뱀서식 지속 접촉: 겹쳐 있는 동안 invuln_time 주기마다 데미지가 들어간다(i-frame).
## health 는 액터 스크립트가 _ready 에서 코드로 연결한다. 감지 대상은 씬의 레이어/마스크로 설정.

@export var health: HealthComponent
## 피격 후 무적 시간(i-frame). 겹침 지속 시 이 주기마다 다시 맞는다. 0 이면 매 프레임.
@export var invuln_time: float = 0.0

## 받는 피해 배율. 방어 계열 신(신장)이 이 값을 낮춘다. 소유 액터가 갱신한다.
var damage_multiplier: float = 1.0

var _invuln_left: float = 0.0
var _overlapping: Array[HitboxComponent] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(delta: float) -> void:
	if _invuln_left > 0.0:
		_invuln_left -= delta
		return
	if health == null or _overlapping.is_empty():
		return
	# 겹친 hitbox 중 가장 큰 데미지 하나를 적용하고 i-frame 을 시작한다.
	var dmg := 0.0
	for hitbox in _overlapping:
		if is_instance_valid(hitbox):
			dmg = maxf(dmg, hitbox.damage)
	if dmg > 0.0:
		health.take_damage(dmg * damage_multiplier)
		_invuln_left = invuln_time


func _on_area_entered(area: Area2D) -> void:
	var hitbox := area as HitboxComponent
	if hitbox != null and not _overlapping.has(hitbox):
		_overlapping.append(hitbox)


func _on_area_exited(area: Area2D) -> void:
	var hitbox := area as HitboxComponent
	if hitbox != null:
		_overlapping.erase(hitbox)
