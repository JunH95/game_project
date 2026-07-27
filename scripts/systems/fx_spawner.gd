extends Node2D

## 연출 전담. 타격·처치 이벤트를 받아 데미지 숫자·파편을 띄우고 히트스톱·셰이크를 요청한다.
## 무기·적이 연출을 직접 호출하면 무기를 더할 때마다 빠뜨리므로 여기 하나로 모은다
## (architecture.md 2절의 디커플링 규칙).

@export var damage_number_scene: PackedScene
@export var death_burst_scene: PackedScene

## 치명일 때만 화면을 흔든다. 평타마다 흔들면 멀미가 나고 치명의 특별함도 사라진다.
const CRIT_HITSTOP: float = 0.055
const CRIT_SHAKE: float = 5.0
const CRIT_SHAKE_TIME: float = 0.16
## 강림·합처럼 큰 순간은 더 크게.
const BIG_HITSTOP: float = 0.12
const BIG_SHAKE: float = 11.0
const BIG_SHAKE_TIME: float = 0.35

## 평타에도 아주 짧게 시간을 씹어야 "맞았다"가 손에 온다. 셰이크는 여기에 붙이지 않는다
## (14-1: 평타마다 흔들면 멀미가 난다) — 흔들지 않고 멈추기만 한다.
const HIT_HITSTOP: float = 0.018
## 한 번에 여러 마리를 벨수록 조금 더 씹힌다. 상한이 없으면 무리 한가운데서 화면이 정지한다.
const HIT_HITSTOP_PER_EXTRA: float = 0.004
const HIT_HITSTOP_MAX: float = 0.042

## 체력이 줄었는지 판정하려고 직전 값을 들고 있는다.
var _last_hp: float = 0.0
## 같은 프레임에 들어온 타격 수. damage_dealt 는 맞은 적마다 오므로 부채꼴 한 번에 수십 번
## 올 수 있고, 그때마다 히트스톱을 걸면 화면이 멎는다. 프레임당 한 번으로 묶는다.
var _frame_hits: int = 0


func _ready() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.taegi_state_changed.connect(_on_taegi_state_changed)
	EventBus.synergy_formed.connect(_on_synergy_formed)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	# 씬을 다시 열면 이전 런의 시간 배율·셰이크가 남을 수 있다.
	GameFeel.reset()


func _on_damage_dealt(world_position: Vector2, amount: float, is_crit: bool) -> void:
	if damage_number_scene != null:
		var number := ObjectPool.acquire(damage_number_scene, self)
		if number != null:
			# 적 머리 위에서 뜨게 살짝 올린다.
			number.global_position = world_position + Vector2(0.0, -14.0)
			number.setup(amount, is_crit)
	_frame_hits += 1
	if is_crit:
		GameFeel.hitstop(CRIT_HITSTOP)
		GameFeel.shake(CRIT_SHAKE, CRIT_SHAKE_TIME)


## 프레임이 끝날 때 그 프레임의 타격을 한 번으로 묶어 씹는다.
## GameFeel.hitstop 은 더 센 요청이 이기므로 치명이 섞여 있으면 치명 쪽이 그대로 남는다.
func _process(_delta: float) -> void:
	if _frame_hits <= 0:
		return
	var extra := float(_frame_hits - 1) * HIT_HITSTOP_PER_EXTRA
	GameFeel.hitstop(minf(HIT_HITSTOP + extra, HIT_HITSTOP_MAX))
	_frame_hits = 0


func _on_enemy_died(enemy: Node2D, world_position: Vector2) -> void:
	if death_burst_scene == null:
		return
	var burst := ObjectPool.acquire(death_burst_scene, self)
	if burst == null:
		return
	burst.global_position = world_position
	# 시그널은 반납 직전에 오므로 이 시점의 적 데이터는 아직 유효하다.
	var color := Color(0.85, 0.16, 0.16)
	var size := 8.0
	if enemy != null and is_instance_valid(enemy):
		var data: EnemyData = enemy.get(&"data")
		if data != null:
			color = data.placeholder_color
			size = data.radius
	burst.setup(color, size)


func _on_taegi_state_changed(active: bool) -> void:
	if active:
		GameFeel.hitstop(BIG_HITSTOP)
		GameFeel.shake(BIG_SHAKE, BIG_SHAKE_TIME)


func _on_synergy_formed(_synergy: SynergyData) -> void:
	GameFeel.shake(BIG_SHAKE * 0.7, BIG_SHAKE_TIME)


## 맞은 것도 몸으로 느껴져야 한다. 피격은 치명보다 약하게 흔든다.
func _on_player_health_changed(current: float, _maximum: float) -> void:
	if current < _last_hp:
		GameFeel.shake(4.0, 0.14)
	_last_hp = current
