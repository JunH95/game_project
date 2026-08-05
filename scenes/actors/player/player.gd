extends CharacterBody2D

## 플레이어. M1: 8방향 이동 + 접촉 피격(HP·i-frame) + 사망 시 씬 리셋.
## 외형은 PlaceholderArt 의 무당 실루엣. texture 를 물리면 그쪽이 우선한다.

const RADIUS: float = 12.0

## 걸음의 위아래 흔들림. 정지하면 잦아든다 — 서 있는데 계속 들썩이면 조작이 안 먹는 것처럼 보인다.
const BOB_SPEED: float = 11.0
const BOB_SETTLE: float = 8.0

const FACE_TURN_RATE: float = 9.0

## 휘두름 모션. 예비(뒤로 감음) → 타격(내지름) → 복귀 세 마디로 나눈다.
## 한 마디짜리로 그냥 뻗기만 하면 때리는 게 아니라 미는 것처럼 보인다.
const SWING_WINDUP: float = 0.07
const SWING_STRIKE: float = 0.06
const SWING_RECOVER: float = 0.15
## 예비에서 뒤로 감는 깊이(음수), 타격에서 내지르는 길이(양수).
const SWING_BACK: float = -0.38
const SWING_FORWARD: float = 1.0
## 타격 순간 무복을 미는 세기. 몸이 움직이면 천이 따라 휘는 것이 화려함의 본체다.
const SWING_CLOTH_POWER: float = 1.5

## 몸의 역동성. 그림 노드(Body)만 움직이므로 판정에는 영향이 없다.
## 위에서 내려다보는 판이라 각도는 작게 — 크면 넘어진 것처럼 보인다.
const BODY_TILT: float = 0.16
## 휘두를 때 몸이 도는 각. 예비에서는 반대로 감긴다.
const SWING_TILT: float = 0.34
## 예비에서 눌리는 양(가로로 퍼지고 세로로 낮아진다).
const SQUASH: float = 0.18
## 타격에서 늘어나는 양. 눌렸다 늘어나는 이 대비가 만화적 타격감의 핵심이다.
const STRETCH: float = 0.15
## 타격 때 앞으로 나갔다 돌아오는 거리(px).
const LUNGE: float = 3.6
## 몸이 목표 각도를 좇는 속도. 즉시 돌리면 딱딱하다.
const BODY_TURN: float = 18.0

## 무보(舞步) — 굿의 발놀림에서 이름을 가져온 짧은 회피(design.md 7-6).
## 이동만이 유일한 조작인 게임에서 둘러싸였을 때 빠져나갈 수단이 아무것도 없으면
## 억울한 죽음이 나온다. 무적을 주지 않는 이유는 그러면 회피가 아니라 무시가 되기 때문이다 —
## 대신 **짧고 빠르게** 빠져나가되 피격은 그대로 받는다.
const DASH_SPEED: float = 620.0
const DASH_TIME: float = 0.14
const DASH_COOLDOWN: float = 1.6
const DASH_TILT: float = 0.62

## 인간성을 한 번 내줄 때마다 탈의 획이 바탕에 묻히는 정도(design.md 3-7-3).
const HUMANITY_BLUR_STEP: float = 0.22

## 정식 아트가 들어오면 여기에 물리고, 도형 실루엣은 자동으로 비켜난다.
@export var texture: Texture2D

## 3D 캐릭터(SubViewport 합성) 프로토타입을 쓸지. 끄면 2D 도형 몸으로 되돌아간다 —
## 둘을 나란히 남겨 둔 이유는 **바꿔 보고 판단하려는 것**이고, 실패하면 이 값 하나로 물러선다.
@export var use_3d_visual: bool = true

## 신내림 수정자를 물어볼 GodSystem. main.tscn 에서 주입한다.
@export var god_system_path: NodePath
## 합 성립을 물어볼 SynergySystem. 작두타기처럼 합이 여는 기능이 이걸 본다.
@export var synergy_system_path: NodePath

