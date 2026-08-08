extends Node

## 밸런스 시뮬레이터 — 런을 헤드리스로 여러 번 돌려 **수치로** 밸런스를 본다(design.md 16-2).
##
## 실행:
##   godot --headless --path . res://tests/balance_sim.tscn -- \
##       --runs=10 --seconds=180 --momju=all --speed=8 --seed=1 --out=user://balance.json
##
## 왜 필요한가: 뱀서라이크의 밸런스는 결국 수치다. 사람이 플레이해서 "부적이 좀 센 것 같다"를
## 답으로 쓰면, 실제로 얼마나 센지 모른 채 고치게 된다 — 전에 부적을 과하게 버프해서
## 다른 무기의 1.5배가 된 적이 있고, 그건 플레이가 아니라 표를 봐야 잡히는 종류의 사고다.
##
## `[중요]` 봇은 사람이 아니다. **절대 수치가 아니라 조건 간 차이를 보는 도구**다 —
## "몸주 A 가 B 보다 오래 버틴다"는 믿을 수 있지만 "3분 42초를 버틴다"는 못 믿는다.
##
## 봇은 게임 코드를 건드리지 않는다. `Input.action_press` 로 **실제 입력 액션**을 눌러
## 플레이어가 사람이 조작할 때와 같은 경로를 타게 한다.

const MAIN_SCENE: String = "res://scenes/main.tscn"
## 이 거리 안에 적이 있을 때만 도망친다. 처음에 150 으로 잡았더니 **봇이 계속 도망만 다녀서
## 젬을 하나도 못 줍고 180초 동안 Lv 1 에 머물렀다** — 사람은 적을 끌고 다니며 줍는다.
## 무기 사거리(작두 90)보다 짧아야 도망 중에도 적이 사거리에 들어온다.
const FLEE_RADIUS: float = 74.0
## 이보다 가까우면 무보(회피)를 쓴다.
const PANIC_RADIUS: float = 42.0
## 젬을 주우러 가는 거리.
const PICKUP_RADIUS: float = 260.0
## 한 런의 실시간 상한(초). 배속을 걸어도 안 끝나면 무언가 잘못된 것이라 끊는다.
const REAL_TIME_LIMIT: float = 120.0

var _runs: int = 5
var _seconds: float = 180.0
var _momju_filter: String = "all"
var _speed: float = 8.0
var _seed: int = 1
var _out_path: String = ""

var _momju_ids: Array[StringName] = []
var _queue: Array = []
var _results: Array[Dictionary] = []

var _main: Node
var _current: Dictionary = {}
var _run_started_at: int = 0
var _rng := RandomNumberGenerator.new()
var _finished: bool = false
## 이번 런에서 무기별로 넣은 총 데미지. `damage_dealt` 의 source 가 출처를 알려 준다.
var _damage_by_source: Dictionary = {}
var _crits: int = 0
var _hits: int = 0
var _damage_taken: float = 0.0
var _last_hp: float = -1.0
## 선택 화면에서 못 빠져나온 프레임 수. 멈춘 채로 매달려 있으면 원인을 찍고 끊는다 —
## 헤드리스에서 조용히 걸려 있으면 타임아웃까지 아무것도 안 나온다.
var _stuck_frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	_rng.seed = _seed
	seed(_seed)
	# 배속을 올리면 한 프레임에 물리 스텝이 몰린다. 상한을 열어 두지 않으면
	# 엔진이 스텝을 버려서 **시뮬레이션 시간이 실제보다 느리게 흐른다**.
	Engine.max_physics_steps_per_frame = 128
	Engine.max_fps = 0
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.player_health_changed.connect(_on_health_changed)
	_resolve_momju_ids()
	_build_queue()
	_start_next()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs = maxi(1, arg.trim_prefix("--runs=").to_int())
		elif arg.begins_with("--seconds="):
			_seconds = maxf(10.0, arg.trim_prefix("--seconds=").to_float())
		elif arg.begins_with("--momju="):
			_momju_filter = arg.trim_prefix("--momju=")
		elif arg.begins_with("--speed="):
			_speed = clampf(arg.trim_prefix("--speed=").to_float(), 1.0, 20.0)
		elif arg.begins_with("--seed="):
			_seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")


