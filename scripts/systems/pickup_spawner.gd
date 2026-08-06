extends Node2D

## 적이 죽은 자리에 픽업을 떨군다.
## 적이 픽업 씬을 직접 알지 않도록 EventBus 를 거친다(architecture.md 2절).

@export var xp_gem_scene: PackedScene

## 적 데이터에 xp_reward 가 없을 때 쓰는 기본값.
const FALLBACK_XP: int = 1


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)


## `[중요]` 젬을 **여기서 바로 만들지 않는다.**
## 적이 죽는 순간은 물리 콜백 한복판일 수 있다(투사체의 `_on_area_entered` → 데미지 → 사망).
## 그때 Area2D 인 젬을 트리에 붙이면 엔진이 "Can't change this state while flushing queries" 로
## 거부하고, **젬이 조용히 안 뜬다.** 부적 몸주만 레벨이 안 오르는 형태로 나타나서
## 밸런스 시뮬이 먼저 잡아냈다 — 플레이로는 "부적이 좀 약하네"로만 보였을 버그다.
##
## 값은 지금 읽는다. 적은 이 시그널 직후 풀에 반납되므로 한 프레임 뒤에는 남의 것이 되어 있다.
func _on_enemy_died(enemy: Node2D, world_position: Vector2) -> void:
	if xp_gem_scene == null:
		return
	var value := FALLBACK_XP
	if enemy != null and is_instance_valid(enemy):
		var data: EnemyData = enemy.get(&"data")
		if data != null:
			value = data.xp_reward
	_spawn_gem.call_deferred(world_position, value)


func _spawn_gem(world_position: Vector2, value: int) -> void:
	var gem := ObjectPool.acquire(xp_gem_scene, self)
	if gem == null:
		push_error("젬을 풀에서 꺼내지 못했다 — 처치 보상이 사라진다.")
		return
	gem.global_position = world_position
	gem.value = value
