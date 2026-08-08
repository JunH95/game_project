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


## 무기별 손동작. 같은 "휘두름"이라도 무엇을 들었느냐로 손이 다르게 가야 무기가 구분된다.
const POSE_SLASH: StringName = &"slash"    ## 작두 — 옆에서 앞으로 쓸어 벤다
const POSE_THROW: StringName = &"throw"    ## 부적 — 뒤로 당겼다 앞으로 튕겨 놓는다
const POSE_HOLD: StringName = &"hold"      ## 궤도 무기 — 돌아가는 날을 따라 들고 있는다
const POSE_SPIN: StringName = &"spin"      ## 언월도 — 몸을 돌려 사방을 쓸어 벤다
## 작두 3연타. 같은 궤적만 반복하면 기계처럼 보이므로 벨 때마다 돌려 쓴다.
const POSE_SLASH_BACK: StringName = &"slash_back"  ## 되돌려 베기(궤적 반전)
const POSE_THRUST: StringName = &"thrust"          ## 찌르기(마무리)
const SLASH_CHAIN: Array[StringName] = [POSE_SLASH, POSE_SLASH_BACK, POSE_THRUST]

## 언월도 — 창술 3연타. 횡소 → 역횡소(반대로 돈다) → 자돌.
const POSE_SPIN_BACK: StringName = &"spin_back"    ## 역횡소(회전 반전)
const POSE_POLE_THRUST: StringName = &"pole_thrust"  ## 자돌 — 자루째 앞으로 뻗는다
const SPIN_CHAIN: Array[StringName] = [POSE_SPIN, POSE_SPIN_BACK, POSE_POLE_THRUST]

## 부적 — 법사 3연타. 뿌리기 → 인 맺기 → 장풍.
const POSE_SEAL: StringName = &"seal"    ## 인(印) — 손을 모았다 옆으로 밀어낸다
const POSE_PALM: StringName = &"palm"    ## 장풍 — 손바닥을 앞으로 내지른다
const THROW_CHAIN: Array[StringName] = [POSE_THROW, POSE_SEAL, POSE_PALM]