var _god_system: Node
## { weapon_id: 무기 노드 } — 몸주·신이 열어 준 것만 켠다.
var _weapons: Dictionary = {}
var _synergy_system: Node
## 합이 열어 주는 궤도들(OrbitBlades). 각자 required_synergy 를 들고 있다.
var _synergy_orbits: Array = []
var _taegi: bool = false
## 휘두름 경과 시간. 0 보다 크면 모션 중이다.
var _swing_time: float = 0.0
var _swing_total: float = 0.0
## 지금 하고 있는 동작의 종류(베기/던지기/들기). 마지막으로 나간 무기가 정한다.
var _pose: StringName = PlaceholderArt.POSE_SLASH
## 작두 연타의 몇 번째 타인지. 벨 때마다 궤적이 바뀐다.
var _slash_step: int = 0
## 무보(회피) 상태. 남은 시간이 0 보다 크면 그 방향으로 미끄러진다.
var _dash_left: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _bob_phase: float = 0.0
## 0.0~1.0. 걸을수록 오르고 멈추면 내려간다. 흔들림의 크기를 여기에 곱한다.
var _bob_weight: float = 0.0
var _facing: float = 0.0
var _base_speed: float = 0.0
var _base_max_hp: float = 0.0
var _base_magnet_radius: float = 0.0

@onready var _movement: MovementComponent = %MovementComponent
@onready var _health: HealthComponent = %HealthComponent
@onready var _hurtbox: HurtboxComponent = %HurtboxComponent
@onready var _magnet: Area2D = %PickupMagnet
@onready var _cloth: ClothBody = get_node_or_null(^"%ClothBody")
@onready var _dash_trail: Node2D = get_node_or_null(^"%DashTrail")
@onready var _body: Node2D = get_node_or_null(^"%Body")


func _ready() -> void:
	_select_visual()
	_hurtbox.health = _health
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	_magnet.area_entered.connect(_on_magnet_area_entered)

	if not god_system_path.is_empty():
		_god_system = get_node_or_null(god_system_path)
	# 수정자는 기본값에 곱하므로 원본을 따로 보관한다(누적 곱을 막기 위함).
	_base_speed = _movement.speed
	_base_max_hp = _health.max_hp
	var magnet_shape := _magnet.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if magnet_shape != null and magnet_shape.shape is CircleShape2D:
		# 씬의 sub_resource 는 인스턴스끼리 공유돼 반경을 고치면 다음 런까지 남는다. 복제해서 쓴다.
		magnet_shape.shape = magnet_shape.shape.duplicate()
		_base_magnet_radius = (magnet_shape.shape as CircleShape2D).radius

	# 어떤 무기를 들고 시작할지는 몸주가 정한다(design.md 3-1-1). 그래서 전부 꺼 두고
	# 몸주·신이 열어 주는 것만 켠다. 작두도 예외가 아니다 — 작도대신의 시작 무기일 뿐이다.
	_weapons = {
		&"jakdu": get_node_or_null(^"%JakduWeapon"),
		&"bujeok": get_node_or_null(^"%BujeokWeapon"),
		&"eonwoldo": get_node_or_null(^"%EonwoldoWeapon"),
	}
	if not synergy_system_path.is_empty():
		_synergy_system = get_node_or_null(synergy_system_path)
	for weapon in _weapons.values():
		if weapon != null:
			weapon.god_system = _god_system
			weapon.process_mode = Node.PROCESS_MODE_DISABLED
	# 작두타기는 합이 여는 기능이라 작두만 합 시스템을 본다.
	var jakdu := _weapons.get(&"jakdu") as JakduWeapon
	if jakdu != null:
		jakdu.synergy_system = _synergy_system
		# 무기가 혼자 움직이면 미는 것처럼 보인다. 몸이 같이 나가야 때리는 것이 된다.
		jakdu.swung.connect(_on_jakdu_swung)
	var bujeok := _weapons.get(&"bujeok") as BujeokWeapon
	if bujeok != null:
		bujeok.fired.connect(_on_weapon_swung.bind(PlaceholderArt.POSE_THROW))
	var eonwoldo := _weapons.get(&"eonwoldo") as EonwoldoWeapon
	if eonwoldo != null:
		eonwoldo.swung.connect(_on_weapon_swung.bind(PlaceholderArt.POSE_SPIN))

	# 합이 여는 궤도들. 무기가 아니라 합에 딸린 것이라 무기 맵과 따로 둔다.
	_synergy_orbits = [get_node_or_null(^"%JakduOrbit"), get_node_or_null(^"%BujeokShield")]
	for orbit in _synergy_orbits:
		if orbit != null:
			orbit.god_system = _god_system
			orbit.process_mode = Node.PROCESS_MODE_DISABLED

	if _god_system != null:
		# player_leveled_up 은 신을 고르기 "전"에 오므로 그걸로 갱신하면 능력치가 한 픽씩 밀린다.
		# 몸주 확정도 내부적으로 serve() 를 거치므로 이 하나로 둘 다 덮는다.
		EventBus.god_served.connect(_on_god_served)
	# 합 성립 신호도 직접 받는다. god_served 만 보면 SynergySystem 이 먼저 연결됐다는
	# 우연에 기대게 된다.
	EventBus.synergy_formed.connect(_on_synergy_formed)

	# 작두타기가 발동하면 몸에 금빛이 실린다 — 지금이 그 순간임을 몸으로도 보여 준다.
	EventBus.taegi_state_changed.connect(_on_taegi_state_changed)
	# 대가는 god_served 보다 뒤에 청구되므로 얼굴은 이 신호로 다시 맞춘다.
	EventBus.price_total_changed.connect(_on_price_total_changed)

	# health_changed 는 피격 때만 오므로 시작 체력을 한 번 알린다.
	# 지연시키는 이유: 플레이어가 HUD 보다 먼저 _ready 를 돌아, 즉시 쏘면 구독 전에 사라진다.
	_announce_health.call_deferred()


