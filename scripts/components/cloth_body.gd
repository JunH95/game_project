class_name ClothBody
extends Node2D

## 무당의 무복. 점과 "두 점 사이 거리를 유지하라"는 제약만으로 천을 만든다(verlet).
##
## 스프라이트 시트를 쓰지 않는 이유가 이것이다 — 8방향 걷기 프레임을 그리지 않아도
## 방향·속도·상태가 무엇이든 천이 알아서 반응한다. 도형 캐릭터가 살아 보이는 것은
## 정교한 그림이 아니라 **몸보다 반 박자 늦게 따라오는 자락** 때문이다.
##
## 몸주·모시는 신·합이 전부 여기 수치로 들어온다. 외형 변화에 새 그림이 필요 없다는 것이
## 이 방식의 값어치다(design.md 9절).
##
## 좌표계: 부모(플레이어) 로컬. 부모가 움직이면 뿌리가 끌려가고 나머지는 관성으로 남는다.

## 한 프레임을 몇 번에 나눠 풀지. 적으면 천이 늘어난다.
const SUBSTEPS: int = 3
## 거리 제약 반복 횟수. 적으면 흐물거리고 많으면 뻣뻣해진다.
const RELAX: int = 6
const GRAVITY: float = 900.0
const DRAG: float = 0.986
## 강림 중 중력 배율. 음수라 자락이 떠오른다 — 신이 내렸다는 인상의 핵심이다.
const GANGRIM_GRAVITY: float = -0.45

## 갈래 하나. 뿌리에서 늘어진 점들의 사슬이다.
class Strand:
	var points: PackedVector2Array
	var previous: PackedVector2Array
	var segment: float
	var spread: float
	var root: Vector2
	## 무구를 쥔 지점에 매달리는 갈래(지전)인지. true 면 root 를 무기 쪽에서 받는다.
	var on_grip: bool = false

	func _init(count: int, seg: float, spread_amount: float, anchor: Vector2,
			grip: bool = false) -> void:
		segment = seg
		spread = spread_amount
		root = anchor
		on_grip = grip
		points = PackedVector2Array()
		previous = PackedVector2Array()
		for i in count:
			var p := anchor + Vector2(0.0, float(i) * seg)
			points.append(p)
			previous.append(p)


@export var robe_color: Color = Color("F2EDE3")
@export var sash_color: Color = Color("E4543F")
## 클수록 무겁게 가라앉는다. 갑주 위 전포는 1.45, 도포는 0.70(design.md 9-1).
@export var cloth_weight: float = 1.0
## 치마 갈래 수. 많을수록 넓게 퍼진다.
@export var rib_count: int = 7
## 갈래 하나의 마디 길이(px).
@export var segment_length: float = 9.0
## 옆으로 벌어지려는 힘. 0 이면 치마가 다리처럼 붙는다.
@export var spread: float = 1.0

var _skirt: Array[Strand] = []
var _sleeves: Array[Strand] = []
var _jijeon: Array[Strand] = []
var _sash: Strand
var _braid: Strand
## 최영장군을 모실 때만 그리는 등 뒤 전기(戰旗). 표식도 천이라 같은 물리에 얹힌다.
var _banner: Strand
var _all: Array[Strand] = []

## 무구를 쥔 지점(로컬). 지전이 여기 매달리므로 천 계산 전에 무기가 채워 준다.
var _grip: Vector2 = Vector2.ZERO
var _gangrim: bool = false
var _show_banner: bool = false
## 자락이 자라는 배율. 신을 모실수록 커진다 — 성장이 몸에 보여야 한다.
var _growth: float = 1.0


func _ready() -> void:
	# 액터보다 뒤에 깔려야 몸이 천 위에 얹힌다.
	z_index = -1
	rebuild()


