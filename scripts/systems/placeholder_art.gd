class_name PlaceholderArt
extends RefCounted

## 정식 아트가 들어오기 전까지 쓰는 공용 실루엣 라이브러리.
## 팔레트와 형태 규칙을 한곳에 모아 액터마다 톤이 어긋나는 것을 막는다.
## 기준색은 vision.md 4절의 광물 안료(주사홍·군청·금박·먹)다.
##
## 여기 함수는 CanvasItem 의 _draw() 안에서만 부른다. 밖에서 부르면 Godot 이 조용히 무시한다.
##
## 성능 규약: 적처럼 수백 개가 동시에 뜨는 액터는 매 프레임 다시 그리면 캔버스 아이템을
## 그만큼 다시 만든다. 그래서 형태는 정적으로 그리고, 움직임은 노드 transform(회전·스케일)으로 준다.
##
## 오목 다각형 금지: draw_colored_polygon 은 오목 폴리곤을 제대로 채우지 못한다.
## 모든 형태를 볼록 조각(삼각형·사다리꼴·원)의 겹침으로 조립한다.

## 광물 안료 팔레트(vision.md 4절).
const JUSA: Color = Color(0.702, 0.208, 0.165)
const GUNCHEONG: Color = Color(0.145, 0.251, 0.478)
const GEUMBAK: Color = Color(0.851, 0.643, 0.255)
const MEOK: Color = Color(0.106, 0.106, 0.141)
const HOBUN: Color = Color(0.949, 0.929, 0.891)

## 넋·혼불 계열의 푸른빛. 배경 넋 불빛과 같은 계열이라 화면이 하나로 읽힌다.
const NEOK: Color = Color(0.62, 0.72, 0.95)


## 텍스처가 있으면 그걸 중앙 정렬로 그리고 true 를 돌려준다.
## 각 액터의 _draw() 첫 줄에서 부르면, 아트가 들어오는 순간 도형 코드가 자동으로 비켜난다.
##
## fit_size 는 긴 변을 맞출 픽셀 크기다. 0 이면 원본 크기로 그린다 — 그림은 보통 캐릭터보다
## 훨씬 크게 뽑히므로(512px 초상 vs 반지름 8px 짜리 적) 액터는 항상 자기 크기를 넘긴다.
static func draw_texture_centered(canvas: CanvasItem, texture: Texture2D,
		fit_size: float = 0.0) -> bool:
	if texture == null:
		return false
	var size := texture.get_size()
	if fit_size > 0.0:
		var longest := maxf(size.x, size.y)
		if longest > 0.0:
			size *= fit_size / longest
	canvas.draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
	return true


## 원귀 — 아래로 흘러내리는 넋. 발이 아니라 연기로 끝나야 "떠 있는 것"으로 읽힌다.
static func draw_wraith(canvas: CanvasItem, r: float, body: Color) -> void:
	var dark := body.darkened(0.42)
	# 바깥 무리를 먼저 깔아 윤곽을 흐린다. 선명한 원은 적이 아니라 UI 처럼 보인다.
	canvas.draw_circle(Vector2(0.0, -r * 0.1), r * 1.25, Color(body.r, body.g, body.b, 0.16))
	# 흘러내리는 자락(볼록 삼각형).
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.82, -r * 0.15), Vector2(r * 0.82, -r * 0.15), Vector2(0.0, r * 1.55)
	]), dark)
	canvas.draw_circle(Vector2(0.0, -r * 0.12), r * 0.86, dark)
	canvas.draw_circle(Vector2(0.0, -r * 0.34), r * 0.62, body)
	_draw_eyes(canvas, Vector2(0.0, -r * 0.4), r * 0.26, r * 0.13)


## 급살 원귀 — 진행 방향으로 길게 뻗은 화살촉. 노드가 이동 방향으로 회전하는 것을 전제한다.
## 노치(파인 뒤꽁무니)는 오목하므로 볼록 삼각형 두 장으로 나눠 만든다.
static func draw_rusher(canvas: CanvasItem, r: float, body: Color) -> void:
	var dark := body.darkened(0.35)
	# 뒤로 끌리는 잔상. 속도가 형태로 읽히게 한다.
	canvas.draw_line(Vector2(-r * 0.4, 0.0), Vector2(-r * 2.6, 0.0),
		Color(body.r, body.g, body.b, 0.28), r * 0.5)
	var tip := Vector2(r * 2.0, 0.0)
	var notch := Vector2(-r * 0.15, 0.0)
	canvas.draw_colored_polygon(PackedVector2Array([
		tip, Vector2(-r * 0.85, r * 0.95), notch]), dark)
	canvas.draw_colored_polygon(PackedVector2Array([
		tip, Vector2(-r * 0.85, -r * 0.95), notch]), dark)
	# 중심의 밝은 심지 — 뾰족한 것이 어디로 향하는지 한눈에.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(r * 1.5, 0.0), Vector2(-r * 0.1, r * 0.34), Vector2(-r * 0.1, -r * 0.34)
	]), body)


