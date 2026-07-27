extends CharacterBody2D

## 플레이어. M1: 8방향 이동 + 접촉 피격(HP·i-frame) + 사망 시 씬 리셋.
## 픽업 자석·작두 무기는 이후 조각에서 붙인다. 플레이스홀더 외형 = 흰 원(_draw).

const RADIUS: float = 12.0

## 신내림 수정자를 물어볼 GodSystem. main.tscn 에서 주입한다.
@export var god_system_path: NodePath
## 합 성립을 물어볼 SynergySystem. 작두타기처럼 합이 여는 기능이 이걸 본다.
@export var synergy_system_path: NodePath

var _god_system: Node
## { weapon_id: 무기 노드 } — 몸주·신이 열어 준 것만 켠다.
var _weapons: Dictionary = {}
var _taegi: bool = false
var _base_speed: float = 0.0
var _base_max_hp: float = 0.0
var _base_magnet_radius: float = 0.0

@onready var _movement: MovementComponent = %MovementComponent
@onready var _health: HealthComponent = %HealthComponent
@onready var _hurtbox: HurtboxComponent = %HurtboxComponent
@onready var _magnet: Area2D = %PickupMagnet


func _ready() -> void:
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
	var synergy_system: Node = null
	if not synergy_system_path.is_empty():
		synergy_system = get_node_or_null(synergy_system_path)
	for weapon in _weapons.values():
		if weapon != null:
			weapon.god_system = _god_system
			# 합이 여는 기능(작두타기)이 있는 무기만 이 참조를 쓴다.
			if &"synergy_system" in weapon:
				weapon.synergy_system = synergy_system
			weapon.process_mode = Node.PROCESS_MODE_DISABLED

	if _god_system != null:
		# player_leveled_up 은 신을 고르기 "전"에 오므로 그걸로 갱신하면 능력치가 한 픽씩 밀린다.
		# 몸주 확정도 내부적으로 serve() 를 거치므로 이 하나로 둘 다 덮는다.
		EventBus.god_served.connect(_on_god_served)

	# 작두타기가 발동하면 몸에 금빛이 실린다 — 지금이 그 순간임을 몸으로도 보여 준다.
	EventBus.taegi_state_changed.connect(_on_taegi_state_changed)

	# health_changed 는 피격 때만 오므로 시작 체력을 한 번 알린다.
	# 지연시키는 이유: 플레이어가 HUD 보다 먼저 _ready 를 돌아, 즉시 쏘면 구독 전에 사라진다.
	_announce_health.call_deferred()


func _announce_health() -> void:
	EventBus.player_health_changed.emit(_health.hp, _health.max_hp)


## 신을 새로 모시면(몸주 확정 포함) 능력치와 열린 무기를 다시 계산한다.
func _on_god_served(_god: GodData) -> void:
	_apply_god_mods()


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


## 자석 반경에 들어온 픽업은 플레이어를 향해 끌려온다. 수집 판정은 픽업 쪽이 한다.
func _on_magnet_area_entered(area: Area2D) -> void:
	if area.has_method(&"attract_to"):
		area.call(&"attract_to", self)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_movement.move(direction)


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


func _on_taegi_state_changed(active: bool) -> void:
	_taegi = active
	queue_redraw()


func _draw() -> void:
	# 강림 중에는 몸 둘레에 금빛 테가 돈다. 정식 이펙트는 M6 아트 패스.
	if _taegi:
		draw_circle(Vector2.ZERO, RADIUS + 6.0, Color(1.0, 0.82, 0.35, 0.35))
	draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