func _announce_health() -> void:
	EventBus.player_health_changed.emit(_health.hp, _health.max_hp)


## 신을 새로 모시면(몸주 확정 포함) 능력치와 열린 무기를 다시 계산한다.
func _on_god_served(_god: GodData) -> void:
	_apply_god_mods()
	_apply_mask()
	_apply_cloth()


## 2D 도형 몸과 3D 리그 중 하나만 남긴다. 둘 다 `%Body` 와 같은 인터페이스라
## 여기서 고르고 나면 아래 코드는 어느 쪽이 붙었는지 몰라도 된다.
func _select_visual() -> void:
	var body_2d := get_node_or_null(^"%Body") as Node2D
	var body_3d := get_node_or_null(^"%Body3D") as Node2D
	var chosen := body_3d if use_3d_visual and body_3d != null else body_2d
	var dropped := body_2d if chosen == body_3d else body_3d
	if chosen == null:
		push_error("플레이어에 몸 그림 노드가 없다(%Body / %Body3D).")
		return
	_body = chosen
	chosen.visible = true
	chosen.process_mode = Node.PROCESS_MODE_INHERIT
	if dropped != null:
		dropped.visible = false
		# 안 보이는 몸이 계속 손 위치를 계산하면 프레임만 먹는다.
		dropped.process_mode = Node.PROCESS_MODE_DISABLED
	# 3D 리그는 자기 치마를 들고 있다. 2D 천을 같이 두면 겹쳐서 둘 다 망가진다 —
	# 절차적 천을 3D 로 옮기는 것은 프로토타입 다음 문제다.
	if _cloth != null and chosen == body_3d:
		_cloth.visible = false


## 탈은 몸주가 정한다 — 신이 내리면 얼굴이 바뀐다.
## 얼굴을 그리지 않아 사람 얼굴 비례 문제를 피하고, 동시에 몸주마다 실루엣이 갈린다.
func _apply_mask() -> void:
	if _body == null or _god_system == null:
		return
	var momju: GodData = _god_system.get_momju() if _god_system.has_method(&"get_momju") else null
	if momju == null:
		return
	_body.mask_shape = momju.mask_shape
	_body.mask_color = momju.mask_color
	# 인간성을 내줄수록 탈의 획이 바탕에 묻힌다 — **얼굴이 흐려진다**(design.md 3-7-3).
	# 눈코입을 지우는 게 아니라 표정이 읽히지 않게 되는 쪽이라야 "사람에서 멀어졌다"가 된다.
	var blur := clampf(float(RunManager.humanity_paid) * HUMANITY_BLUR_STEP, 0.0, 0.8)
	_body.mask_mark_color = momju.mask_mark_color.lerp(momju.mask_color, blur)


