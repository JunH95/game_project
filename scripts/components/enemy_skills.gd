class_name EnemySkills
extends Node2D

## 적의 특수 능력(design.md 6-4). `EnemyData.skills` 가 키만 들고 동작은 여기가 구현한다 —
## 무기가 `WeaponData` 를 읽는 것과 같은 구조라, 새 스킬은 `match` 한 갈래 + 데이터 한 줄이면 된다.
##
## **잡귀에게는 스킬을 주지 않는다.** 화면에 스킬이 열 개씩 터지면 무엇이 위험한지 안 읽힌다.
## `rank` 가 minion 이면 이 노드는 아예 돌지 않는다.
##
## 그리는 것도 여기서 한다. 스킬은 전부 **예고가 먼저** 떠야 한다 — 피할 수 없는 공격은
## 난이도가 아니라 불공정이다.

## 결박 — `[고증]` 저승사자가 "성명 삼자를 부르고 쇠사슬로 결박한다"(lore.md 5-3).
const TETHER_RANGE: float = 190.0
const TETHER_TIME: float = 2.2
## 묶인 동안의 이동 배율. 0 이면 완전 정지라 억울하다 — 느려지되 벗어날 수는 있어야 한다.
const TETHER_SLOW: float = 0.45
## 이 거리를 넘기면 사슬이 끊긴다. 도망칠 여지를 남긴다.
const TETHER_BREAK: float = 260.0

## 급살 — `[고증]` 급살사자. 예고선이 먼저 뜨고 그 다음에 돌진한다.
const LUNGE_TELEGRAPH: float = 0.75
const LUNGE_TIME: float = 0.35
const LUNGE_SPEED: float = 620.0
const LUNGE_RANGE: float = 320.0

## 분열 — 죽으면 작은 것 둘로 갈라진다. 광역으로 한 번에 정리하라는 신호다.
const SPLIT_COUNT: int = 2
const SPLIT_SCALE: float = 0.6

var data: EnemyData

var _enemy: CharacterBody2D
var _movement: MovementComponent
var _target: Node2D
var _cooldown: float = 0.0
## 지금 쓰고 있는 스킬과 남은 시간. 하나씩만 쓴다 — 동시에 여러 개면 읽히지 않는다.
var _active: StringName = &""
var _phase_left: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	_enemy = get_parent() as CharacterBody2D
	if _enemy == null:
		push_error("EnemySkills 는 CharacterBody2D 의 자식이어야 한다.")
		return
	_movement = _enemy.get_node_or_null(^"%MovementComponent") as MovementComponent


## 적이 풀에서 꺼내질 때 호출한다. 이전 개체의 스킬 상태가 남으면 엉뚱한 것이 발동한다.
func reset(new_data: EnemyData) -> void:
	data = new_data
	_cancel()
	_cooldown = data.skill_cooldown * 0.5 if data != null else 0.0
	set_process(_has_skills())
	queue_redraw()


func _has_skills() -> bool:
	return data != null and data.rank != "minion" and not data.skills.is_empty()


## 처치 시 적이 호출한다. 분열처럼 죽는 순간에만 의미가 있는 스킬을 여기서 처리한다.
func on_died() -> void:
	if not _has_skills() or not data.skills.has(&"split"):
		return
	_split()


func _process(delta: float) -> void:
	if not _has_skills():
		return
	_resolve_target()
	if _target == null:
		_cancel()
		return

	if _active != &"":
		_tick_active(delta)
		return

	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_try_cast()


func _resolve_target() -> void:
	if _target != null and is_instance_valid(_target):
		return
	_target = get_tree().get_first_node_in_group(&"player")


func _try_cast() -> void:
	var distance := _enemy.global_position.distance_to(_target.global_position)
	for key: StringName in data.skills:
		match key:
			&"tether":
				if distance <= TETHER_RANGE:
					# 전용 효과음이 생기기 전까지는 소리를 내지 않는다.
					# 엉뚱한 소리(강림음 등)를 빌려 쓰면 그 소리의 의미가 흐려진다.
					_begin(&"tether", TETHER_TIME)
					return
			&"lunge":
				if distance <= LUNGE_RANGE:
					_lunge_dir = (_target.global_position - _enemy.global_position).normalized()
					_begin(&"lunge", LUNGE_TELEGRAPH)
					return
			&"summon":
				_begin(&"summon", 0.35)
				return
			&"split":
				pass  # 죽을 때만 쓰인다(on_died)
			_:
				push_warning("알 수 없는 적 스킬 키: %s" % key)


