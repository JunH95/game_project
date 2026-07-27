extends Node2D

## 저승 바닥. 타일 텍스처를 무한히 깔고, 그 위에 넋 불빛을 띄운다.
## 관문마다 바닥이 바뀌므로(design.md 5절) 텍스처는 데이터로 받는다.
##
## TileMapLayer 를 쓰지 않는 이유: 뱀서라이크의 바닥은 균일하게 무한히 이어지기만 하면 된다.
## 칸마다 다른 타일을 놓을 일이 없으므로 셀을 채우고 지우는 관리 비용만 생긴다.
## `draw_texture_rect(..., tile=true)` 한 번이면 같은 결과가 나온다.
##
## 텍스처가 없으면 격자로 폴백한다 — 아트가 아직 임포트되지 않았을 때도 판이 읽혀야 한다.

## 카메라가 따라오므로 화면을 덮을 만큼만 그린다. 넓게 그려도 보이지 않고 비용만 든다.
const EXTENT: float = 1600.0

## 폴백 격자(텍스처가 없을 때).
const GRID_SPACING: float = 96.0
const GRID_COLOR: Color = Color(0.42, 0.45, 0.62, 0.055)
## 굵은 선을 몇 칸마다 넣는다. 균일한 격자만 있으면 얼마나 움직였는지 읽히지 않는다.
const MAJOR_EVERY: int = 4
const MAJOR_COLOR: Color = Color(0.48, 0.44, 0.68, 0.10)

## 떠다니는 넋 불빛. 저승의 공기를 만든다. 바닥이 무엇이든 항상 띄운다.
const WISP_COUNT: int = 46
const WISP_COLOR: Color = Color(0.62, 0.72, 0.95)

## 임포트되어 있으면 자동으로 쓰는 기본 바닥. 씬에서 직접 참조하지 않는 이유:
## .png 는 Godot 이 한 번 열려야 임포트되므로, 씬이 참조하면 그 전까지 씬 로드가 깨진다.
const DEFAULT_GROUND: String = "res://assets/sprites/tiles/ground_stone.png"

## 관문별 바닥. GateData.background 를 여기에 넣는다. 비면 DEFAULT_GROUND 를 찾는다.
@export var ground_texture: Texture2D
## 타일 한 장이 월드에서 차지하는 크기(px). 작을수록 무늬가 촘촘해진다.
@export var tile_world_size: float = 240.0
## 반복이 눈에 띄지 않게 같은 바닥을 다른 배율로 한 겹 더 덮는다. 0 이면 끈다.
## 두 겹의 반복 주기가 어긋나야 격자로 읽히지 않으므로 정수배가 아닌 값을 쓴다.
@export var detail_scale: float = 2.63
@export_range(0.0, 1.0) var detail_alpha: float = 0.22
## 바닥을 얼마나 눌러 깔지. 바닥이 밝으면 액터가 묻혀 난전에서 적을 놓친다.
@export var ground_tint: Color = Color(0.72, 0.72, 0.82, 1.0)

var _wisp_pos: PackedVector2Array = PackedVector2Array()
var _wisp_phase: PackedFloat32Array = PackedFloat32Array()
var _wisp_radius: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0
var _camera: Camera2D


func _ready() -> void:
	# z_index 를 낮춰 액터보다 항상 뒤에 깔린다.
	z_index = -100
	# tile=true 로 그리려면 캔버스 아이템이 반복 샘플링을 허용해야 한다. 기본값은 꺼져 있다.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_resolve_ground()

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260722
	for i in WISP_COUNT:
		_wisp_pos.append(Vector2(
			rng.randf_range(-EXTENT, EXTENT), rng.randf_range(-EXTENT, EXTENT)))
		_wisp_phase.append(rng.randf() * TAU)
		_wisp_radius.append(rng.randf_range(1.4, 3.4))


## 관문이 지정하지 않았으면 기본 바닥을 찾는다. 아직 임포트되지 않았으면 조용히 격자로 남는다
## (exists 로 막지 않으면 임포트 전에 load 가 에러를 뱉는다).
func _resolve_ground() -> void:
	if ground_texture != null:
		return
	if not ResourceLoader.exists(DEFAULT_GROUND):
		return
	var loaded := load(DEFAULT_GROUND)
	if loaded is Texture2D:
		ground_texture = loaded
	else:
		push_warning("기본 바닥을 Texture2D 로 읽지 못했다: %s" % DEFAULT_GROUND)


## 관문 전환 때 호출한다. 바닥만 갈아 끼우고 넋 불빛은 그대로 둔다.
func set_ground(texture: Texture2D) -> void:
	ground_texture = texture
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	# 카메라를 따라다녀야 바닥이 무한히 이어지는 것처럼 보인다.
	var camera := _resolve_camera()
	if camera != null:
		var focus := camera.get_screen_center_position()
		# 타일 간격 단위로 스냅해야 무늬가 미끄러지지 않고 제자리에 있는 것처럼 보인다.
		var snap := tile_world_size if ground_texture != null else GRID_SPACING
		global_position = (focus / snap).floor() * snap
	queue_redraw()


func _resolve_camera() -> Camera2D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	var player := get_tree().get_first_node_in_group(&"player")
	_camera = player.get_node_or_null(^"Camera2D") as Camera2D if player != null else null
	return _camera


func _draw() -> void:
	if ground_texture != null:
		_draw_ground()
	else:
		_draw_grid()
	_draw_wisps()


## 타일을 무한히 깐다. 반복 주기가 다른 두 겹을 겹쳐 같은 무늬가 되풀이되는 것을 흐린다.
func _draw_ground() -> void:
	_draw_tiled(tile_world_size, ground_tint)
	if detail_alpha > 0.0 and detail_scale > 0.0:
		var tint := Color(ground_tint.r, ground_tint.g, ground_tint.b, detail_alpha)
		_draw_tiled(tile_world_size * detail_scale, tint)


## world_size 는 타일 한 장이 월드에서 차지할 크기. 그리기 변환으로 배율을 주므로
## 텍스처 해상도가 바뀌어도 화면상 크기는 그대로다.
func _draw_tiled(world_size: float, tint: Color) -> void:
	var texture_size := ground_texture.get_size().x
	if texture_size <= 0.0 or world_size <= 0.0:
		return
	var draw_scale := world_size / texture_size
	# 덮을 범위를 타일 정수 개수로 맞춘다. 반 장이 걸치면 반복 위상이 어긋나 이음새가 드러난다.
	var tiles := int(ceil(EXTENT / world_size)) + 1
	var half := float(tiles) * texture_size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(draw_scale, draw_scale))
	draw_texture_rect(ground_texture, Rect2(-half, -half, half * 2.0, half * 2.0), true, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 아트가 아직 없을 때의 폴백. 아무것도 없는 검은 화면에서는 이동감도 공간감도 없다.
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