## 무복은 몸주가 정하고, 모실수록 자락이 자란다. 새 그림이 아니라 값이라 여기서 끝난다.
func _apply_cloth() -> void:
	if _cloth == null or _god_system == null:
		return
	var momju: GodData = _god_system.get_momju() if _god_system.has_method(&"get_momju") else null
	if momju != null:
		# 3D 리그가 붙어 있으면 무복 색이 천이 아니라 재질로 간다. 값이 데이터에서 오는 구조는 같다.
		if _body != null and _body.has_method(&"apply_appearance"):
			_body.call(&"apply_appearance", momju.robe_color, momju.sash_color)
		_cloth.robe_color = momju.robe_color
		_cloth.sash_color = momju.sash_color
		_cloth.cloth_weight = momju.cloth_weight
		_cloth.rib_count = momju.rib_count
		_cloth.segment_length = momju.segment_length
		_cloth.spread = momju.cloth_spread
		_cloth.rebuild()
	# 최영장군을 모시면 등 뒤에 전기가 나부낀다 — 표식도 천이라 같은 물리에 얹힌다.
	_cloth.set_banner_visible(_god_system.get_level(&"choeyeong") > 0)
	_cloth.set_growth(_god_system.get_served_count()
		if _god_system.has_method(&"get_served_count") else 0)


func _on_synergy_formed(_synergy: SynergyData) -> void:
	_refresh_synergy_orbits()


## 합이 열린 궤도만 켠다. 한 번 열리면 런이 끝날 때까지 유지된다.
func _refresh_synergy_orbits() -> void:
	if _synergy_system == null:
		return
	for orbit in _synergy_orbits:
		if orbit != null and _synergy_system.is_active(orbit.required_synergy):
			orbit.process_mode = Node.PROCESS_MODE_INHERIT


func _apply_god_mods() -> void:
	if _god_system == null:
		return
	_movement.speed = _base_speed * _god_system.get_multiplier(&"move_speed_pct")

	# 최대 체력이 늘면 늘어난 만큼 현재 체력도 채운다. 안 그러면 상한만 오르고 체감이 없다.
	var new_max: float = _base_max_hp * _god_system.get_multiplier(&"max_hp_pct")
	var gained: float = new_max - _health.max_hp
	_health.max_hp = new_max
	if gained > 0.0:
		_health.hp = minf(new_max, _health.hp + gained)
	_health.health_changed.emit(_health.hp, _health.max_hp)

	var magnet_shape := _magnet.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if magnet_shape != null and magnet_shape.shape is CircleShape2D:
		var circle := magnet_shape.shape as CircleShape2D
		circle.radius = _base_magnet_radius * _god_system.get_multiplier(&"pickup_radius_pct")

	# 방어 계열 신(신장)은 받는 피해를 줄인다.
	_hurtbox.damage_multiplier = _god_system.get_multiplier(&"damage_taken_pct")

	# 몸주와 신이 무기를 열어 준다. 한 번 열리면 런이 끝날 때까지 유지된다.
	for weapon_id: StringName in _weapons:
		var weapon: Node = _weapons[weapon_id]
		if weapon != null and _god_system.grants_weapon(weapon_id):
			weapon.process_mode = Node.PROCESS_MODE_INHERIT
	_refresh_synergy_orbits()