## 무구를 쥔 손의 위치(몸 로컬). 지전이 여기 매달리므로 **그리기와 천이 같은 값을 봐야 한다** —
## 각자 계산하면 손과 종이 술이 따로 논다. draw_shaman_body 와 인자가 같다.
##
## swing 이 음수면 예비(뒤로), 양수면 타격(앞으로)이다. pose 가 그 궤적의 모양을 정한다.
static func shaman_hand(r: float, bob: float, facing: float, swing: float,
		pose: StringName = POSE_SLASH) -> Vector2:
	var lift := -bob * r * 0.08
	var shoulder := Vector2(0.0, -r * 0.16 + lift)

	match pose:
		POSE_THROW:
			# 던지기 — 방향은 그대로 두고 거리만 확 바뀐다. 뒤로 당겼다가 앞으로 튕긴다.
			var reach := r * (0.55 + swing * 1.05)
			return shoulder + Vector2.from_angle(facing) * reach
		POSE_HOLD:
			# 들고 있는 자세 — 몸에서 일정 거리로 내밀고, 휘두름에는 조금만 반응한다.
			return shoulder + Vector2.from_angle(facing) * (r * (0.78 + swing * 0.22))
		POSE_SPIN:
			# 사방 베기 — 손이 몸을 한 바퀴 돈다. 팔을 길게 뻗어 대형 무기의 무게를 낸다.
			var turn := clampf((swing + 0.38) / 1.38, 0.0, 1.0) * TAU
			return shoulder + Vector2.from_angle(facing + turn) * (r * (0.72 + maxf(swing, 0.0) * 0.5))
		POSE_SPIN_BACK:
			# 역횡소 — 손이 반대로 한 바퀴 돈다. 회전 방향이 뒤집히는 것이 2타의 전부다.
			var back_turn := clampf((swing + 0.38) / 1.38, 0.0, 1.0) * -TAU
			return shoulder + Vector2.from_angle(facing + back_turn) 				* (r * (0.72 + maxf(swing, 0.0) * 0.5))
		POSE_POLE_THRUST:
			# 자돌 — 돌지 않고 자루째 앞으로 뻗는다. 대형 무기라 작두 찌르기보다 더 나간다.
			return shoulder + Vector2.from_angle(facing + swing * 0.08) 				* (r * (0.45 + maxf(swing, 0.0) * 1.45))
		POSE_SEAL:
			# 인 맺기 — 손을 몸 앞으로 **모았다가 옆으로** 민다. 앞뒤가 아니라 좌우로 움직여야
			# 던지기와 갈린다. 예비에서 가슴 앞까지 당겨 온다.
			var open := clampf((swing + 0.38) / 1.38, 0.0, 1.0)
			var lateral := lerpf(-0.15, 1.05, open)
			return shoulder + Vector2.from_angle(facing + lateral) 				* (r * (0.35 + maxf(swing, 0.0) * 0.55))
		POSE_PALM:
			# 장풍 — 손바닥을 앞으로 내지른다. 던지기보다 짧게 당겼다 더 멀리 뻗는다.
			return shoulder + Vector2.from_angle(facing) * (r * (0.42 + swing * 1.35))
		POSE_SLASH_BACK:
			# 되돌려 베기 — 위 궤적을 뒤집는다. 한쪽으로만 계속 휘두르면 기계처럼 보인다.
			var back_sweep := lerpf(-0.95, 0.62, clampf((swing + 0.38) / 1.38, 0.0, 1.0))
			return shoulder + Vector2.from_angle(facing + back_sweep) \
				* (r * (0.62 + maxf(swing, 0.0) * 0.55))
		POSE_THRUST:
			# 찌르기 — 각도는 거의 고정하고 팔만 길게 뻗는다. 세 번째 타의 마무리.
			return shoulder + Vector2.from_angle(facing + swing * 0.12) \
				* (r * (0.5 + maxf(swing, 0.0) * 1.15))
		_:
			# 베기 — 손이 호를 그린다. 예비에서 뒤(+각), 타격에서 앞(−각)으로 쓸고 지나간다.
			# 거리보다 **각도**가 움직여야 "휘둘렀다"로 읽힌다.
			var sweep := lerpf(0.95, -0.62, clampf((swing + 0.38) / 1.38, 0.0, 1.0))
			var dist := r * (0.62 + maxf(swing, 0.0) * 0.55)
			return shoulder + Vector2.from_angle(facing + sweep) * dist


## 무당의 몸만. 무복은 ClothBody 가 물리로 그리므로 여기서는 그 위에 얹히는 것만 그린다.
## 천까지 여기서 그리면 도형과 물리가 겹쳐 두 벌을 입은 것처럼 보인다.
##
## facing 은 몸이 향한 각(rad), swing 은 휘두름의 진행도다.
## swing 이 음수면 뒤로 감는 예비 동작, 양수면 앞으로 내지르는 타격이다(0 이면 평상시).
## 몸통을 회전시키지 않는 이유: 자식으로 달린 무기(부채꼴·궤도)까지 같이 돌아간다.
## 그래서 회전 대신 **팔·상체를 facing 쪽으로 밀어** 방향을 낸다.
## 두 점을 잇되 **가운데가 부풀어 휘는** 선의 점들. 한복은 직선이 거의 없다 —
## 배래(소매 아랫선)·도련(저고리 밑단)·어깨가 전부 곡선이라, 직선으로 그리면 레고가 된다.
## bulge 는 휘는 방향과 깊이(로컬 기준 수직 방향).
static func _curve(a: Vector2, b: Vector2, bulge: float, steps: int = 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	var normal := (b - a).orthogonal().normalized() * bulge
	for i in steps + 1:
		var t := float(i) / float(steps)
		# 이차 베지어. 가운데에서 가장 많이 휜다.
		var mid := a.lerp(b, t)
		out.append(mid + normal * (4.0 * t * (1.0 - t)))
	return out


## 끝으로 갈수록 가늘어지는 사지. 굵기가 일정한 선은 팔이 아니라 막대로 보인다.
static func _limb(canvas: CanvasItem, a: Vector2, b: Vector2, w_start: float, w_end: float,
		color: Color, bulge: float = 0.0) -> void:
	var spine := _curve(a, b, bulge, 6)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in spine.size():
		var t := float(i) / float(spine.size() - 1)
		var w := lerpf(w_start, w_end, t) * 0.5
		# 다음 점을 향한 방향의 수직으로 두께를 준다.
		var ahead: Vector2 = spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]
		var n := ahead.orthogonal().normalized() * w
		left.append(spine[i] + n)
		right.append(spine[i] - n)
	# 좌우를 한 폴리곤으로 잇지 않는다. 팔이 접히면 양쪽 변이 교차해 나비넥타이 폴리곤이 되고,
	# 그러면 매 프레임 "triangulation failed" 가 쏟아진다(전에 4.7MB 로그로 에디터를 죽인 그 버그다).
	# 마디마다 삼각형 둘로 쪼개면 교차해도 각 조각은 여전히 성립한다.
	for i in spine.size() - 1:
		_fill_triangle(canvas, left[i], left[i + 1], right[i], color)
		_fill_triangle(canvas, left[i + 1], right[i + 1], right[i], color)
	# 끝을 둥글게 — 잘린 단면이 보이면 조립품처럼 읽힌다.
	canvas.draw_circle(a, w_start * 0.5, color)
	canvas.draw_circle(b, w_end * 0.5, color)