## 몸주 목록은 데이터에서 읽는다. 여기 하드코딩하면 몸주를 추가할 때마다 시뮬이 뒤처진다.
func _resolve_momju_ids() -> void:
	var probe := Node.new()
	probe.set_script(load("res://scripts/systems/god_system.gd"))
	add_child(probe)
	for god: GodData in probe.get_momju_candidates():
		_momju_ids.append(god.id)
	probe.queue_free()
	if _momju_ids.is_empty():
		push_error("밸런스 시뮬: 몸주 후보가 없다.")
		_report_and_quit()


func _build_queue() -> void:
	var targets: Array[StringName] = []
	if _momju_filter == "all":
		targets = _momju_ids
	else:
		var wanted := StringName(_momju_filter)
		if not _momju_ids.has(wanted):
			push_error("밸런스 시뮬: 모르는 몸주다 — %s" % _momju_filter)
			_report_and_quit()
			return
		targets = [wanted]
	for momju_id: StringName in targets:
		for i in _runs:
			_queue.append({"momju": momju_id, "index": i})


func _start_next() -> void:
	if _queue.is_empty():
		_report_and_quit()
		return
	var job: Dictionary = _queue.pop_front()
	_current = {
		"momju": job["momju"],
		"index": job["index"],
		"picked": [] as Array[StringName],
	}
	_damage_by_source = {}
	_crits = 0
	_hits = 0
	_damage_taken = 0.0
	_last_hp = -1.0
	_run_started_at = Time.get_ticks_msec()

	var scene := load(MAIN_SCENE) as PackedScene
	_main = scene.instantiate()
	add_child(_main)
	# 관문 길이를 시뮬 길이에 맞춘다. 5분을 다 돌리면 한 조건에 수십 초가 든다.
	var gate := _main.get_node_or_null(^"%GateTimer")
	if gate != null:
		gate.duration_sec = _seconds
	_strip_visuals()
	# 배속은 **씬을 띄운 뒤에** 건다. FxSpawner 가 _ready 에서 GameFeel.reset() 을 부르므로
	# 먼저 걸어 두면 매 런마다 1x 로 초기화된다(실제로 그래서 12x 가 1.0x 로 나왔다).
	# Engine.time_scale 을 직접 넣지 않는 이유는 따로 있다 — 히트스톱이 타격마다 되돌린다.
	GameFeel.set_base_time_scale(_speed)
	_stuck_frames = 0


## 그림만 담당하는 노드를 끈다. 판정은 전부 다른 데 있으므로(9-1-1 의 그림/판정 분리)
## 시뮬 결과는 바뀌지 않는데, **속도는 배로 빨라진다** — 스프링 관절·verlet 천·3D 뷰포트는
## 헤드리스에서도 매 프레임 계산이 돈다. 이 분리를 지켜 둔 값을 여기서 돌려받는 셈이다.
func _strip_visuals() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null:
		for child_name: String in ["Body3D", "Body", "ClothBody", "DashTrail"]:
			var node := player.get_node_or_null(NodePath(child_name)) as Node
			if node != null:
				node.process_mode = Node.PROCESS_MODE_DISABLED
				if node is CanvasItem:
					(node as CanvasItem).visible = false
	# 데미지 숫자·처치 이펙트는 초당 수십 개가 뜬다. 계측은 시그널에서 직접 받으므로 필요 없다.
	for node_name: String in ["FxSpawner", "Hud", "Background"]:
		var node := _main.get_node_or_null(NodePath(node_name)) as Node
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is CanvasItem:
				(node as CanvasItem).visible = false