## 자석 반경에 들어온 픽업은 플레이어를 향해 끌려온다. 수집 판정은 픽업 쪽이 한다.
func _on_magnet_area_entered(area: Area2D) -> void:
	if area.has_method(&"attract_to"):
		area.call(&"attract_to", self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dash"):
		if _try_dash():
			get_viewport().set_input_as_handled()
		return
	# `[고증]` 신은 저절로 오지 않고 불러야 온다. 자동 발동이면 판단이 사라진다.
	if not event.is_action_pressed(&"gangrim"):
		return
	var jakdu := _weapons.get(&"jakdu") as JakduWeapon
	if jakdu != null and jakdu.invoke_taegi():
		get_viewport().set_input_as_handled()


## 무보 — 짧게 미끄러져 포위를 빠져나간다. 쿨다운 중이면 false 를 돌려 헛발질을 알린다.
func _try_dash() -> bool:
	if _dash_cooldown > 0.0 or _dash_left > 0.0:
		return false
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# 가만히 선 채로 누르면 보고 있는 쪽으로 나간다 — 아무 일도 안 일어나면 눌린 줄 모른다.
	_dash_dir = input.normalized() if not input.is_zero_approx() else Vector2.from_angle(_facing)
	_dash_left = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	if _cloth != null:
		# 자락이 뒤로 확 끌린다. 빠르게 움직였다는 것이 천으로 먼저 보인다.
		_cloth.impulse(-_dash_dir, 2.4)
	if _dash_trail != null:
		_dash_trail.call(&"burst", global_position, _dash_dir)
	AudioManager.play(&"jakdu_swing")
	return true


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	if _dash_left > 0.0:
		_dash_left -= delta
		# 끝으로 갈수록 잦아든다. 등속으로 끊으면 벽에 부딪힌 것처럼 멈춘다.
		var ease_out := clampf(_dash_left / DASH_TIME, 0.0, 1.0)
		velocity = _dash_dir * DASH_SPEED * (0.35 + 0.65 * ease_out)
		move_and_slide()
		_facing = _dash_dir.angle()
		# 옮긴 **뒤에** 남긴다 — 이동 전 위치를 기록하면 첫 잔상이 몸에 겹쳐 궤적이 한 칸 짧아진다.
		if _dash_trail != null and _body != null:
			_dash_trail.call(&"record", global_position, _body, RADIUS)
	else:
		_movement.move(direction)

	# 걸음 흔들림. 플레이어는 하나뿐이라 매 프레임 다시 그려도 부담이 없다.
	# 몸을 회전·반전시키지 않는 이유: 자식으로 달린 무기(작두 부채꼴·궤도)까지 같이 뒤집힌다.
	var target_weight := 1.0 if not direction.is_zero_approx() else 0.0
	_bob_weight = move_toward(_bob_weight, target_weight, BOB_SETTLE * delta)
	if _bob_weight > 0.0:
		_bob_phase += BOB_SPEED * delta

	if _swing_total > 0.0:
		_swing_time += delta
		if _swing_time >= _swing_total:
			_swing_total = 0.0
			_swing_time = 0.0
	elif _bob_weight > 0.0:
		# 휘두르는 동안에는 걷는 쪽으로 몸을 돌리지 않는다 — 벤 방향을 보고 있어야 한다.
		# 즉시 돌리면 지전이 덜덜 떨리므로 부드럽게 좇는다.
		_facing = rotate_toward(_facing, direction.angle(), FACE_TURN_RATE * delta)
	_update_body(delta)


## 그림 노드만 기울이고 찌그러뜨린다. 무기는 루트에 있으므로 판정은 그대로다.
func _update_body(delta: float) -> void:
	if _body == null:
		return
	var reach := _swing_reach()
	var dir := Vector2.from_angle(_facing)
	var bob := sin(_bob_phase) * _bob_weight

	# 이동 방향으로 기운다. 달리는 쪽으로 상체가 쏠려야 서 있는 판때기가 아니게 된다.
	var move_tilt := clampf(velocity.x / maxf(1.0, _movement.speed), -1.0, 1.0) * BODY_TILT
	# 휘두르면 그쪽으로 돈다. 예비(reach<0)에서는 반대로 감긴다.
	var swing_tilt := reach * SWING_TILT * (1.0 if dir.x >= 0.0 else -1.0)
	_body.rotation = lerp_angle(_body.rotation, move_tilt + swing_tilt,
		1.0 - exp(-BODY_TURN * delta))

	# 무보 중에는 진행 방향으로 몸을 눕힌다. 속도는 숫자가 아니라 기울기로 읽힌다.
	var dash_weight := clampf(_dash_left / DASH_TIME, 0.0, 1.0)
	if dash_weight > 0.0:
		_body.rotation = lerp_angle(_body.rotation,
			DASH_TILT * signf(_dash_dir.x if absf(_dash_dir.x) > 0.01 else 1.0) * dash_weight,
			1.0 - exp(-BODY_TURN * 1.6 * delta))

	# 눌렸다 늘어난다. 예비에서 웅크리고 타격에서 뻗는 대비가 타격감을 만든다.
	if reach < 0.0:
		_body.scale = Vector2(1.0 + SQUASH * -reach, 1.0 - SQUASH * 0.8 * -reach)
	else:
		_body.scale = Vector2(1.0 - STRETCH * 0.7 * reach, 1.0 + STRETCH * reach)
	# 달리는 방향으로 늘어나 잔상처럼 보인다.
	_body.scale *= Vector2(1.0 - 0.18 * dash_weight, 1.0 + 0.14 * dash_weight)

	# 타격 순간 앞으로 나갔다 돌아온다.
	_body.position = dir * (LUNGE * maxf(reach, 0.0))

	_body.bob = bob
	_body.taegi = _taegi
	_body.facing = _facing
	_body.swing = reach
	_body.pose = _pose
	_body.radius = RADIUS
	_body.texture = texture
	# 다시 그리는 것은 Body 가 자기 _process 에서 한다(손 지연을 거기서 계산하므로).

	# 무구를 쥔 손 — 지전이 여기 매달린다. 몸이 돌고 찌그러지므로 **그 변환을 거쳐** 넘겨야
	# 종이 술이 손에서 논다. 로컬 좌표를 그대로 주면 몸만 기울고 술은 제자리에 남는다.
	if _cloth != null:
		# Body 가 실제로 그린 손(지연 적용분)을 그대로 쓴다. 여기서 다시 계산하면
		# 종이 술만 목표 위치로 튀어 손과 어긋난다.
		var hand: Vector2 = _body.get_hand() if _body.has_method(&"get_hand") \
			else PlaceholderArt.shaman_hand(RADIUS, bob, _facing, reach, _pose)
		_cloth.set_grip(_body.transform * hand)


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_health_changed.emit(current, maximum)
	# 피격 플래시: 붉게 물들었다가 흰색으로 복귀
	modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)