## 업덩이 — 육중한 죄업 덩어리. 원을 겹쳐 울퉁불퉁한 실루엣을 만들고 균열로 속을 보여 준다.
static func draw_hulk(canvas: CanvasItem, r: float, body: Color) -> void:
	var dark := body.darkened(0.4)
	var lit := body.lightened(0.18)
	canvas.draw_circle(Vector2.ZERO, r * 1.12, Color(body.r, body.g, body.b, 0.14))
	canvas.draw_circle(Vector2.ZERO, r * 0.92, dark)
	canvas.draw_circle(Vector2(-r * 0.46, -r * 0.34), r * 0.52, dark)
	canvas.draw_circle(Vector2(r * 0.44, -r * 0.22), r * 0.46, dark)
	canvas.draw_circle(Vector2(r * 0.12, r * 0.5), r * 0.5, dark)
	canvas.draw_circle(Vector2(-r * 0.3, r * 0.4), r * 0.4, dark)
	# 균열에서 새는 빛. 덩어리 안에 뭔가 갇혀 있다는 인상을 준다.
	var glow := Color(JUSA.r, JUSA.g, JUSA.b, 0.85)
	canvas.draw_line(Vector2(-r * 0.55, -r * 0.1), Vector2(-r * 0.05, r * 0.25), glow, r * 0.12)
	canvas.draw_line(Vector2(-r * 0.05, r * 0.25), Vector2(r * 0.5, r * 0.05), glow, r * 0.1)
	canvas.draw_line(Vector2(r * 0.05, -r * 0.6), Vector2(-r * 0.05, r * 0.25), glow, r * 0.08)
	_draw_eyes(canvas, Vector2(0.0, -r * 0.3), r * 0.34, r * 0.12, lit)


## 무당 — 플레이어. 위에서 내려다보는 판이라 몸은 늘 세워 두고, 방향은 호출부가 scale.x 로 뒤집는다.
## bob 은 걸음의 위아래 흔들림(0.0~1.0), taegi 는 강림 중 금빛 후광.
static func draw_mudang(canvas: CanvasItem, r: float, bob: float, taegi: bool) -> void:
	if taegi:
		# 강림 중에는 뒤에 금빛이 번진다 — 지금이 그 순간임을 몸으로 알린다.
		canvas.draw_circle(Vector2.ZERO, r * 2.1, Color(GEUMBAK.r, GEUMBAK.g, GEUMBAK.b, 0.14))
		canvas.draw_circle(Vector2.ZERO, r * 1.45, Color(GEUMBAK.r, GEUMBAK.g, GEUMBAK.b, 0.3))

	# 발밑 그림자. 없으면 캐릭터가 바닥에서 떠 보인다.
	canvas.draw_circle(Vector2(0.0, r * 0.95), r * 0.72, Color(0.0, 0.0, 0.0, 0.28))

	var lift := -bob * r * 0.08
	# 무복 치마(볼록 사다리꼴).
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.52, -r * 0.3 + lift), Vector2(r * 0.52, -r * 0.3 + lift),
		Vector2(r * 0.88, r * 0.95), Vector2(-r * 0.88, r * 0.95)
	]), Color(0.93, 0.94, 0.97))
	# 홍띠 — 무복의 붉은 허리띠. 흰 옷에 색점이 하나 있어야 실루엣이 납작해지지 않는다.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.6, r * 0.02 + lift), Vector2(r * 0.6, r * 0.02 + lift),
		Vector2(r * 0.66, r * 0.28), Vector2(-r * 0.66, r * 0.28)
	]), JUSA)
	# 어깨선 — 군청으로 저고리 깃을 암시한다.
	canvas.draw_line(Vector2(-r * 0.5, -r * 0.26 + lift), Vector2(r * 0.5, -r * 0.26 + lift),
		GUNCHEONG, r * 0.16)
	# 머리
	canvas.draw_circle(Vector2(0.0, -r * 0.66 + lift), r * 0.4, Color(0.96, 0.91, 0.83))
	# 머리 위 방울 — 무구(巫具)를 한 점으로 암시한다.
	canvas.draw_circle(Vector2(0.0, -r * 1.02 + lift), r * 0.16, GEUMBAK)