func _process(_delta: float) -> void:
	if _finished or _main == null:
		return
	# 런 종료를 **먼저** 본다. 결과 화면도 트리를 멈추므로, 일시정지 분기를 앞에 두면
	# 죽은 뒤에 영영 선택 화면을 찾다가 매달린다. 예전에는 몸주 버튼을 무조건 눌러 대는
	# 버그가 우연히 일시정지를 풀어 줘서 이 문제가 가려져 있었다.
	if _is_run_over() or _real_elapsed() > REAL_TIME_LIMIT:
		_finish_run()
		return
	# 몸주·신 선택 화면은 트리를 멈춘다. 봇이 대신 고른다.
	if get_tree().paused:
		_stuck_frames += 1
		if _stuck_frames > 900:
			_report_stuck()
			return
		_auto_choose()
		return
	_stuck_frames = 0
	_drive_bot()


## 선택 화면을 못 넘겼다. 무엇이 떠 있고 버튼이 몇 개인지까지 찍어야 다음에 안 헤맨다.
func _report_stuck() -> void:
	var lines: PackedStringArray = []
	for dialog_name in ["MomjuSelect", "GodSelect", "RunResult"]:
		var dialog := _main.find_child(dialog_name, true, false)
		if dialog == null:
			lines.append("%s: 없음" % dialog_name)
			continue
		var choices := dialog.find_child("Choices", true, false)
		# 가시성까지 찍는다. "버튼은 있는데 안 눌린다"의 원인은 대개 창이 안 떠 있는 것이라,
		# 버튼 수만 찍으면 같은 자리에서 두 번 헤맨다.
		lines.append("%s: 열림=%s 버튼=%s" % [dialog_name, str(_is_panel_open(dialog)),
			str(choices.get_child_count()) if choices != null else "없음"])
	push_error("밸런스 시뮬: 선택 화면에서 멈췄다 — " + " / ".join(lines))
	_report_and_quit()


func _real_elapsed() -> float:
	return float(Time.get_ticks_msec() - _run_started_at) / 1000.0


# --- 봇 ---

## 위협에서 멀어지고 젬 쪽으로 간다. 정교할 필요는 없다 — **모든 조건에 같은 봇**을 쓰는 것이
## 중요하지, 봇이 잘하는 것이 중요한 게 아니다. 잘하는 봇은 오히려 차이를 지운다.
func _drive_bot() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var here := player.global_position

	var away := Vector2.ZERO
	var nearest_sq := INF
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := here - enemy.global_position
		var dist_sq := offset.length_squared()
		if dist_sq < 0.01:
			continue
		nearest_sq = minf(nearest_sq, dist_sq)
		if dist_sq > FLEE_RADIUS * FLEE_RADIUS:
			continue
		# 가까울수록 세게 민다. 거리 제곱에 반비례시키면 붙은 적이 판단을 지배한다.
		away += offset / dist_sq * 8000.0

	var toward := Vector2.ZERO
	var best_sq := PICKUP_RADIUS * PICKUP_RADIUS
	for node in get_tree().get_nodes_in_group(&"pickup"):
		var gem := node as Node2D
		if gem == null or not is_instance_valid(gem):
			continue
		var dist_sq := here.distance_squared_to(gem.global_position)
		if dist_sq < best_sq:
			best_sq = dist_sq
			toward = (gem.global_position - here).normalized()

	# 붙었을 때만 도망치고, 그 외에는 줍는다. 도망을 항상 우선하면 봇이 맵 끝으로 달아나
	# 전투도 수집도 안 하는 판이 되어 **무엇을 재는지 알 수 없는 수치**가 나온다.
	var move := away.limit_length(1.0) * 2.2 + toward
	_press_move(move.normalized() if move.length() > 0.15 else Vector2.ZERO)
	# 코앞까지 붙으면 무보로 뺀다. 쿨다운은 플레이어가 알아서 무시한다.
	_press(&"dash", nearest_sq < PANIC_RADIUS * PANIC_RADIUS)


func _press_move(direction: Vector2) -> void:
	_press(&"move_right", direction.x > 0.25)
	_press(&"move_left", direction.x < -0.25)
	_press(&"move_down", direction.y > 0.25)
	_press(&"move_up", direction.y < -0.25)


