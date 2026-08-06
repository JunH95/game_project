extends CanvasLayer

## 개발용 디버그 메뉴(F1). **처음부터 다시 플레이하지 않고 원하는 상태로 건너뛰는 도구**다.
##
## 왜 필요한가: 5분짜리 관문을 끝까지 돌아야 확인되는 것들이 있다 — 후반 난이도, 합이 열린 뒤의
## 화면, 대가를 여러 번 치른 얼굴, 만렙 근처의 밸런스. 그걸 매번 처음부터 플레이해서 보면
## **하루에 확인할 수 있는 가짓수가 열 손가락을 못 넘는다.** 상태로 직접 뛰어야 한다.
##
## `[중요]` 릴리즈 빌드에서는 통째로 비활성이다(`OS.is_debug_build()`).
## 치트가 출시본에 남는 사고는 대개 "끄는 것을 잊어서"가 아니라 "끌 수 있게 안 만들어서" 난다.
##
## 이 노드는 게임 상태를 **바깥에서** 건드린다. 그래서 시스템 쪽에 디버그용 함수를 만들지 않는다 —
## 그러면 디버그 코드가 게임 코드 안으로 스며든다.

const TIME_SCALES: PackedFloat32Array = [1.0, 2.0, 4.0, 8.0]

@export var god_system_path: NodePath
@export var gate_timer_path: NodePath
@export var spawn_director_path: NodePath
@export var price_system_path: NodePath
@export var synergy_system_path: NodePath

var _god_system: Node
var _gate_timer: Node
var _spawn_director: Node
var _price_system: Node
var _synergy_system: Node
var _panel: PanelContainer
var _status: Label
var _time_scale_index: int = 0
var _invincible: bool = false


func _ready() -> void:
	# 릴리즈 빌드에서는 존재 자체를 지운다. 입력도 UI 도 남기지 않는다.
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_god_system = get_node_or_null(god_system_path)
	_gate_timer = get_node_or_null(gate_timer_path)
	_spawn_director = get_node_or_null(spawn_director_path)
	_price_system = get_node_or_null(price_system_path)
	_synergy_system = get_node_or_null(synergy_system_path)
	_build_ui()
	_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"debug_menu"):
		return
	_panel.visible = not _panel.visible
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _panel != null and _panel.visible:
		_status.text = _describe_state()


# --- UI 조립 ---

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-330.0, 8.0)
	_panel.custom_minimum_size = Vector2(320, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.55, 0.75)
	style.set_content_margin_all(8.0)
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_panel.add_child(column)

	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 12)
	_status.add_theme_color_override(&"font_color", Color(0.72, 0.80, 0.92))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	column.add_child(HSeparator.new())

	_add_row(column, "배속", [
		["1x", _set_time_scale.bind(0)], ["2x", _set_time_scale.bind(1)],
		["4x", _set_time_scale.bind(2)], ["8x", _set_time_scale.bind(3)],
	])
	_add_row(column, "레벨", [
		["+1", _grant_levels.bind(1)], ["+5", _grant_levels.bind(5)],
	])
	_add_row(column, "시간", [
		["+30초", _skip_time.bind(30.0)], ["+60초", _skip_time.bind(60.0)],
		["막판", _skip_to_end],
	])
	_add_row(column, "적", [
		["+10", _spawn_enemies.bind(10)], ["+40", _spawn_enemies.bind(40)],
		["전멸", _kill_all],
	])
	_add_row(column, "생존", [
		["무적", _toggle_invincible], ["회복", _heal],
	])
	_add_row(column, "대가", [
		["수명", _pay.bind(&"lifespan")], ["살", _pay.bind(&"flesh")],
		["넋", _pay.bind(&"soul")], ["인간성", _pay.bind(&"humanity")],
		["기억", _pay.bind(&"memory")],
	])

	column.add_child(HSeparator.new())
	var gods_label := Label.new()
	gods_label.text = "신 즉시 모심 (합 확인용)"
	gods_label.add_theme_font_size_override(&"font_size", 11)
	gods_label.add_theme_color_override(&"font_color", Color(0.6, 0.66, 0.78))
	column.add_child(gods_label)
	column.add_child(_build_god_buttons())


func _add_row(parent: VBoxContainer, label: String, entries: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 3)
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(46, 0)
	name_label.add_theme_font_size_override(&"font_size", 12)
	row.add_child(name_label)
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[0]
		button.add_theme_font_size_override(&"font_size", 12)
		button.pressed.connect(entry[1] as Callable)
		row.add_child(button)
	parent.add_child(row)


## 신 버튼은 로스터가 늘면 같이 늘어난다. 여기 목록을 손으로 관리하면 신을 추가할 때마다
## 디버그 메뉴를 고쳐야 하고, 그러면 결국 안 고쳐서 새 신만 테스트가 안 된다.
func _build_god_buttons() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 3)
	grid.add_theme_constant_override(&"v_separation", 3)
	if _god_system == null:
		return grid
	for god: GodData in _god_system.available_gods:
		if god == null:
			continue
		var button := Button.new()
		button.text = god.display_name
		button.add_theme_font_size_override(&"font_size", 11)
		button.pressed.connect(_serve.bind(god))
		grid.add_child(button)
	return grid


