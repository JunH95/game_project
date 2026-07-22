class_name HealthComponent
extends Node

## 체력을 소유·관리하는 재사용 컴포넌트(플레이어·적·보스 공용).
## 데미지는 take_damage 로만 들어오고, 죽음/변화는 시그널로 알린다.

signal died
signal health_changed(current: float, maximum: float)

@export var max_hp: float = 100.0

var hp: float


func _ready() -> void:
	hp = max_hp


## 최대 체력을 다시 설정(데이터 구동 적처럼 런타임에 스탯을 주입할 때).
func setup(new_max_hp: float) -> void:
	max_hp = new_max_hp
	hp = new_max_hp


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()


func is_alive() -> bool:
	return hp > 0.0