func _press(action: StringName, down: bool) -> void:
	if down:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right", &"dash"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# --- 선택 화면 자동 처리 ---

## `[중요]` **떠 있는 창만 누른다.** 몸주 선택은 고르고 나면 패널만 숨고 노드와 버튼은 그대로
## 남는다 — 가시성을 안 보고 누르면 이후 모든 레벨업에서 **몸주 버튼을 다시 눌러**
## `set_momju` 가 반복 호출된다. 그러면 신내림 카드는 한 번도 안 눌리고 몸주만 계속 쌓여,
## 시뮬이 "몸주 단일 스택"을 재면서 겉으로는 멀쩡한 표를 뱉는다(실제로 그랬다).
func _auto_choose() -> void:
	var momju := _main.find_child("MomjuSelect", true, false)
	if momju != null and _is_panel_open(momju) and _press_momju(momju):
		return
	var select := _main.find_child("GodSelect", true, false)
	if select != null and _is_panel_open(select):
		_press_random_choice(select)


func _is_panel_open(dialog: Node) -> bool:
	var panel := dialog.find_child("Panel", true, false) as Control
	return panel != null and panel.visible


## 지정한 몸주를 고른다. 버튼 순서는 `get_momju_candidates()` 순서와 같다.
func _press_momju(dialog: Node) -> bool:
	var choices := dialog.find_child("Choices", true, false)
	if choices == null or choices.get_child_count() == 0:
		return false
	var god_system := _main.get_node_or_null(^"%GodSystem")
	if god_system == null:
		return false
	var candidates: Array = god_system.get_momju_candidates()
	for i in candidates.size():
		if (candidates[i] as GodData).id != _current["momju"]:
			continue
		if i >= choices.get_child_count():
			return false
		(choices.get_child(i) as Button).pressed.emit()
		return true
	return false


## 신은 무작위로 고른다. 특정 빌드를 재는 게 아니라 **몸주별 평균**을 보는 것이라
## 사람이 고를 법한 편향을 넣으면 오히려 조건이 오염된다. 시드가 있어 재현은 된다.
func _press_random_choice(dialog: Node) -> void:
	var choices := dialog.find_child("Choices", true, false)
	if choices == null or choices.get_child_count() == 0:
		return
	var pick := _rng.randi_range(0, choices.get_child_count() - 1)
	(choices.get_child(pick) as Button).pressed.emit()


func _is_run_over() -> bool:
	var result := _main.find_child("RunResult", true, false)
	if result == null:
		return false
	var panel := result.find_child("Panel", true, false) as Control
	return panel != null and panel.visible


# --- 계측 ---

func _on_damage_dealt(_position: Vector2, amount: float, is_crit: bool,
		source: StringName) -> void:
	_damage_by_source[source] = float(_damage_by_source.get(source, 0.0)) + amount
	_hits += 1
	if is_crit:
		_crits += 1


func _on_health_changed(current: float, _maximum: float) -> void:
	if _last_hp >= 0.0 and current < _last_hp:
		_damage_taken += _last_hp - current
	_last_hp = current


