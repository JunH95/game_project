extends Node2D

## 화면 밖 링에서 적을 주기적으로 스폰한다.
## M1 슬라이스: 추격 적 1종 고정 레이트. 시간에 따른 램프·웨이브는 M5(WaveTable).

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
@export var spawn_interval: float = 1.0
@export var spawn_radius: float = 700.0
@export var max_alive: int = 200

var _target: Node2D
var _accum: float = 0.0


func _ready() -> void:
	_target = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_accum += delta
	while _accum >= spawn_interval:
		_accum -= spawn_interval
		_spawn_one()


func _spawn_one() -> void:
	if enemy_scene == null:
		return
	if get_tree().get_nodes_in_group(&"enemy").size() >= max_alive:
		return
	var enemy := enemy_scene.instantiate()
	enemy.data = enemy_data
	var angle := randf() * TAU
	enemy.global_position = _target.global_position + Vector2.from_angle(angle) * spawn_radius
	get_parent().add_child(enemy)
