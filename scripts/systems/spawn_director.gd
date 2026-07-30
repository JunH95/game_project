extends Node2D

## 화면 밖 링에서 적을 스폰한다.
## 시간이 갈수록 스폰율이 오르고(트리클), 주기적으로 무리가 한 방향에서 몰려온다(버스트).
## 밀도가 5분 내내 같으면 후반 압박이 생기지 않아, 램프와 버스트를 분리해 둔다.
##
## 관문별 배율·적 구성·시그니처 기믹은 GateData/WaveTable 로 옮긴다(M5).

@export var enemy_scene: PackedScene
## 기본 적(추격). 관문 내내 나온다.
@export var enemy_data: EnemyData

@export_group("적 구성")
## 러시형. 약하고 빠르다. 이 시각(초) 이후 섞여 나온다.
@export var rusher_data: EnemyData
@export var rusher_after_sec: float = 60.0
@export_range(0.0, 1.0) var rusher_ratio: float = 0.35
## 탱크형. 느리고 단단하다. 등장이 늦고 비율이 낮다 — 초반에 나오면 진행이 막힌다.
@export var tank_data: EnemyData
@export var tank_after_sec: float = 120.0
@export_range(0.0, 1.0) var tank_ratio: float = 0.12

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

@export_group("엘리트 (design.md 6-4)")
## 스킬을 가진 개체. 드물게 나와야 위협이 된다 — 흔하면 잡몹이고 화면이 안 읽힌다.
@export var elite_data: Array[EnemyData] = []
## 엘리트가 나오기 시작하는 시각과 주기(초).
@export var elite_after_sec: float = 45.0
@export var elite_interval: float = 38.0

@export_group("공통")
## 화면 밖 링의 반지름. 카메라 줌 1.6 에서 보이는 범위의 반대각선이 약 413px 이므로,
## 그보다 조금 밖에 둔다. 너무 멀면 적이 도착하기까지 화면이 비고, 너무 가까우면
## 눈앞에서 튀어나온다.
@export var spawn_radius: float = 460.0
@export var max_alive: int = 200

var _target: Node2D
var _elapsed: float = 0.0
## 스폰율이 소수라서 누적해 두고 1.0 을 넘을 때마다 한 마리씩 낸다.
var _spawn_accum: float = 0.0
var _burst_accum: float = 0.0
var _elite_accum: float = 0.0
## 엘리트를 돌아가며 낸다. 무작위면 같은 종류만 연달아 나오는 판이 생긴다.
var _elite_index: int = 0


func _ready() -> void:
	_target = get_tree().get_first_node_in_group("player")
	# 적이 부하를 부르거나 갈라질 때 실제로 만드는 것은 스포너다 —
	# 적이 직접 스폰하면 풀 관리가 두 곳으로 갈린다.
	EventBus.enemy_summon_requested.connect(_on_summon_requested)
	EventBus.enemy_split_requested.connect(_on_split_requested)


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

	if not elite_data.is_empty() and _elapsed >= elite_after_sec and elite_interval > 0.0:
		_elite_accum += delta
		while _elite_accum >= elite_interval:
			_elite_accum -= elite_interval
			_spawn_elite()


## 램프 진행도 0.0~1.0.
func _progress() -> float:
	if ramp_duration <= 0.0:
		return 1.0
	return clampf(_elapsed / ramp_duration, 0.0, 1.0)


func _current_rate() -> float:
	return lerpf(start_rate, end_rate, _progress())


## 버스트는 한 방향에 뭉쳐서 낸다. 사방에 고르게 뿌리면 트리클과 구분이 안 돼 "몰려온다"는 느낌이 죽는다.
## 한 버스트는 한 종류로 낸다 — 섞으면 "무엇이 몰려오는지"가 읽히지 않는다.
func _spawn_burst() -> void:
	var count := int(round(lerpf(float(burst_min), float(burst_max), _progress())))
	var base_angle := randf() * TAU
	var data := _pick_data()
	for i in count:
		_spawn_at(base_angle + randf_range(-0.6, 0.6), data)


## 엘리트는 한 마리씩만 낸다. 둘 이상이 동시에 스킬을 쓰면 무엇이 위험한지 안 읽힌다.
func _spawn_elite() -> void:
	var pool: Array[EnemyData] = []
	for candidate in elite_data:
		if candidate != null:
			pool.append(candidate)
	if pool.is_empty():
		return
	# 돌아가며 낸다. 무작위면 같은 종류만 연달아 나오는 판이 생긴다.
	var data := pool[_elite_index % pool.size()]
	_elite_index += 1
	_spawn_at(randf() * TAU, data)


## 신장 계열이 부하를 부른다. 플레이어 쪽이 아니라 **부른 적 주위**에 낸다 —
## 소환인데 화면 밖에서 걸어오면 소환으로 안 읽힌다.
func _on_summon_requested(world_position: Vector2, count: int) -> void:
	for i in count:
		var angle := TAU * float(i) / float(maxi(1, count)) + randf_range(-0.3, 0.3)
		_spawn_near(world_position + Vector2.from_angle(angle) * randf_range(28.0, 56.0),
			enemy_data)


## 갈라진 조각. 원래 자리에서 튀어나온다.
func _on_split_requested(world_position: Vector2, count: int, scale_mult: float) -> void:
	if rusher_data == null:
		return
	for i in count:
		var angle := TAU * float(i) / float(maxi(1, count))
		var spawned := _spawn_near(
			world_position + Vector2.from_angle(angle) * 18.0, rusher_data)
		# 조각은 작고 약하다. 원본과 같은 크기면 죽인 보람이 없다.
		if spawned != null:
			spawned.scale = Vector2.ONE * scale_mult


## 링이 아니라 지정한 자리에 낸다. 소환·분열처럼 위치가 의미를 가지는 경우에 쓴다.
func _spawn_near(world_position: Vector2, data: EnemyData) -> Node2D:
	if enemy_scene == null or data == null:
		return null
	if get_tree().get_nodes_in_group(&"enemy").size() >= max_alive:
		return null
	var enemy := ObjectPool.acquire(enemy_scene, get_parent())
	if enemy == null:
		return null
	enemy.global_position = world_position
	enemy.setup(data)
	return enemy


## 시간이 지나면 새 종류가 섞인다. 탱크는 늦게·드물게 — 초반에 나오면 진행이 막힌다.
func _pick_data() -> EnemyData:
	if tank_data != null and _elapsed >= tank_after_sec and randf() < tank_ratio:
		return tank_data
	if rusher_data != null and _elapsed >= rusher_after_sec and randf() < rusher_ratio:
		return rusher_data
	return enemy_data


func _spawn_at(angle: float, data: EnemyData = null) -> void:
	if enemy_scene == null:
		return
	if get_tree().get_nodes_in_group(&"enemy").size() >= max_alive:
		return
	var enemy := ObjectPool.acquire(enemy_scene, get_parent())
	if enemy == null:
		return
	# acquire 안에서 _pool_reset 이 이미 돌았으므로, data 교체는 setup 으로 다시 반영한다.
	enemy.setup(data if data != null else _pick_data())
	enemy.global_position = _target.global_position + Vector2.from_angle(angle) * spawn_radius