func _finish_run() -> void:
	var survived: float = RunManager.elapsed_sec
	var total := 0.0
	for value: float in _damage_by_source.values():
		total += value
	_current["survived"] = survived
	_current["cleared"] = survived >= _seconds - 0.5
	_current["kills"] = RunManager.kills
	_current["level"] = RunManager.level
	_current["damage"] = total
	_current["dps"] = total / maxf(1.0, survived)
	_current["damage_by_source"] = _damage_by_source.duplicate()
	_current["crit_rate"] = float(_crits) / maxf(1.0, float(_hits))
	_current["damage_taken"] = _damage_taken
	_current["gods"] = _describe_served()
	_current["humanity"] = RunManager.humanity_paid
	_results.append(_current)

	# 실제 배속을 같이 찍는다. 요청한 speed 가 안 나오는데 모르고 있으면
	# "왜 이렇게 오래 걸리지"를 매번 다시 조사하게 된다.
	var real := _real_elapsed()
	_current["real_sec"] = real
	print("  [%d/%d] %s — %.0f초 · 처치 %d · Lv %d · DPS %.1f%s   (실시간 %.1fs, %.1fx)" % [
		_results.size(), _results.size() + _queue.size(), _current["momju"],
		survived, _current["kills"], _current["level"], _current["dps"],
		"  (클리어)" if _current["cleared"] else "", real, survived / maxf(0.01, real)])

	_release_all()
	get_tree().paused = false
	_main.queue_free()
	_main = null
	# 씬이 실제로 사라진 뒤에 다음 런을 띄운다. 겹치면 그룹에 두 판의 적이 함께 잡힌다.
	await get_tree().process_frame
	await get_tree().process_frame
	_start_next()


# --- 집계 ---

func _report_and_quit() -> void:
	if _finished:
		return
	_finished = true
	GameFeel.set_base_time_scale(1.0)
	if _results.is_empty():
		push_error("밸런스 시뮬: 결과가 없다.")
		get_tree().quit(1)
		return

	var by_momju: Dictionary = {}
	for row: Dictionary in _results:
		var key: StringName = row["momju"]
		if not by_momju.has(key):
			by_momju[key] = []
		(by_momju[key] as Array).append(row)

	print("\n=== 밸런스 시뮬 — 런 %d회 · 관문 %.0f초 · seed %d ===" % [
		_results.size(), _seconds, _seed])
	print("%-12s %8s %8s %8s %8s %8s %8s" % [
		"몸주", "생존", "클리어", "처치", "레벨", "DPS", "받은뎀"])
	for key: StringName in by_momju:
		var rows: Array = by_momju[key]
		print("%-12s %8.1f %7.0f%% %8.1f %8.1f %8.1f %8.0f" % [
			key,
			_mean(rows, "survived"), _mean(rows, "cleared") * 100.0,
			_mean(rows, "kills"), _mean(rows, "level"),
			_mean(rows, "dps"), _mean(rows, "damage_taken")])

	print("\n--- 무기별 데미지 비중 ---")
	var weapon_totals: Dictionary = {}
	var grand := 0.0
	for row: Dictionary in _results:
		for source: StringName in (row["damage_by_source"] as Dictionary):
			var value: float = row["damage_by_source"][source]
			weapon_totals[source] = float(weapon_totals.get(source, 0.0)) + value
			grand += value
	for source: StringName in weapon_totals:
		var value: float = weapon_totals[source]
		print("  %-10s %8.0f  (%.1f%%)" % [source, value, value / maxf(1.0, grand) * 100.0])

	if not _out_path.is_empty():
		_save_json()
	get_tree().quit(0)


## 무엇을 몇 레벨로 모셨는지. id 만 남기면 "신 3종"까지만 알 수 있어
## 어떤 빌드가 이겼는지 되짚을 수 없다.
func _describe_served() -> Array:
	var out: Array = []
	var god_system := _main.get_node_or_null(^"%GodSystem") if _main != null else null
	if god_system == null:
		return out
	var served: Dictionary = god_system.get_served()
	for god_id: StringName in served:
		out.append("%s:%d" % [god_id, int(served[god_id])])
	return out


func _mean(rows: Array, key: String) -> float:
	if rows.is_empty():
		return 0.0
	var total := 0.0
	for row: Dictionary in rows:
		total += float(row[key])
	return total / float(rows.size())


## 표는 읽으려고 찍고, JSON 은 **밸런스를 고치기 전후로 비교하려고** 남긴다.
func _save_json() -> void:
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file == null:
		push_error("밸런스 시뮬: 결과 파일을 쓰지 못했다 — %s (%d)" % [
			_out_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({
		"seed": _seed, "seconds": _seconds, "runs": _runs, "results": _results
	}, "  "))
	file.close()
	print("\n결과 저장 — %s" % _out_path)
