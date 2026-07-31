extends Node2D

## 무당의 몸을 **3D 로 렌더해 2D 화면에 합성**하는 노드(방식 C 프로토타입).
##
## `body_visual.gd`(2D 도형)와 **같은 인터페이스**를 노출한다 — bob/taegi/facing/swing/pose/
## mask_*/radius/get_hand(). 그래서 `player.gd` 는 어느 쪽이 붙었는지 몰라도 된다.
## 판정은 여전히 플레이어 루트에 있으므로 이 노드는 아무리 돌려도 게임에 영향이 없다(9-1-1).
##
## 왜 SubViewport 인가: 게임을 3D 로 옮기지 않고 **캐릭터만** 3D 로 본다. 씬·충돌·스폰·카메라가
## 전부 2D 그대로라 실패해도 되돌릴 것이 이 파일 하나다. 판단할 것은 하나다 —
## **빛과 부피가 생기면 캐릭터가 실제로 나아 보이는가.**
##
## 정식 모델(.glb)이 들어오면 `_build_rig()` 만 교체한다. 조명·카메라·합성은 그대로 쓴다.

## 리그가 차지하는 높이(유닛). 고깔 끝까지.
const RIG_TOP: float = 1.85
## 직교 카메라가 담는 세로 높이. 리그보다 넉넉해야 휘두를 때 팔이 잘리지 않는다.
const CAMERA_SIZE: float = 2.9
## 렌더 해상도. 화면에서는 50px 남짓으로 줄어드므로 크게 뽑아 내려 깎는다(공짜 안티에일리어싱).
const VIEWPORT_PX: int = 192
## 카메라 부감. 90 도면 진짜 탑다운이라 얼굴이 안 보이고, 0 도면 횡스크롤이 된다.
## 52 도로 시작했다가 낮췄다 — 위에서 내려다보니 고깔만 보여 **사람이 아니라 원뿔**로 읽혔다.
const CAMERA_PITCH_DEG: float = 34.0

## 먹선 두께(유닛). 3D 를 3D 처럼 두면 이 프로젝트의 무신도 톤에서 떨어져 나온다 —
## 윤곽을 먹으로 두르면 조명과 부피는 살리면서 그림은 2D 삽화 쪽에 남는다.
## 처음 0.016 은 화면에서 0.4px 라 **있으나 마나였다** — 캐릭터가 50px 로 줄어드는 것을
## 계산에 넣지 않은 값이었다. 유닛이 아니라 최종 픽셀로 굵기를 정해야 한다.
const OUTLINE: float = 0.055

## 2D 도형 몸이 차지하던 세로 비율. 3D 로 바꿔도 **같은 크기로 보여야** 비교가 된다.
const BODY_SPAN_RATIO: float = 2.63
const FEET_RATIO: float = 1.05

# --- body_visual.gd 와 같은 인터페이스 ---
var bob: float = 0.0
var taegi: bool = false
var facing: float = 0.0
var swing: float = 0.0
var pose: StringName = PlaceholderArt.POSE_SLASH
var mask_shape: StringName = &"jangsu"
var mask_color: Color = PlaceholderArt.HOBUN
var mask_mark_color: Color = PlaceholderArt.JUSA
var radius: float = 12.0
var texture: Texture2D
## 무복 색. 몸주가 정한다(GodData.robe_color).
var robe_color: Color = Color(0.62, 0.16, 0.15)
var sash_color: Color = Color(0.85, 0.64, 0.26)

var _viewport: SubViewport
var _sprite: Sprite2D
var _rig: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _mask: MeshInstance3D
var _arm_main: Node3D
var _arm_back: Node3D
var _legs: Array[Node3D] = []
var _weapons: Dictionary = {}
var _taegi_light: OmniLight3D
var _robe_material: StandardMaterial3D
var _sash_material: StandardMaterial3D
var _mask_material: StandardMaterial3D
var _mask_mark_material: StandardMaterial3D
## 손 위치(2D 로컬). 천의 그립과 무기 발사점이 여기 붙는다.
var _hand: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_viewport()
	_build_rig()
	_apply_layout()