# --- 기능 ---

## 배속. 5분 관문을 8배로 돌리면 40초다 — 후반 난이도를 하루에 열 번 볼 수 있게 된다.
## Engine.time_scale 을 직접 만지지 않는다 — 히트스톱이 매 타격마다 되돌려 놓아서
## 적을 한 대 때리는 순간 배속이 풀린다. 평상시 배속의 주인은 GameFeel 이다.
func _set_time_scale(index: int) -> void:
	_time_scale_index = clampi(index, 0, TIME_SCALES.size() - 1)
	GameFeel.set_base_time_scale(TIME_SCALES[_time_scale_index])


## 레벨업을 직접 일으킨다. XP 를 넣는 게 아니라 신호를 쏘는 이유는
## 레벨 곡선과 무관하게 **신내림 화면 그 자체**를 보려는 것이기 때문이다.
func _grant_levels(count: int) -> void:
	for i in count:
		RunManager.level += 1
		EventBus.player_leveled_up.emit(RunManager.level)


## 관문 시계를 앞으로 감는다. 스폰 램프·적 스케일링이 전부 경과 시간을 보므로
## 이 한 줄로 "후반부 상태"가 만들어진다.
func _skip_time(seconds: float) -> void:
	RunManager.elapsed_sec = minf(RunManager.gate_duration_sec - 1.0,
		RunManager.elapsed_sec + seconds)


func _skip_to_end() -> void:
	RunManager.elapsed_sec = maxf(0.0, RunManager.gate_duration_sec - 20.0)


func _spawn_enemies(count: int) -> void:
	if _spawn_director == null:
		push_error("디버그: SpawnDirector 가 없어 적을 부를 수 없다.")
		return
	for i in count:
		# 스포너의 내부 배치 규칙(화면 밖 링)을 그대로 쓴다. 여기서 좌표를 새로 정하면
		# 디버그로 부른 적만 다른 데서 나와 테스트가 실제와 달라진다.
		_spawn_director.call(&"_spawn_at", TAU * float(i) / float(count))


func _kill_all() -> void:
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var health := (node as Node).get_node_or_null(^"%HealthComponent") as HealthComponent
		if health != null:
			health.take_damage(health.max_hp * 10.0)


func _toggle_invincible() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var hurtbox := player.get_node_or_null(^"%HurtboxComponent") as HurtboxComponent
	if hurtbox == null:
		return
	_invincible = not _invincible
	# 판정을 끄는 대신 무적 시간을 사실상 무한으로 둔다 — 피격 경로 자체는 살아 있어야
	# "맞았는데 아무 일도 안 일어나는" 버그와 구분이 된다.
	hurtbox.invuln_time = 9999.0 if _invincible else 0.5


func _heal() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var health := player.get_node_or_null(^"%HealthComponent") as HealthComponent
	if health != null:
		health.hp = health.max_hp
		health.health_changed.emit(health.hp, health.max_hp)


## 대가를 직접 청구한다. 신을 모셔야만 대가가 붙으므로, 대가의 **누적 효과**(얼굴이 흐려지는
## 정도, 타이머 색)를 보려면 신 로스터에 의존하지 않고 따로 부를 수 있어야 한다.
func _pay(kind: StringName) -> void:
	if _price_system == null:
		push_error("디버그: PriceSystem 이 없다.")
		return
	var god := GodData.new()
	god.id = &"_debug_price"
	god.display_name = "디버그"
	god.price_kind = kind
	_price_system.call(&"_on_god_served", god)


func _serve(god: GodData) -> void:
	if _god_system != null:
		_god_system.serve(god)


func _describe_state() -> String:
	var lines: PackedStringArray = []
	lines.append("배속 %.0fx    Lv %d    처치 %d%s" % [
		GameFeel.base_time_scale, RunManager.level, RunManager.kills,
		"    [무적]" if _invincible else ""])
	lines.append("관문 %.0f / %.0f초    적 %d" % [
		RunManager.elapsed_sec, RunManager.gate_duration_sec,
		get_tree().get_nodes_in_group(&"enemy").size()])
	if _god_system != null:
		var served: Dictionary = _god_system.get_served()
		var parts: PackedStringArray = []
		for god_id: StringName in served:
			parts.append("%s·%d" % [god_id, int(served[god_id])])
		lines.append("신: " + (" ".join(parts) if not parts.is_empty() else "없음"))
	if _price_system != null:
		lines.append("대가 %d회 (인간성 %d)" % [
			_price_system.call(&"get_paid_total"),
			_price_system.call(&"get_humanity_paid")])
	return "\n".join(lines)