## 넓이가 0 이거나 좌표가 유한하지 않은 삼각형은 건너뛴다. 렌더러에 넘기면 에러만 남고
## 그려지지도 않는다 — 매 프레임 도는 코드라 로그가 곧 성능 문제가 된다.
static func _fill_triangle(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2,
		color: Color) -> void:
	if not (a.is_finite() and b.is_finite() and c.is_finite()):
		return
	if absf((b - a).cross(c - a)) < 0.01:
		return
	canvas.draw_colored_polygon(PackedVector2Array([a, b, c]), color)


## 탈 — 몸주가 정한다. 신이 내리면 얼굴이 바뀐다는 것을 그대로 쓴다.
## 형태만으로 셋이 구분돼야 하므로 윤곽선을 서로 다르게 잡았다(작은 크기에서 색은 뭉개진다).
static func draw_mask(canvas: CanvasItem, center: Vector2, r: float, shape: StringName,
		face: Color, mark: Color) -> void:
	match shape:
		&"gaksi":
			# 각시탈 — 갸름한 계란형. 이마에 붉은 점, 눈은 가늘게 감긴 선.
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -r * 1.05), center + Vector2(r * 0.72, -r * 0.1),
				center + Vector2(0.0, r * 1.0), center + Vector2(-r * 0.72, -r * 0.1)
			]), face)
			canvas.draw_circle(center + Vector2(0.0, -r * 0.55), r * 0.15, mark)
			for side in [-1.0, 1.0]:
				canvas.draw_line(center + Vector2(side * r * 0.14, -r * 0.02),
					center + Vector2(side * r * 0.46, -r * 0.12), mark, r * 0.13)
		&"yangban":
			# 양반탈 — 넓적하고 위가 각진 형. 눈이 크고 둥글다.
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-r * 0.78, -r * 0.72), center + Vector2(r * 0.78, -r * 0.72),
				center + Vector2(r * 0.62, r * 0.95), center + Vector2(-r * 0.62, r * 0.95)
			]), face)
			for side in [-1.0, 1.0]:
				canvas.draw_circle(center + Vector2(side * r * 0.34, -r * 0.08), r * 0.2, mark)
		_:
			# 장수탈 — 사납게 각진 형. 눈꼬리가 위로 치솟고 이마에 굵은 획.
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -r * 1.1), center + Vector2(r * 0.8, -r * 0.35),
				center + Vector2(r * 0.5, r * 0.95), center + Vector2(-r * 0.5, r * 0.95),
				center + Vector2(-r * 0.8, -r * 0.35)
			]), face)
			canvas.draw_line(center + Vector2(-r * 0.5, -r * 0.6),
				center + Vector2(r * 0.5, -r * 0.6), mark, r * 0.16)
			for side in [-1.0, 1.0]:
				canvas.draw_line(center + Vector2(side * r * 0.12, r * 0.05),
					center + Vector2(side * r * 0.52, -r * 0.22), mark, r * 0.16)