func _process(delta: float) -> void:
	if _rig == null:
		return
	_apply_layout()
	_pose_rig(delta)
	# 손은 3D 에서 계산해 2D 로 되돌린다 — 천이 실제 손에 매달려야 하기 때문이다.
	_hand = _project_hand()


## 천(지전)이 매달릴 손 위치. `body_visual.gd` 와 시그니처가 같아야 player.gd 가 갈리지 않는다.
func get_hand() -> Vector2:
	return _hand


## 몸주 외형을 물린다. 색이 데이터에서 오는 구조는 2D 와 동일하다.
func apply_appearance(new_robe: Color, new_sash: Color) -> void:
	robe_color = new_robe
	sash_color = new_sash
	if _robe_material != null:
		_robe_material.albedo_color = robe_color
	if _sash_material != null:
		_sash_material.albedo_color = sash_color


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEWPORT_PX, VIEWPORT_PX)
	# 배경이 비어야 저승 바탕 위에 캐릭터만 얹힌다.
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	# 그림자 속이 새까매지지 않게 환경광을 넣는다. 색은 저승 밤의 푸른빛.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.38, 0.58)
	# 환경광을 낮춰야 그늘이 생긴다. 밝게 채우면 흰옷이 전부 같은 값이 되어 형태가 사라진다.
	env.ambient_light_energy = 0.32
	# 2D 게임이라 물려받을 3D 월드가 없다. 트리에 넣기 **전에** 자기 월드를 쥐어 준다 —
	# 넣은 뒤에 바꾸면 이미 잡힌 scenario 를 놓아 주다가 null 을 건드린다.
	var world := World3D.new()
	world.environment = env
	_viewport.world_3d = world
	add_child(_viewport)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.near = 0.05
	camera.far = 40.0
	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	var focus := Vector3(0.0, RIG_TOP * 0.5, 0.0)
	camera.position = focus + Vector3(0.0, sin(pitch), cos(pitch)) * 8.0
	camera.look_at_from_position(camera.position, focus, Vector3.UP)
	_viewport.add_child(camera)

	# 주광 — 앞 위에서. 그림자를 켜야 부피가 생긴다. 이게 2D 도형과의 진짜 차이다.
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.5
	key.shadow_enabled = true
	key.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-34.0), 0.0)
	_viewport.add_child(key)

	# 역광 — 뒤아래에서 넋빛. 윤곽이 배경에서 떨어져 나온다(어둠 + 발광 방향).
	var rim := DirectionalLight3D.new()
	rim.light_color = PlaceholderArt.NEOK
	rim.light_energy = 2.2
	rim.rotation = Vector3(deg_to_rad(18.0), deg_to_rad(168.0), 0.0)
	_viewport.add_child(rim)

	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)


