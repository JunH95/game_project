extends Node

## 대가(代價) — 신을 모시는 값(design.md 3-7).
##
## **얻기만 하는 선택은 가볍다.** 이게 없으면 3택1이 "뭐가 제일 센가"로 납작해지고,
## 이 게임의 첫 문장("대가를 치르고 신을 모신다")이 게임 안에 존재하지 않게 된다.
##
## `[중요]` 대가는 **파워를 직접 깎지 않는다**(3-7-2). 데미지·범위·발수·속도를 줄이면
## 강해지는 감각에 브레이크가 걸리고, 값을 부르는 신을 **피하는 것이 최적**이 된다.
## 가져가는 것은 **안전마진과 시간**이다 — "강해지지만 약해진다"가 아니라
## "강해지지만 위태로워진다".
##
## 대가는 신을 모실 때마다 다시 청구된다. 첫 레벨에만 받으면 2레벨부터는
## 공짜로 세지는 신이 되어 결국 "한 번 물고 계속 먹는" 것이 최적이 된다.

## 수명 — 관문 제한시간을 이만큼 깎는다(초).
const LIFESPAN_SEC: float = 20.0
## 살 — i-frame 을 이만큼 줄인다. 0 이 되면 접촉 즉시 연타로 죽으므로 바닥을 둔다.
const FLESH_IFRAME_STEP: float = 0.15
const FLESH_IFRAME_FLOOR: float = 0.2
## 넋 — 다음 레벨업의 선택지 수. 3 → 2.
const SOUL_CHOICE_COUNT: int = 2
## 관문이 이보다 짧아지지는 않는다. 수명을 계속 내주다 즉시 종료되는 것을 막는다.
const GATE_FLOOR_SEC: float = 60.0

@export var god_system_path: NodePath
@export var gate_timer_path: NodePath
@export var player_path: NodePath

var _god_system: Node
var _gate_timer: Node
var _hurtbox: HurtboxComponent

## 치른 대가의 총 횟수. HUD 가 "지금 어느 결말 쪽으로 가고 있는지" 보여 주는 근거다.
var _paid_total: int = 0
## 인간성만 따로 센다. 다른 넷은 수치지만 이건 **결말을 바꾼다**(design.md 5-0).
var _humanity_paid: int = 0
## 넋을 내주어 다음 선택지가 줄어 있는 상태인지. 다음 신내림에서 회수한다.
var _soul_debt: bool = false
## 3택으로 되돌릴 원래 값. 인스펙터에서 바꿔 뒀을 수 있으므로 상수로 쓰지 않는다.
var _base_choice_count: int = 3


func _ready() -> void:
	_god_system = get_node_or_null(god_system_path)
	if _god_system == null:
		push_error("PriceSystem: GodSystem 을 찾지 못해 대가를 청구할 수 없다.")
		return
	_base_choice_count = int(_god_system.choice_count)
	_gate_timer = get_node_or_null(gate_timer_path)
	if _gate_timer == null:
		push_error("PriceSystem: GateTimer 를 찾지 못했다. 수명 대가가 동작하지 않는다.")
	var player := get_node_or_null(player_path)
	if player != null:
		_hurtbox = player.get_node_or_null(^"%HurtboxComponent") as HurtboxComponent
	if _hurtbox == null:
		push_error("PriceSystem: 플레이어 HurtboxComponent 를 찾지 못했다. 살 대가가 동작하지 않는다.")
	EventBus.god_served.connect(_on_god_served)


## 인간성을 얼마나 내줬는지. 결말 판정(design.md 5-0)과 얼굴이 흐려지는 정도가 이걸 본다.
func get_humanity_paid() -> int:
	return _humanity_paid


func get_paid_total() -> int:
	return _paid_total


func _on_god_served(god: GodData) -> void:
	# 회수가 먼저다. 넋을 내준 뒤의 그 레벨업이 끝났으므로 선택지를 되돌린다 —
	# 청구를 먼저 하면 방금 낸 대가를 같은 프레임에 회수해 버린다.
	_repay_soul()
	if god == null or god.price_kind == &"":
		return
	var detail := _charge(god)
	if detail.is_empty():
		return
	_paid_total += 1
	EventBus.price_paid.emit(god.price_kind, god, detail)
	EventBus.price_total_changed.emit(_paid_total, _humanity_paid)


## 대가를 실제로 청구한다. 치르지 못했으면 빈 문자열을 돌려 "치른 것으로 세지 않는다".
func _charge(god: GodData) -> String:
	match god.price_kind:
		&"lifespan":
			return _charge_lifespan(god.price_scale)
		&"flesh":
			return _charge_flesh()
		&"soul":
			return _charge_soul()
		&"humanity":
			return _charge_humanity()
		&"memory":
			return _charge_memory()
		_:
			push_error("PriceSystem: 모르는 대가 종류다 — %s (%s)" % [god.price_kind, god.id])
			return ""


## 수명 — 종착이 가까워진다. 적 난이도 진행도(RunManager.gate_duration_sec)도 같이 당겨지므로
## 남은 시간이 줄 뿐 아니라 **남은 시간이 더 험해진다**. 그게 이 대가의 값이다.
func _charge_lifespan(scale: float) -> String:
	if _gate_timer == null:
		return ""
	var cut := LIFESPAN_SEC * scale
	var before: float = _gate_timer.duration_sec
	var after := maxf(GATE_FLOOR_SEC, before - cut)
	if is_equal_approx(before, after):
		return ""
	_gate_timer.duration_sec = after
	RunManager.gate_duration_sec = after
	return "수명 −%d초" % int(round(before - after))


## 살 — 맞고 나서 무적인 시간이 짧아진다. 데미지는 그대로다.
func _charge_flesh() -> String:
	if _hurtbox == null:
		return ""
	var before := _hurtbox.invuln_time
	var after := maxf(FLESH_IFRAME_FLOOR, before - FLESH_IFRAME_STEP)
	if is_equal_approx(before, after):
		return ""
	_hurtbox.invuln_time = after
	return "살 — 무적 %.2fs → %.2fs" % [before, after]


## 넋 — 다음 레벨업에 카드가 한 장 덜 뜬다. 이미 내준 상태면 더 내주지 않는다.
func _charge_soul() -> String:
	if _god_system == null or _soul_debt:
		return ""
	_soul_debt = true
	_god_system.choice_count = SOUL_CHOICE_COUNT
	return "넋 — 다음 신내림 2택"


## 인간성 — 지금은 아무것도 깎지 않는다. **끝에서 청구된다**(design.md 5-0).
## 강해질수록 사람에서 멀어지고, 그 거리가 결말을 가른다.
func _charge_humanity() -> String:
	_humanity_paid += 1
	RunManager.humanity_paid = _humanity_paid
	return "인간성 — 사람에서 한 걸음 멀어졌다"


## 기억 — 이미 모신 신 하나를 1레벨 잃는다. 잊을 것이 없으면 청구되지 않는다
## (첫 신내림에서 자기 자신을 잊는 것을 막는다).
func _charge_memory() -> String:
	if _god_system == null or not _god_system.forget_one():
		return ""
	return "기억 — 모시던 신 하나를 잊었다"


func _repay_soul() -> void:
	if not _soul_debt or _god_system == null:
		return
	_soul_debt = false
	_god_system.choice_count = _base_choice_count