## pose 는 무엇을 들었는지다(POSE_SLASH/THROW/HOLD/SPIN). 무기마다 손이 다르게 가야 구분된다.
## mask_* 는 몸주가 정하는 탈. 얼굴을 그리지 않고 탈을 씌워 실루엣으로 캐릭터를 가른다.
static func draw_shaman_body(canvas: CanvasItem, r: float, bob: float, taegi: bool,
		facing: float = 0.0, swing: float = 0.0, pose: StringName = POSE_SLASH,
		mask_shape: StringName = &"jangsu", mask_color: Color = HOBUN,
		mask_mark_color: Color = JUSA,
		hand_override: Variant = null) -> void:
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
	var dir := Vector2.from_angle(facing)
	# 상체가 휘두르는 쪽으로 쏠린다. 예비 동작(swing<0)에서는 반대로 젖혀진다.
	var lean := dir * (r * 0.24 * swing)
	var skin := Color(0.96, 0.91, 0.83)

	# --- 다리 ---
	# 걸을 때 앞뒤로 엇갈리고, 벨 때는 앞뒤로 벌려 버틴다. 치마 밑으로 이만큼은 보여야
	# "움직이고 있다"가 읽힌다(치마를 짧게 둔 이유가 이것이다).
	var stride := bob * r * 0.30
	# 벨 때는 향한 쪽으로 앞발이 나가 버틴다.
	var brace := dir.x * absf(swing) * r * 0.22
	for leg in [1.0, -1.0]:
		var hip := Vector2(r * 0.17 * leg, r * 0.34 + lift)
		var foot := Vector2(r * 0.17 * leg + stride * leg + brace * leg, r * 1.02)
		# 다리는 무릎에서 살짝 휜다. 곧은 막대면 조립품이다.
		_limb(canvas, hip, foot, r * 0.18, r * 0.12, skin, leg * r * 0.05)
		# 버선 — 코가 살짝 들린 흰 신.
		canvas.draw_circle(foot, r * 0.14, HOBUN)

	# --- 뒷팔 --- 몸 뒤에 깔려야 앞팔이 위로 읽힌다. 앞팔과 반대로 움직여 균형을 잡는다.
	var shoulder_off := Vector2(-r * 0.30 * dir.x, -r * 0.20 + lift) + lean * 0.4
	var back_hand := shoulder_off - dir * (r * (0.36 + maxf(swing, 0.0) * 0.28))
	_limb(canvas, shoulder_off, back_hand, r * 0.22, r * 0.14, skin, r * 0.08)

	# --- 치마 위로 드러나는 저고리 --- 한복은 저고리가 짧고 치마가 가슴 밑에서 퍼진다.
	# 그 경계가 실루엣의 핵심이라 저고리를 짧은 사다리꼴로 둔다.
	var chest := -r * 0.30 + lift
	var waist := r * 0.12 + lift
	# 저고리 — 어깨는 둥글게 내려오고 도련(밑단)은 아래로 볼록하다. 사다리꼴로 그리면 레고가 된다.
	var jeogori := PackedVector2Array()
	jeogori.append_array(_curve(Vector2(-r * 0.44, chest + r * 0.10) + lean,
		Vector2(r * 0.44, chest + r * 0.10) + lean, -r * 0.16))   # 어깨선(위로 볼록)
	jeogori.append_array(_curve(Vector2(r * 0.40, waist) + lean,
		Vector2(-r * 0.40, waist) + lean, -r * 0.12))             # 도련(아래로 볼록)
	canvas.draw_colored_polygon(jeogori, HOBUN)

	# 깃·동정 — 목에서 V 로 여미는 곡선. 한복으로 읽히게 하는 가장 싼 두 획이다.
	var neck := Vector2(0.0, -r * 0.34 + lift) + lean
	for side in [-1.0, 1.0]:
		canvas.draw_polyline(_curve(neck,
			Vector2(side * r * 0.30, chest + r * 0.30) + lean, side * r * 0.06),
			GUNCHEONG, r * 0.10)
	# 고름 — 가슴에서 늘어진 붉은 끈. 끝이 바람에 휜다.
	canvas.draw_polyline(_curve(Vector2(r * 0.12, chest + r * 0.26) + lean,
		Vector2(r * 0.04, waist + r * 0.34) + lean, r * 0.10), JUSA, r * 0.08)

	# --- 머리와 탈 ---
	# `[고증]` 굿에서 신을 청할 때 그 신의 탈을 쓴다. 사람 얼굴을 그리지 않는 이유이기도 하다 —
	# 눈코입 비례는 조금만 어긋나도 "못생겼다"로 읽히지만, 탈은 원래 과장된 형태라 그 판정이 없다.
	var head := Vector2(0.0, -r * 0.60 + lift) + lean
	canvas.draw_circle(head, r * 0.34, skin)
	draw_mask(canvas, head, r * 0.36, mask_shape, mask_color, mask_mark_color)
	# 고깔 — 강신무의 관. 상체보다 덜 따라와야 관성이 있는 것처럼 보인다.
	var hat_lean := lean * 0.55
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r * 1.58 + lift) + hat_lean,
		Vector2(r * 0.44, -r * 0.84 + lift) + hat_lean,
		Vector2(-r * 0.44, -r * 0.84 + lift) + hat_lean
	]), Color(0.93, 0.94, 0.97))

	# --- 앞팔 --- 무구를 쥔 손. 모션의 주역이라 마지막에 그려 맨 위로 올린다.
	var shoulder_main := Vector2(r * 0.30 * dir.x, -r * 0.20 + lift) + lean
	# 호출부가 지연된 손 위치를 주면 그걸 쓴다 — 목표를 반 박자 늦게 좇아야 팔이 부드럽다.
	var hand: Vector2 = hand_override if hand_override is Vector2 \
		else shaman_hand(r, bob, facing, swing, pose)
	# 팔꿈치를 살짝 꺾어 막대가 아니라 팔로 보이게 한다.
	# 배래 — 소매 아랫선이 활처럼 휘는 것이 한복의 결정적 곡선이다. 팔을 그 곡선으로 그린다.
	_limb(canvas, shoulder_main, hand, r * 0.26, r * 0.15, skin, r * 0.14)
	# 손. 무기가 어디서 나가는지 한 점으로 찍어 준다.
	canvas.draw_circle(hand, r * 0.14, skin)
	# 내지르는 순간에만 손끝에 잔광. 언제 터졌는지가 눈에 들어와야 한다(0-2 읽히는 설계).
	if swing > 0.25:
		var glow := GEUMBAK if taegi else HOBUN
		canvas.draw_circle(hand, r * 0.30 * swing, Color(glow.r, glow.g, glow.b, 0.34 * swing))