## 원기둥·구·원뿔만으로 조립한다. 정식 모델이 오기 전까지의 3D 플레이스홀더라
## 2D 도형 실루엣과 **같은 규칙**을 따른다: 짧은 저고리 · 퍼지는 치마 · 고깔 · 탈.
func _build_rig() -> void:
	_rig = Node3D.new()
	_viewport.add_child(_rig)

	var skin := _material(Color(0.96, 0.91, 0.83))
	var white := _material(PlaceholderArt.HOBUN)
	_robe_material = _material(robe_color)
	_mask_material = _material(mask_color)

	_hips = Node3D.new()
	_rig.add_child(_hips)

	# 다리 — 치마 밑으로 정강이와 버선이 보여야 "움직이고 있다"가 읽힌다.
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.11, 0.52, 0.0)
		_hips.add_child(leg)
		var shin := CapsuleMesh.new()
		shin.radius = 0.055
		shin.height = 0.44
		_mesh(leg, shin, skin, Vector3(0.0, -0.20, 0.0))
		var foot := SphereMesh.new()
		foot.radius = 0.072
		foot.height = 0.13
		_mesh(leg, foot, white, Vector3(0.0, -0.44, 0.04))
		_legs.append(leg)

	# 치마 — 허리에서 퍼지되 **종이 되지 않게** 밑변을 좁게 잡는다. 처음에 밑변을 키웠더니
	# 사람이 아니라 등불로 읽혔다. 한복 치마는 넓어도 키의 1/5 을 넘지 않는다.
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.16
	skirt.bottom_radius = 0.27
	skirt.height = 0.52
	skirt.radial_segments = 20
	_mesh(_hips, skirt, _robe_material, Vector3(0.0, 0.70, 0.0))

	_torso = Node3D.new()
	_torso.position = Vector3(0.0, 0.96, 0.0)
	_hips.add_child(_torso)

	# 저고리 — 가슴 밑에서 끝나는 짧은 상의. 치마와의 경계가 실루엣의 핵심이다.
	var jeogori := CylinderMesh.new()
	jeogori.top_radius = 0.20
	jeogori.bottom_radius = 0.22
	jeogori.height = 0.34
	jeogori.radial_segments = 16
	_mesh(_torso, jeogori, white, Vector3(0.0, 0.17, 0.0))

	# 홍띠 — 허리를 한 바퀴. 가는 띠 하나가 상하를 갈라 준다.
	_sash_material = _material(sash_color)
	var sash := CylinderMesh.new()
	sash.top_radius = 0.225
	sash.bottom_radius = 0.225
	sash.height = 0.06
	sash.radial_segments = 16
	_mesh(_torso, sash, _sash_material, Vector3(0.0, 0.02, 0.0))

	# 깃·동정 — 목에서 여미는 군청 두 획. 한복으로 읽히게 하는 가장 싼 디테일이다(9-1-1).
	for side: float in [-1.0, 1.0]:
		var collar := BoxMesh.new()
		collar.size = Vector3(0.055, 0.26, 0.03)
		var collar_node := _mesh(_torso, collar, _material(PlaceholderArt.GUNCHEONG),
			Vector3(side * 0.075, 0.26, 0.185), OUTLINE * 0.5)
		collar_node.rotation = Vector3(0.0, 0.0, side * deg_to_rad(16.0))

	# 고름 — 가슴에서 늘어진 붉은 끈.
	var tie := BoxMesh.new()
	tie.size = Vector3(0.04, 0.22, 0.02)
	_mesh(_torso, tie, _material(PlaceholderArt.JUSA),
		Vector3(0.06, 0.13, 0.20), OUTLINE * 0.5)

	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.42, 0.0)
	_torso.add_child(_head)
	var skull := SphereMesh.new()
	skull.radius = 0.16
	skull.height = 0.32
	_mesh(_head, skull, skin, Vector3.ZERO)

	# 탈 — 얼굴 앞에 붙는 판. `[고증]` 굿에서 신을 청할 때 그 신의 탈을 쓴다.
	var mask_mesh := SphereMesh.new()
	mask_mesh.radius = 0.148
	mask_mesh.height = 0.30
	_mask = _mesh(_head, mask_mesh, _mask_material, Vector3(0.0, 0.0, 0.085))
	_mask.scale = Vector3(1.0, 1.1, 0.55)
	# 탈의 획 — 눈꼬리 둘과 이마 한 획. 눈코입을 그리지 않는 이유는 9-1-2 와 같다:
	# 사람 얼굴 비례는 조금만 어긋나도 "못생겼다"가 되지만 탈의 획은 그 판정이 없다.
	_mask_mark_material = _material(mask_mark_color)
	var brow := BoxMesh.new()
	brow.size = Vector3(0.17, 0.028, 0.02)
	_mesh(_head, brow, _mask_mark_material, Vector3(0.0, 0.055, 0.155), 0.0)
	for side: float in [-1.0, 1.0]:
		var eye := BoxMesh.new()
		eye.size = Vector3(0.075, 0.022, 0.02)
		var eye_node := _mesh(_head, eye, _mask_mark_material,
			Vector3(side * 0.058, -0.012, 0.152), 0.0)
		eye_node.rotation = Vector3(0.0, 0.0, side * deg_to_rad(-18.0))

	# 고깔 — 강신무의 관. 원뿔 하나로 실루엣이 단번에 잡힌다.
	var hat := CylinderMesh.new()
	hat.top_radius = 0.0
	hat.bottom_radius = 0.165
	hat.height = 0.34
	hat.radial_segments = 14
	_mesh(_head, hat, white, Vector3(0.0, 0.26, -0.02))
	# 고깔 밑의 먹띠. 머리와 관을 갈라 주지 않으면 흰 원뿔이 얼굴까지 흘러내린다.
	var band := CylinderMesh.new()
	band.top_radius = 0.168
	band.bottom_radius = 0.175
	band.height = 0.045
	band.radial_segments = 14
	_mesh(_head, band, _material(PlaceholderArt.GUNCHEONG), Vector3(0.0, 0.11, -0.02),
		OUTLINE * 0.5)

	_arm_main = _build_arm(skin, 1.0)
	_arm_back = _build_arm(skin, -1.0)

	_taegi_light = OmniLight3D.new()
	_taegi_light.light_color = PlaceholderArt.GEUMBAK
	_taegi_light.light_energy = 0.0
	_taegi_light.omni_range = 3.0
	_taegi_light.position = Vector3(0.0, 1.0, 0.4)
	_rig.add_child(_taegi_light)