## 죽으면 알리기만 한다. 결과 화면 표시와 재시작은 RunResult 가 맡는다
## (즉시 리로드하면 무엇 때문에 죽었는지 볼 새도 없이 판이 넘어간다).
func _on_died() -> void:
	EventBus.player_died.emit()


## 작두는 벨 때마다 다른 궤적을 쓴다 — 베기 → 되돌려 베기 → 찌르기.
## 같은 동작만 반복하면 아무리 잘 그려도 기계처럼 보인다.
## 연타 번호는 무기가 센다 — 팔의 포즈와 칼의 궤적이 같은 값을 봐야 어긋나지 않는다.
func _on_jakdu_swung(direction: Vector2, step: int) -> void:
	var chain := PlaceholderArt.SLASH_CHAIN
	_slash_step = clampi(step, 0, chain.size() - 1)
	_on_weapon_swung(direction, chain[_slash_step])


## 무기가 나갔다. 몸도 같이 나가고, 그 바람에 무복이 휩쓸린다.
## pose 는 무엇을 들었는지 — 베기와 던지기는 손이 다르게 가야 무기가 구분된다.
func _on_weapon_swung(direction: Vector2, pose: StringName) -> void:
	_pose = pose
	_swing_time = 0.0
	_swing_total = SWING_WINDUP + SWING_STRIKE + SWING_RECOVER
	# 겨눈 쪽을 즉시 본다 — 걷는 방향과 베는 방향이 다를 때 몸이 엉뚱한 데를 보면 어색하다.
	if not direction.is_zero_approx():
		_facing = direction.angle()
	if _cloth != null:
		_cloth.impulse(direction, SWING_CLOTH_POWER)


## 휘두름 진행도를 -1~1 로. 음수는 뒤로 감는 예비, 양수는 내지르는 타격이다.
func _swing_reach() -> float:
	if _swing_total <= 0.0:
		return 0.0
	if _swing_time < SWING_WINDUP:
		# 예비는 **감속하며** 들어간다. 등속으로 감으면 태엽 감는 기계처럼 보인다.
		var wind := _swing_time / SWING_WINDUP
		return lerpf(0.0, SWING_BACK, 1.0 - (1.0 - wind) * (1.0 - wind))
	var struck := _swing_time - SWING_WINDUP
	if struck < SWING_STRIKE:
		# 내지르는 구간은 짧고 급해야 한다. 여기가 완만하면 타격이 아니라 뻗기가 된다.
		# 가속(t²)으로 나가야 **뒤로 감았다가 터지는** 대비가 생긴다.
		var hit := struck / SWING_STRIKE
		return lerpf(SWING_BACK, SWING_FORWARD, hit * hit)
	var back := (struck - SWING_STRIKE) / SWING_RECOVER
	# 복귀는 천천히 — ease-out 이라야 힘을 쓰고 난 뒤처럼 보인다.
	return lerpf(SWING_FORWARD, 0.0, back * back)


func _on_price_total_changed(_total: int, _humanity: int) -> void:
	_apply_mask()


func _on_taegi_state_changed(active: bool) -> void:
	_taegi = active
	if _cloth != null:
		_cloth.set_gangrim(active)
		# 신이 내리는 순간 자락이 위로 솟구친다.
		if active:
			_cloth.impulse(Vector2.UP, 2.2)