## 무보(대시) 잔상용 납작한 실루엣. 본체를 그대로 다시 그리지 않는 이유가 둘 있다.
## 하나는 비용 — 잔상 여섯 장이면 사지·탈·고름까지 여섯 번 그린다.
## 다른 하나가 더 중요하다: **잔상은 형태가 아니라 궤적을 보여 주는 것**이라 디테일이 살아 있으면
## 오히려 지금 몸이 어디인지가 흐려진다. 윤곽 한 덩어리로 뭉쳐야 속도로 읽힌다.
static func draw_shaman_ghost(canvas: CanvasItem, r: float, tint: Color) -> void:
	# 치마 — 실제 치마는 ClothBody 가 그리지만, 잔상에서 빠지면 같은 인물로 안 보인다.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.40, r * 0.10), Vector2(r * 0.40, r * 0.10),
		Vector2(r * 0.86, r * 1.05), Vector2(-r * 0.86, r * 1.05),
	]), tint)
	# 저고리 + 머리 + 고깔. 셋이 겹친 덩어리라 볼록 조각만으로 성립한다.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.44, -r * 0.20), Vector2(r * 0.44, -r * 0.20),
		Vector2(r * 0.40, r * 0.14), Vector2(-r * 0.40, r * 0.14),
	]), tint)
	canvas.draw_circle(Vector2(0.0, -r * 0.60), r * 0.36, tint)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r * 1.58), Vector2(r * 0.44, -r * 0.84), Vector2(-r * 0.44, -r * 0.84),
	]), tint)


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