## 어깨에 달린 회전축 + 팔 + 손. 무기는 손에 매단다 — 무엇을 들었는지가 3D 에서는 그대로 보인다.
func _build_arm(skin: StandardMaterial3D, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.26, 0.27, 0.02)
	_torso.add_child(pivot)

	var upper := CapsuleMesh.new()
	upper.radius = 0.05
	upper.height = 0.38
	_mesh(pivot, upper, skin, Vector3(0.0, -0.17, 0.0))

	var hand := Node3D.new()
	hand.position = Vector3(0.0, -0.36, 0.0)
	pivot.add_child(hand)
	var fist := SphereMesh.new()
	fist.radius = 0.065
	fist.height = 0.13
	_mesh(hand, fist, skin, Vector3.ZERO)

	if side > 0.0:
		_build_weapons(hand)
	return pivot


## 무기 셋을 손에 매달아 두고 pose 에 따라 하나만 보인다.
## 2D 에서는 손 위치로만 구분되던 것이 3D 에서는 **실물로** 구분된다.
func _build_weapons(hand: Node3D) -> void:
	var steel := _material(Color(0.86, 0.89, 0.94))
	steel.metallic = 0.7
	steel.roughness = 0.28
	var wood := _material(Color(0.42, 0.33, 0.26))

	# 무기는 손에서 **팔이 뻗은 방향(-Y)으로 이어져** 나간다. 앞(+Z)으로 삐죽 내밀면
	# 팔과 무기가 남남으로 보인다 — 쥐고 있다는 것이 방향의 연속으로 읽혀야 한다.

	# 작두 — 짧고 넓은 외날.
	var jakdu := Node3D.new()
	hand.add_child(jakdu)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.045, 0.56, 0.13)
	var blade_node := _mesh(jakdu, blade, steel, Vector3(0.0, -0.30, 0.02))
	blade_node.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)
	_weapons[PlaceholderArt.POSE_SLASH] = jakdu

	# 언월도 — 긴 자루 + 끝에 붙은 초승달 날. 손 위아래로 걸쳐야 장병기로 보인다.
	var eonwoldo := Node3D.new()
	hand.add_child(eonwoldo)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.026
	shaft.bottom_radius = 0.026
	shaft.height = 1.10
	_mesh(eonwoldo, shaft, wood, Vector3(0.0, -0.38, 0.0))
	var crescent := BoxMesh.new()
	crescent.size = Vector3(0.04, 0.26, 0.15)
	var crescent_node := _mesh(eonwoldo, crescent, steel, Vector3(0.0, -1.00, 0.06))
	crescent_node.rotation = Vector3(deg_to_rad(-22.0), 0.0, 0.0)
	_weapons[PlaceholderArt.POSE_SPIN] = eonwoldo

	# 부적 — 손에 쥔 종이. 얇아야 종이로 보인다.
	var bujeok := Node3D.new()
	hand.add_child(bujeok)
	var paper := BoxMesh.new()
	paper.size = Vector3(0.13, 0.24, 0.01)
	var paper_material := _material(Color(0.95, 0.86, 0.42))
	# 부적은 술법의 매개라 스스로 빛나야 한다 — 종이가 아니라 기운으로 읽힌다.
	paper_material.emission_enabled = true
	paper_material.emission = PlaceholderArt.JUSA
	paper_material.emission_energy_multiplier = 0.6
	_mesh(bujeok, paper, paper_material, Vector3(0.0, -0.14, 0.03))
	_weapons[PlaceholderArt.POSE_THROW] = bujeok


