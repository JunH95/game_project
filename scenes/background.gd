extends Node2D

## 저승 바닥. 도형 플레이스홀더 단계지만 "어둡고 신령한" 톤(vision.md 4절)은 지금부터 잡는다.
## 아무것도 없는 검은 화면에서는 이동감도 공간감도 없어 테스트가 재미없다.
##
## 정식 아트(무신도 톤 타일·안개 셰이더)는 M6 아트 패스에서 이 노드를 대체한다.

## 카메라가 따라오므로 화면을 덮을 만큼만 그린다. 넓게 그려도 보이지 않고 비용만 든다.
const EXTENT: float = 1600.0
const GRID_SPACING: float = 96.0
const GRID_COLOR: Color = Color(0.42, 0.45, 0.62, 0.055)
## 굵은 선을 몇 칸마다 넣는다. 균일한 격자만 있으면 얼마나 움직였는지 읽히지 않는다.
const MAJOR_EVERY: int = 4
const MAJOR_COLOR: Color = Color(0.48, 0.44, 0.68, 0.10)

## 떠다니는 넋 불빛. 저승의 공기를 만든다.
const WISP_COUNT: int = 46
const WISP_COLOR: Color = Color(0.62, 0.72, 0.95)

var _wisp_pos: PackedVector2Array = PackedVector2Array()
var _wisp_phase: PackedFloat32Array = PackedFloat32Array()
var _wisp_radius: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0
var _camera: Camera2D


func _ready() -> void:
	# z_index 를 낮춰 액터보다 항상 뒤에 깔린다.
	z_index = -100
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260722
	for i in WISP_COUNT:
		_wisp_pos.append(Vector2(
			rng.randf_range(-EXTENT, EXTENT), rng.randf_range(-EXTENT, EXTENT)))
		_wisp_phase.append(rng.randf() * TAU)
		_wisp_radius.append(rng.randf_range(1.4, 3.4))


func _process(delta: float) -> void:
	_time += delta
	# 카메라를 따라다녀야 격자가 무한히 이어지는 것처럼 보인다.
	var camera := _resolve_camera()
	if camera != null:
		var focus := camera.get_screen_center_position()
		# 격자 간격 단위로 스냅해야 선이 미끄러지지 않고 제자리에 있는 것처럼 보인다.
		global_position = (focus / GRID_SPACING).floor() * GRID_SPACING
	queue_redraw()


func _resolve_camera() -> Camera2D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	var player := get_tree().get_first_node_in_group(&"player")
	_camera = player.get_node_or_null(^"Camera2D") as Camera2D if player != null else null
	return _camera


func _draw() -> void:
	_draw_grid()
	_draw_wisps()


func _draw_grid() -> void:
	var steps := int(EXTENT / GRID_SPACING)
	for i in range(-steps, steps + 1):
		var offset := float(i) * GRID_SPACING
		var color := MAJOR_COLOR if i % MAJOR_EVERY == 0 else GRID_COLOR
		var width := 2.0 if i % MAJOR_EVERY == 0 else 1.0
		draw_line(Vector2(offset, -EXTENT), Vector2(offset, EXTENT), color, width)
		draw_line(Vector2(-EXTENT, offset), Vector2(EXTENT, offset), color, width)


## 넋 불빛은 제자리에서 느리게 숨 쉰다. 흘러다니게 하면 시선을 뺏어 적을 놓친다.
func _draw_wisps() -> void:
	for i in _wisp_pos.size():
		var pulse := 0.5 + 0.5 * sin(_time * 0.7 + _wisp_phase[i])
		var radius := _wisp_radius[i] * (0.7 + 0.5 * pulse)
		var local := _wisp_pos[i] - global_position
		# 바깥쪽 옅은 무리를 먼저 깔아 번지는 느낌을 준다.
		draw_circle(local, radius * 2.6, Color(WISP_COLOR.r, WISP_COLOR.g, WISP_COLOR.b, 0.05 * pulse))
		draw_circle(local, radius, Color(WISP_COLOR.r, WISP_COLOR.g, WISP_COLOR.b, 0.30 * pulse))