## 무당의 몸만. 무복은 ClothBody 가 물리로 그리므로 여기서는 그 위에 얹히는 것만 그린다.
## 천까지 여기서 그리면 도형과 물리가 겹쳐 두 벌을 입은 것처럼 보인다.
static func draw_shaman_body(canvas: CanvasItem, r: float, bob: float, taegi: bool) -> void:
	if taegi:
		# 강림 중에는 뒤에 금빛이 번지고 발밑에 작두날이 깔린다 — 무당이 작두에 오르는 도상.
		canvas.draw_circle(Vector2.ZERO, r * 2.4, Color(GEUMBAK.r, GEUMBAK.g, GEUMBAK.b, 0.14))
		canvas.draw_circle(Vector2.ZERO, r * 1.5, Color(GEUMBAK.r, GEUMBAK.g, GEUMBAK.b, 0.28))
		for offset in [-0.55, 0.55]:
			canvas.draw_line(Vector2(-r * 1.5, r * (1.35 + offset * 0.5)),
				Vector2(r * 1.5, r * (1.35 + offset * 0.5)), Color(0.86, 0.89, 0.93, 0.95), 2.5)
	else:
		# 발밑 그림자. 없으면 캐릭터가 바닥에서 떠 보인다.
		canvas.draw_circle(Vector2(0.0, r * 0.95), r * 0.72, Color(0.0, 0.0, 0.0, 0.28))

	var lift := -bob * r * 0.08
	# 어깨 — 무복 위로 드러나는 부분만.
	canvas.draw_line(Vector2(-r * 0.5, -r * 0.26 + lift), Vector2(r * 0.5, -r * 0.26 + lift),
		GUNCHEONG, r * 0.2)
	canvas.draw_circle(Vector2(0.0, -r * 0.66 + lift), r * 0.4, Color(0.96, 0.91, 0.83))
	# 눈 두 점. 없으면 발광체지 사람이 아니다.
	_draw_eyes(canvas, Vector2(0.0, -r * 0.62 + lift), r * 0.17, r * 0.07, Color(0.11, 0.11, 0.14))
	# 고깔 — 강신무의 관
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r * 1.7 + lift), Vector2(r * 0.5, -r * 0.9 + lift),
		Vector2(-r * 0.5, -r * 0.9 + lift)
	]), Color(0.93, 0.94, 0.97))


## 부적 — 세로로 긴 종이. 진행 방향이 X 축이 되도록 그린다(호출부가 rotation 을 준다).
static func draw_talisman(canvas: CanvasItem, s: float) -> void:
	# 꼬리 잔상. 유도로 휘는 궤적이 눈에 남게 한다.
	canvas.draw_line(Vector2(-s * 0.9, 0.0), Vector2(-s * 2.4, 0.0),
		Color(GEUMBAK.r, GEUMBAK.g, GEUMBAK.b, 0.3), s * 0.5)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(s * 1.35, -s * 0.52), Vector2(s * 1.35, s * 0.52),
		Vector2(-s * 0.95, s * 0.62), Vector2(-s * 0.95, -s * 0.62)
	]), Color(0.95, 0.86, 0.42))
	# 주사로 친 획. 글자를 읽히게 그릴 크기가 아니라 획의 리듬만 남긴다.
	canvas.draw_line(Vector2(s * 0.9, 0.0), Vector2(-s * 0.6, 0.0), JUSA, s * 0.2)
	canvas.draw_line(Vector2(s * 0.35, -s * 0.34), Vector2(s * 0.35, s * 0.34), JUSA, s * 0.16)
	canvas.draw_line(Vector2(-s * 0.25, -s * 0.28), Vector2(-s * 0.25, s * 0.28), JUSA, s * 0.14)


## 넋 조각(XP 젬). 회전은 호출부가 scale.x 로 준다 — 젬은 화면에 수십 개가 깔려서
## 매 프레임 다시 그리면 개수만큼 비용이 붙는다.
static func draw_soul_gem(canvas: CanvasItem, r: float, tint: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, r * 2.0, Color(tint.r, tint.g, tint.b, 0.12))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r * 1.35), Vector2(r, 0.0), Vector2(0.0, r * 1.35), Vector2(-r, 0.0)
	]), tint)
	# 위쪽 반쪽만 밝게 — 면이 갈라져야 보석으로 읽힌다.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r * 1.35), Vector2(r * 0.5, -r * 0.2), Vector2(-r * 0.5, -r * 0.2)
	]), Color(1.0, 1.0, 1.0, 0.55))


## 노려보는 두 점. 눈이 있으면 원이 적으로 읽힌다.
static func _draw_eyes(canvas: CanvasItem, center: Vector2, spread: float, size: float,
		color: Color = Color(1.0, 0.93, 0.72, 0.95)) -> void:
	canvas.draw_circle(center + Vector2(-spread, 0.0), size, color)
	canvas.draw_circle(center + Vector2(spread, 0.0), size, color)