## 몸주가 바뀌거나 신을 더 모시면 다시 짠다. 갈래 수·길이가 달라지기 때문이다.
func rebuild() -> void:
	var seg := segment_length / maxf(0.2, cloth_weight)
	var length := int(round(8.0 * _growth))

	_skirt.clear()
	for i in rib_count:
		var t := 0.5 if rib_count <= 1 else float(i) / float(rib_count - 1)
		_skirt.append(Strand.new(length, seg, (t - 0.5) * 2.0 * spread,
			Vector2((t - 0.5) * 15.0, 0.0)))

	_sleeves.clear()
	for side in [-1.0, 1.0]:
		_sleeves.append(Strand.new(6, seg, side * spread, Vector2(side * 17.0, -14.0)))

	# 지전(紙錢) — 무구에 매다는 흰 종이 술. 이 하나가 무기를 무구(巫具)로 만든다.
	_jijeon.clear()
	for i in 5:
		_jijeon.append(Strand.new(4, 5.5, (float(i) - 2.0) * 0.5, Vector2.ZERO, true))

	_sash = Strand.new(int(round(13.0 * _growth)), 8.5, 0.0, Vector2(-4.0, 2.0))
	# 댕기 — 버려진 일곱째 공주. 땋은 머리가 있어야 젊은 여성으로 읽힌다.
	_braid = Strand.new(9, 7.5, 0.0, Vector2(0.0, -20.0))
	_banner = Strand.new(10, 9.0, 0.0, Vector2(-6.0, -14.0))

	_all.clear()
	_all.append_array(_skirt)
	_all.append_array(_sleeves)
	_all.append_array(_jijeon)
	_all.append(_sash)
	_all.append(_braid)
	_all.append(_banner)


## 무기가 매 프레임 호출한다. 지전이 무구를 따라 흔들리게 한다.
func set_grip(local_position: Vector2) -> void:
	_grip = local_position


func set_gangrim(active: bool) -> void:
	_gangrim = active


func set_banner_visible(visible_banner: bool) -> void:
	_show_banner = visible_banner


## 신을 모실수록 자락이 자란다. 값이 바뀔 때만 다시 짠다 — 매번 짜면 천이 초기화된다.
func set_growth(served_count: int) -> void:
	var next := 1.0 + float(served_count) * 0.085
	if is_equal_approx(next, _growth):
		return
	_growth = next
	rebuild()


## 자락을 direction 쪽으로 민다. 끝으로 갈수록 세게 밀어야 채찍처럼 파도가 흐른다.
## 뿌리(0번)는 몸에 붙어 있으므로 건드리지 않는다.
func impulse(direction: Vector2, power: float) -> void:
	for strand in _all:
		var count := strand.points.size()
		for i in range(1, count):
			var k := float(i) / float(count)
			strand.points[i] += direction * power * k * 26.0


func _physics_process(delta: float) -> void:
	var sub := delta / float(SUBSTEPS)
	for _i in SUBSTEPS:
		_step(sub)
	queue_redraw()


func _step(delta: float) -> void:
	var gravity_scale := GANGRIM_GRAVITY if _gangrim else 1.0
	for strand in _all:
		var count := strand.points.size()
		if count < 2:
			continue
		# 뿌리는 물리를 따르지 않고 몸(또는 무구)에 붙어 있다.
		strand.previous[0] = strand.points[0]
		strand.points[0] = _grip if strand.on_grip else strand.root

		for i in range(1, count):
			var velocity: Vector2 = (strand.points[i] - strand.previous[i]) * DRAG
			strand.previous[i] = strand.points[i]
			var next: Vector2 = strand.points[i] + velocity
			next.y += GRAVITY * cloth_weight * gravity_scale * delta * delta
			# 뿌리에서 멀수록 옆으로 벌어진다.
			next.x += strand.spread * (float(i) / float(count)) * 26.0 * delta
			strand.points[i] = next

		# 거리 제약. 이 반복이 곧 "천"이다.
		for _r in RELAX:
			for i in range(count - 1):
				var a: Vector2 = strand.points[i]
				var b: Vector2 = strand.points[i + 1]
				var offset := b - a
				var distance := offset.length()
				if distance <= 0.0001:
					continue
				var correction := offset * ((distance - strand.segment) / distance * 0.5)
				if i > 0:
					strand.points[i] = a + correction
				strand.points[i + 1] = b - correction