func _begin(key: StringName, duration: float) -> void:
	_active = key
	_phase_left = duration
	queue_redraw()


func _tick_active(delta: float) -> void:
	# 돌진 실행 단계는 _physics_process 가 시간을 센다. 여기서도 깎으면 이중으로 줄어
	# 돌진이 설계한 절반 길이가 된다.
	if _active == &"lunge_go":
		return
	_phase_left -= delta
	queue_redraw()

	match _active:
		&"tether":
			_tick_tether()
		&"lunge":
			_tick_lunge(delta)
		&"summon":
			if _phase_left <= 0.0:
				_summon()
				_end()

	if _phase_left <= 0.0 and _active == &"tether":
		_end()


func _tick_tether() -> void:
	var distance := _enemy.global_position.distance_to(_target.global_position)
	# 멀리 달아나면 사슬이 끊긴다. 완전히 묶어 두면 난이도가 아니라 억울함이 된다.
	if distance > TETHER_BREAK:
		_end()
		return
	_apply_player_slow(TETHER_SLOW)


func _tick_lunge(delta: float) -> void:
	if _phase_left > 0.0:
		return
	# 예고가 끝나면 그 방향으로 튀어나간다. 방향은 예고 시점에 고정 — 예고선을 피하면 피해진다.
	if _active == &"lunge":
		_active = &"lunge_go"
		_phase_left = LUNGE_TIME
		return


func _apply_player_slow(multiplier: float) -> void:
	var movement := _target.get_node_or_null(^"%MovementComponent") as MovementComponent
	if movement != null:
		movement.external_multiplier = multiplier


func _clear_player_slow() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var movement := _target.get_node_or_null(^"%MovementComponent") as MovementComponent
	if movement != null:
		movement.external_multiplier = 1.0


func _summon() -> void:
	# `[고증]` 신장이 잡귀를 부린다(lore.md 3-2). 부하는 스포너가 만들게 하고 여기서는 알리기만 한다.
	EventBus.enemy_summon_requested.emit(_enemy.global_position, 3)


func _split() -> void:
	EventBus.enemy_split_requested.emit(_enemy.global_position, SPLIT_COUNT, SPLIT_SCALE)


func _cancel() -> void:
	_clear_player_slow()
	_active = &""
	_phase_left = 0.0
	queue_redraw()


func _end() -> void:
	_clear_player_slow()
	_active = &""
	_cooldown = data.skill_cooldown if data != null else 4.0
	queue_redraw()


## 물리 프레임에 돌진을 밀어 넣는다. 이동 컴포넌트를 거치지 않는 이유는
## 돌진 중에는 추격 방향을 무시해야 하기 때문이다.
func _physics_process(delta: float) -> void:
	if _active != &"lunge_go":
		return
	_phase_left -= delta
	_enemy.velocity = _lunge_dir * LUNGE_SPEED
	_enemy.move_and_slide()
	if _phase_left <= 0.0:
		_end()


## 예고와 사슬을 그린다. 스킬은 보이지 않으면 없는 것이다.
func _draw() -> void:
	if _active == &"":
		return
	match _active:
		&"tether":
			if _target == null or not is_instance_valid(_target):
				return
			var to_player := to_local(_target.global_position)
			# 사슬은 마디로 그린다. 직선 하나면 조준선처럼 보여 무엇인지 안 읽힌다.
			var links := 9
			for i in links:
				var t := float(i) / float(links)
				var point := to_player * t
				draw_circle(point, 2.6, Color(0.72, 0.70, 0.62, 0.85))
			draw_line(Vector2.ZERO, to_player, Color(0.85, 0.78, 0.55, 0.35), 1.5)
		&"lunge":
			# 예고선 — 시간이 갈수록 진해진다. 언제 터지는지가 색으로 읽혀야 한다.
			var heat := 1.0 - clampf(_phase_left / LUNGE_TELEGRAPH, 0.0, 1.0)
			var reach := _lunge_dir * LUNGE_SPEED * LUNGE_TIME
			draw_line(Vector2.ZERO, reach,
				Color(PlaceholderArt.JUSA.r, PlaceholderArt.JUSA.g, PlaceholderArt.JUSA.b,
					0.25 + heat * 0.55), 6.0 + heat * 6.0)
		&"summon":
			var pulse := 1.0 - clampf(_phase_left / 0.35, 0.0, 1.0)
			draw_arc(Vector2.ZERO, 26.0 + pulse * 30.0, 0.0, TAU, 24,
				Color(0.55, 0.42, 0.78, 0.7 * (1.0 - pulse)), 3.0)
