extends Node2D

## 적이 죽은 자리에 픽업을 떨군다.
## 적이 픽업 씬을 직접 알지 않도록 EventBus 를 거친다(architecture.md 2절).

@export var xp_gem_scene: PackedScene


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Node2D, world_position: Vector2) -> void:
	if xp_gem_scene == null:
		return
	var gem := xp_gem_scene.instantiate()
	gem.global_position = world_position
	# 시그널은 queue_free 직전에 오므로 이 시점의 적은 아직 유효하다.
	if enemy != null and is_instance_valid(enemy):
		var data: EnemyData = enemy.get(&"data")
		if data != null:
			gem.value = data.xp_reward
	add_child(gem)
