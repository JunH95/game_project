class_name WeaponData
extends Resource

## 무기 1종의 데이터. data/weapons/*.tres 로 인스턴스화한다.
## 근접(작두)/원거리(부적)를 is_melee 로 구분하고, 각 형태에 맞는 필드만 사용한다.

@export var id: StringName
@export var display_name: String
@export var is_melee: bool = true

@export_group("Common")
@export var base_damage: float = 10.0
@export var cooldown: float = 0.8
@export var knockback: float = 120.0

@export_group("Melee (작두)")
## 사거리(px). GDScript 내장 range() 와 이름이 겹치면 값이 아니라 함수로 해석되므로 attack_range 로 둔다.
@export var attack_range: float = 90.0
@export var arc_degrees: float = 100.0

@export_group("Orbit (언월도)")
## 플레이어로부터의 공전 반경(px).
@export var orbit_radius: float = 70.0
## 공전 각속도(rad/s).
@export var orbit_speed: float = 2.0
## 같은 적을 다시 때리기까지의 간격(초). 없으면 접촉한 적이 즉사해 궤도의 의미가 사라진다.
@export var rehit_cooldown: float = 0.5

@export_group("Ranged (부적)")
@export var projectile_speed: float = 320.0
@export var homing_turn_rate: float = 4.0
@export var pierce: int = 1
@export var count: int = 1
@export var lifetime: float = 2.5

## 레벨별 스케일 규칙. 예: { "damage_per_level": 3, "cooldown_step": -0.1 }
@export var level_scale: Dictionary