## 화면에서 2D 도형 몸과 **같은 크기**로 보이게 맞춘다. 크기가 다르면 무엇이 나아졌는지 판단할 수 없다.
func _apply_layout() -> void:
	if _sprite == null:
		return
	# 부감으로 눕혀 보므로 세로가 코사인만큼 눌린다. 그걸 감안해야 실제 크기가 맞는다.
	var apparent := RIG_TOP * cos(deg_to_rad(CAMERA_PITCH_DEG))
	var rig_px := apparent / CAMERA_SIZE * float(VIEWPORT_PX)
	if rig_px <= 0.0:
		return
	var target := BODY_SPAN_RATIO * radius
	var s := target / rig_px
	_sprite.scale = Vector2(s, s)
	# 발이 2D 몸과 같은 자리에 오도록 스프라이트를 올린다(스프라이트는 중앙 정렬이라 그냥 두면 뜬다).
	_sprite.position = Vector2(0.0, (FEET_RATIO - BODY_SPAN_RATIO * 0.5) * radius)


## 플레이어 상태를 3D 포즈로 옮긴다. 2D 판이 하던 것과 같은 규칙을 3차원으로 늘린 것뿐이다.
func _pose_rig(delta: float) -> void:
	# 몸이 도는 것 — 이게 3D 로 옮긴 이유의 절반이다. 2D 에서는 좌우 반전밖에 없었다.
	_rig.rotation.y = lerp_angle(_rig.rotation.y, PI * 0.5 - facing, 1.0 - exp(-14.0 * delta))

	# 걸음 — 위아래로 흔들리고 다리가 엇갈린다.
	_hips.position.y = absf(bob) * 0.045
	var stride := bob * 0.55
	for i in _legs.size():
		var side := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = stride * side

	# 휘두름 — 예비(swing<0)에서 감고 타격(swing>0)에서 내지른다.
	_torso.rotation.y = swing * 0.55
	_torso.rotation.x = -swing * 0.18
	_arm_main.rotation = _arm_pose(swing)
	# 뒷팔은 반대로 움직여 균형을 잡는다. 둘이 같이 가면 인형처럼 보인다.
	_arm_back.rotation = Vector3(0.15 + swing * 0.8, 0.0, -0.16)

	_show_weapon()

	if _mask_mark_material != null:
		_mask_mark_material.albedo_color = mask_mark_color
	if _mask_material != null:
		_mask_material.albedo_color = mask_color
		# 강림하면 탈이 스스로 빛난다. 얼굴이 바뀌는 것이 곧 신이 내린 것이다.
		_mask_material.emission_enabled = taegi
		_mask_material.emission = PlaceholderArt.GEUMBAK
		_mask_material.emission_energy_multiplier = 1.4 if taegi else 0.0
	if _taegi_light != null:
		_taegi_light.light_energy = 3.2 if taegi else 0.0