func _draw() -> void:
	# 강림 중에는 무복 전체가 금빛으로 물든다.
	var robe := PlaceholderArt.GEUMBAK if _gangrim else robe_color
	var robe_alpha := 0.44 if _gangrim else 0.30

	# 치마는 갈래 사이를 면으로 채워야 천으로 보인다. 선만 그으면 밧줄 다발이다.
	for i in range(_skirt.size() - 1):
		_fill_panel(_skirt[i], _skirt[i + 1], robe, robe_alpha)
	for strand in _skirt:
		_ribbon(strand, robe, 3.4, 0.34)
	for strand in _sleeves:
		_ribbon(strand, robe, 7.0, 0.42)

	# 댕기 — 몸보다 어두워야 뒤로 넘어간 것처럼 읽힌다.
	_ribbon(_braid, Color(0.16, 0.13, 0.16), 6.5, 0.95)
	var braid_tip: Vector2 = _braid.points[_braid.points.size() - 1]
	draw_circle(braid_tip, 5.0, Color(sash_color, 0.9))

	for strand in _jijeon:
		_ribbon(strand, PlaceholderArt.HOBUN, 3.2, 0.72)

	if _show_banner:
		_fill_banner()

	_ribbon(_sash, sash_color, 9.0, 0.85)
	_ribbon(_sash, sash_color, 15.0, 0.22)


## 갈래 두 개 사이를 면으로 채운다. 볼록·오목을 가리지 않으려고 사각형으로 쪼갠다
## (draw_colored_polygon 은 오목 폴리곤을 제대로 채우지 못한다).
func _fill_panel(a: Strand, b: Strand, color: Color, alpha: float) -> void:
	var count: int = mini(a.points.size(), b.points.size())
	for i in range(count - 1):
		# 아래로 갈수록 옅어져야 천이 공기 중으로 사라지는 것처럼 보인다.
		var fade := alpha * (1.0 - float(i) / float(count) * 0.85)
		_fill_quad(PackedVector2Array([
			a.points[i], a.points[i + 1], b.points[i + 1], b.points[i]
		]), Color(color, fade))


## 넓이가 0 인 사각형은 그리지 않는다. 갈래가 겹쳐 접히는 순간(런 시작 직후처럼 천이
## 아직 안 퍼졌을 때) 네 점이 한 줄로 서면 삼각분할이 실패해 엔진이 에러를 뱉는다.
## 어차피 보이지 않는 면이라 건너뛰는 것이 맞다.
func _fill_quad(points: PackedVector2Array, color: Color) -> void:
	# 신발끈 공식. 부호는 필요 없고 크기만 본다.
	var doubled_area := 0.0
	var n := points.size()
	for i in n:
		var p := points[i]
		var q := points[(i + 1) % n]
		doubled_area += p.x * q.y - q.x * p.y
	if absf(doubled_area) < 1.0:
		return
	draw_colored_polygon(points, color)


func _fill_banner() -> void:
	var color := PlaceholderArt.GEUMBAK if _gangrim else PlaceholderArt.JUSA
	var width := 20.0 * (1.7 if _gangrim else 1.0)
	var count := _banner.points.size()
	for i in range(count - 1):
		var fade := 0.5 * (1.0 - float(i) / float(count) * 0.6)
		_fill_quad(PackedVector2Array([
			_banner.points[i], _banner.points[i + 1],
			_banner.points[i + 1] - Vector2(width, 0.0),
			_banner.points[i] - Vector2(width, 0.0)
		]), Color(color, fade))
	_ribbon(_banner, color, 4.0, 0.9)


## 끝으로 갈수록 가늘어져야 천이지 밧줄이 아니다.
func _ribbon(strand: Strand, color: Color, width: float, alpha: float) -> void:
	var count := strand.points.size()
	for i in range(count - 1):
		var taper := 1.0 - float(i) / float(count) * 0.72
		draw_line(strand.points[i], strand.points[i + 1],
			Color(color, alpha), width * taper)
