extends Node2D

## 화면 밖 링에서 적을 스폰한다.
## 시간이 갈수록 스폰율이 오르고(트리클), 주기적으로 무리가 한 방향에서 몰려온다(버스트).
## 밀도가 5분 내내 같으면 후반 압박이 생기지 않아, 램프와 버스트를 분리해 둔다.
##
## 관문별 배율·적 구성·시그니처 기믹은 GateData/WaveTable 로 옮긴다(M5).

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData

@export_group("스폰 램프")
## 관문 시작 시점의 초당 스폰 수.
@export var start_rate: float = 1.0
## 램프가 끝나는 시점의 초당 스폰 수.
@export var end_rate: float = 6.0
## 이 시간에 걸쳐 start_rate 에서 end_rate 로 오른다. 관문 길이와 맞춘다.
@export var ramp_duration: float = 300.0

@export_group("버스트")
## 무리가 몰려오는 주기(초). 0 이하면 버스트를 쓰지 않는다.
@export var burst_interval: float = 30.0
## 버스트 1회의 마리 수. 램프 진행도에 따라 min 에서 max 로 보간한다.
@export var burst_min: int = 4
@export var burst_max: int = 20

@export_group("공통")
@export var spawn_radius: float = 700.0
@export var max_alive: int = 200

var _target: Node2D
var _elapsed: float = 0.0
## 스폰율이 소수라서 누적해 두고 1.0 을 넘을 때마다 한 마리씩 낸다.
var _spawn_accum: float = 0.0
var _burst_accum: float = 0.0


func _ready() -> void:
	_target = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_elapsed += delta

	_spawn_accum += _current_rate() * delta
	while _spawn_accum >= 1.0:
		_spawn_accum -= 1.0
		_spawn_at(randf() * TAU)

	if burst_interval > 0.0:
		_burst_accum += delta
		while _burst_accum >= burst_interval:
			_burst_accum -= burst_interval
			_spawn_burst()


## 램프 진행도 0.0~1.0.
func _progress() -> float:
	if ramp_duration <= 0.0:
		return 1.0
	return clampf(_elapsed / ramp_duration, 0.0, 1.0)


func _current_rate() -> float:
	return lerpf(start_rate, end_rate, _progress())


## 버스트는 한 방향에 뭉쳐서 낸다. 사방에 고르게 뿌리면 트리클과 구분이 안 돼 "몰려온다"는 느낌이 죽는다.
func _spawn_burst() -> void:
	var count := int(round(lerpf(float(burst_min), float(burst_max), _progress())))
	var base_angle := randf() * TAU
	for i in count:
		_spawn_at(base_angle + randf_range(-0.6, 0.6))


func _spawn_at(angle: float) -> void:
	if enemy_scene == null:
		return
	if get_tree().get_nodes_in_group(&"enemy").size() >= max_alive:
		return
	var enemy := ObjectPool.acquire(enemy_scene, get_parent())
	if enemy == null:
		return
	# acquire 안에서 _pool_reset 이 이미 돌았으므로, data 교체는 setup 으로 다시 반영한다.
	enemy.setup(enemy_data)
	enemy.global_position = _target.global_position + Vector2.from_angle(angle) * spawn_radius