## 포즈마다 팔이 다르게 간다. 팔은 -Y(아래)로 뻗어 있고, X 회전이 앞뒤 · Y 회전이 좌우 쓸기다.
## reach 는 -1(예비)~1(타격). **reach 가 0 이면 자연스럽게 내려와 있어야** 한다 —
## 처음엔 0 에서도 팔이 머리 위로 올라가 있어 가만히 서 있을 때가 가장 어색했다.
func _arm_pose(reach: float) -> Vector3:
	match pose:
		PlaceholderArt.POSE_SLASH_BACK:
			# 되돌려베기 — 좌우 쓸기가 반대다. 이게 1타와 2타의 차이 전부다.
			return Vector3(0.2 - reach * 1.6, reach * 0.85, 0.16)
		PlaceholderArt.POSE_THRUST:
			# 찌르기 — 좌우로 쓸지 않고 앞으로만 뻗는다.
			return Vector3(0.35 - reach * 2.0, 0.0, 0.1)
		PlaceholderArt.POSE_THROW:
			# 던지기 — 당겼다 튕긴다. 팔이 몸 앞을 가로지르지 않는다.
			return Vector3(0.55 - reach * 1.7, -0.25 * reach, 0.25)
		PlaceholderArt.POSE_SPIN:
			# 창술 — 자루째 크게 돈다. 팔을 옆으로 벌려야 장병기가 몸에 안 걸린다.
			return Vector3(-0.15 - reach * 0.4, reach * 2.2, 0.85)
		_:
			# 기본 베기 — 뒤로 감았다가 앞을 가로질러 쓴다.
			return Vector3(0.2 - reach * 1.6, -reach * 0.85, 0.16)


## pose 에 맞는 무기만 손에 남긴다. 베기 3종은 전부 작두다.
func _show_weapon() -> void:
	var wanted: StringName = pose
	if pose == PlaceholderArt.POSE_SLASH_BACK or pose == PlaceholderArt.POSE_THRUST:
		wanted = PlaceholderArt.POSE_SLASH
	for key: StringName in _weapons:
		var node: Node3D = _weapons[key]
		node.visible = key == wanted


## 3D 손을 화면 좌표로 되돌린다. 천이 실제 손에 매달려야 종이 술이 손에서 논다.
func _project_hand() -> Vector2:
	if _arm_main == null or _sprite == null:
		return _hand
	var hand_node := _arm_main.get_child(_arm_main.get_child_count() - 1) as Node3D
	if hand_node == null:
		return _hand
	var world := hand_node.global_position
	var camera := _viewport.get_camera_3d()
	if camera == null:
		return _hand
	# 뷰포트 픽셀 → 스프라이트 로컬 → 이 노드의 로컬. 스프라이트가 중앙 정렬이라 절반을 빼 준다.
	var screen := camera.unproject_position(world)
	var centered := screen - Vector2(VIEWPORT_PX, VIEWPORT_PX) * 0.5
	return _sprite.position + centered * _sprite.scale


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = 0.0
	return material


func _mesh(parent: Node3D, mesh: Mesh, material: StandardMaterial3D,
		offset: Vector3, outline: float = OUTLINE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = offset
	parent.add_child(node)
	if outline > 0.0:
		_add_outline(node, mesh, outline)
	return node


## 먹선 — 같은 메시를 조금 부풀려 **앞면을 버리고** 검게 그린다. 뒷면만 남으므로
## 형태 뒤로 테두리만 삐져나온다(툰 아웃라인의 고전적인 방법).
## 이게 없으면 흰 저고리와 흰 치마가 한 덩어리로 뭉쳐 사람으로 안 읽힌다 — 실제로 그랬다.
func _add_outline(host: MeshInstance3D, mesh: Mesh, thickness: float) -> void:
	var ink := StandardMaterial3D.new()
	ink.albedo_color = PlaceholderArt.MEOK
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.cull_mode = BaseMaterial3D.CULL_FRONT
	ink.grow = true
	ink.grow_amount = thickness
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = ink
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
