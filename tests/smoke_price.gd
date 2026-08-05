extends Node

## 대가(代價) 시스템 스모크 테스트(design.md 3-7).
## 실행: godot --headless --path . res://tests/smoke_price.tscn
##
## 대가 5종 중 실제 데이터에 붙어 있는 것은 둘뿐이다(살·인간성). 나머지 셋은 로스터가
## 늘면 데이터로만 붙일 수 있어야 하는데, **쓰이지 않는 코드 경로는 조용히 썩는다.**
## 그래서 여기서는 GodData 를 코드로 만들어 다섯 종류를 전부 청구시킨다.
##
## main.tscn 을 자식으로 띄워 실제 배선을 그대로 쓴다 — 테스트가 게임과 다른 것을 재면
## 통과해도 의미가 없다.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const MAX_FRAMES: int = 600

var _frame: int = 0
var _main: Node
var _price_system: Node
var _god_system: Node
var _gate_timer: Node
var _hurtbox: HurtboxComponent
var _done: bool = false
var _failures: int = 0
var _paid_kinds: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene := load(MAIN_SCENE) as PackedScene
	if scene == null:
		_fail("main.tscn 을 불러오지 못했다.")
		_finish()
		return
	_main = scene.instantiate()
	add_child(_main)
	EventBus.price_paid.connect(_on_price_paid)


func _on_price_paid(kind: StringName, _god: GodData, detail: String) -> void:
	_paid_kinds.append(kind)
	if detail.is_empty():
		_fail("대가를 치렀는데 화면에 띄울 문구가 비었다: %s" % kind)


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < 4:
		return
	if not _resolve():
		if _frame > MAX_FRAMES:
			_fail("시스템 노드를 찾지 못했다.")
			_finish()
		return
	_run()
	_finish()


func _resolve() -> bool:
	if _price_system == null:
		_price_system = _main.get_node_or_null(^"%PriceSystem")
	if _god_system == null:
		_god_system = _main.get_node_or_null(^"%GodSystem")
	if _gate_timer == null:
		_gate_timer = _main.get_node_or_null(^"%GateTimer")
	if _hurtbox == null:
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null:
			_hurtbox = player.get_node_or_null(^"%HurtboxComponent") as HurtboxComponent
	return _price_system != null and _god_system != null and _gate_timer != null \
		and _hurtbox != null


func _run() -> void:
	_check_lifespan()
	_check_flesh()
	_check_soul()
	_check_humanity()
	_check_memory()
	_check_gentle_god_is_free()


## 수명 — 관문이 짧아지고, 적 난이도 진행도(RunManager)도 같이 당겨져야 한다.
func _check_lifespan() -> void:
	var before: float = _gate_timer.duration_sec
	_serve(_make_god(&"_t_lifespan", &"lifespan"))
	var after: float = _gate_timer.duration_sec
	if not (after < before):
		_fail("수명을 내줬는데 관문이 그대로다: %.1f -> %.1f" % [before, after])
	if not is_equal_approx(RunManager.gate_duration_sec, after):
		_fail("관문은 줄었는데 난이도 기준이 안 따라왔다(적이 덜 험해진다).")


## 살 — i-frame 이 짧아진다. 데미지는 건드리지 않는다(3-7-2: 파워를 직접 깎지 않는다).
func _check_flesh() -> void:
	var before := _hurtbox.invuln_time
	_serve(_make_god(&"_t_flesh", &"flesh"))
	if not (_hurtbox.invuln_time < before):
		_fail("살을 내줬는데 무적 시간이 그대로다: %.2f" % before)


## 넋 — 다음 신내림이 2택이 되고, 그 다음 신내림에서 3택으로 돌아온다.
func _check_soul() -> void:
	var base: int = _god_system.choice_count
	_serve(_make_god(&"_t_soul", &"soul"))
	if _god_system.choice_count != 2:
		_fail("넋을 내줬는데 선택지가 줄지 않았다: %d" % _god_system.choice_count)
	# 다음 신내림이 지나가면 회수된다.
	_serve(_make_god(&"_t_plain_a", &""))
	if _god_system.choice_count != base:
		_fail("넋 대가가 회수되지 않아 계속 2택이다: %d" % _god_system.choice_count)


## 인간성 — 지금은 아무것도 깎지 않는다. 대신 런에 남아 결말이 본다(5-0).
func _check_humanity() -> void:
	var before: int = RunManager.humanity_paid
	_serve(_make_god(&"_t_humanity", &"humanity"))
	if RunManager.humanity_paid != before + 1:
		_fail("인간성을 내줬는데 런에 기록되지 않았다: %d" % RunManager.humanity_paid)
	if _price_system.get_humanity_paid() != RunManager.humanity_paid:
		_fail("인간성 집계가 시스템과 런에서 어긋난다.")


## 기억 — 이미 모신 신 하나가 1레벨 준다. 잊을 것이 없으면 청구되지 않아야 한다.
func _check_memory() -> void:
	var before := _total_levels()
	_serve(_make_god(&"_t_memory", &"memory"))
	# 방금 모신 신이 +1 이고 기억이 −1 이라 합은 그대로여야 한다.
	if _total_levels() != before + 1 - 1:
		_fail("기억을 내줬는데 잊은 신이 없다: %d -> %d" % [before, _total_levels()])


## 순한 신은 아무것도 가져가지 않아야 한다. 여기서 무언가 줄면 대가가 새고 있는 것이다.
func _check_gentle_god_is_free() -> void:
	var gate: float = _gate_timer.duration_sec
	var iframe := _hurtbox.invuln_time
	var humanity: int = RunManager.humanity_paid
	_serve(_make_god(&"_t_plain_b", &""))
	if not is_equal_approx(_gate_timer.duration_sec, gate) \
			or not is_equal_approx(_hurtbox.invuln_time, iframe) \
			or RunManager.humanity_paid != humanity:
		_fail("순한 신을 모셨는데 대가가 청구됐다.")


func _total_levels() -> int:
	var total := 0
	for level: int in (_god_system.get_served() as Dictionary).values():
		total += level
	return total


## 테스트용 신. 로스터에 넣어야 GodSystem 이 집계에 포함한다.
func _make_god(id: StringName, price: StringName) -> GodData:
	var god := GodData.new()
	god.id = id
	god.display_name = String(id)
	god.element = &"earth"
	god.max_level = 5
	god.price_kind = price
	return god


func _serve(god: GodData) -> void:
	_god_system.available_gods.append(god)
	_god_system.serve(god)


func _fail(message: String) -> void:
	_failures += 1
	push_error("  - %s" % message)


func _finish() -> void:
	_done = true
	if _failures > 0:
		push_error("대가 스모크 실패 %d건" % _failures)
		get_tree().quit(1)
		return
	print("대가 스모크 통과 — 청구된 대가 %s" % [_paid_kinds])
	get_tree().quit(0)
