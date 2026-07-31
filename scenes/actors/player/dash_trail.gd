extends Node2D

## 무보(대시)의 잔상. 플레이어가 지나온 자리에 넋빛 실루엣을 남기고, 출발 지점에는
## 터져 나가는 고리를 남긴다.
##
## `top_level = true` 로 두어 플레이어 transform 을 물려받지 않는다. 잔상은 **지나온 자리**에
## 남아야 하는데, 부모를 따라가면 몸에 붙어 같이 끌려가 잔상이 아니라 그냥 두꺼운 몸이 된다.
##
## 그리기 전용이라 판정과 무관하다(9-1-1 의 그림/판정 분리 규칙).

## 잔상 한 장이 사라지기까지. 대시 자체(0.14s)보다 길어야 멈춘 뒤에도 궤적이 읽힌다.
const GHOST_LIFE: float = 0.26
## 몇 프레임마다 한 장 남길지. 매 프레임 남기면 겹쳐서 한 덩어리가 되고 궤적이 안 보인다.
const GHOST_INTERVAL: int = 2
const GHOST_MAX: int = 8
## 출발 고리가 퍼지는 시간.
const BURST_LIFE: float = 0.22

var _ghosts: Array[Dictionary] = []
var _burst_left: float = 0.0
var _burst_at: Vector2 = Vector2.ZERO
var _burst_dir: Vector2 = Vector2.RIGHT
var _tick: int = 0


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	rotation = 0.0


## 대시가 시작됐다. 출발 자리에 고리를 찍는다 — 어디서 튀어나갔는지가 남아야
## "빨랐다"가 아니라 "여기서 저기로 갔다"로 읽힌다.
func burst(world_position: Vector2, direction: Vector2) -> void:
	_burst_at = world_position
	_burst_dir = direction
	_burst_left = BURST_LIFE
	_tick = 0


## 대시 중 매 물리 프레임 호출. body 는 그림 노드라 기울기·스쿼시가 이미 실려 있다.
func record(world_position: Vector2, body: Node2D, radius: float) -> void:
	_tick += 1
	if _tick % GHOST_INTERVAL != 0:
		return
	if _ghosts.size() >= GHOST_MAX:
		_ghosts.remove_at(0)
	_ghosts.append({
		"at": world_position + body.position,
		"rot": body.rotation,
		"scale": body.scale,
		"r": radius,
		"life": GHOST_LIFE,
	})


func _process(delta: float) -> void:
	if _ghosts.is_empty() and _burst_left <= 0.0:
		return
	if _burst_left > 0.0:
		_burst_left -= delta
	var i := _ghosts.size() - 1
	while i >= 0:
		_ghosts[i]["life"] -= delta
		if _ghosts[i]["life"] <= 0.0:
			_ghosts.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	if _burst_left > 0.0:
		_draw_burst()
	for ghost in _ghosts:
		var t: float = clampf(ghost["life"] / GHOST_LIFE, 0.0, 1.0)
		# 오래된 잔상일수록 옅고 조금 작다. 같은 크기로 늘어놓으면 어느 쪽이 과거인지 모른다.
		var fade := t * t * 0.5
		draw_set_transform(ghost["at"], ghost["rot"], ghost["scale"] * (0.82 + 0.18 * t))
		PlaceholderArt.draw_shaman_ghost(self, ghost["r"],
			Color(PlaceholderArt.NEOK.r, PlaceholderArt.NEOK.g, PlaceholderArt.NEOK.b, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 출발 자리의 고리와 뒤로 뻗는 기운 선. 고리만 있으면 어느 쪽으로 갔는지가 빠진다.
func _draw_burst() -> void:
	var t := _burst_left / BURST_LIFE
	var grow := 1.0 - t
	var tint := PlaceholderArt.NEOK
	# 진행 방향으로 눌린 타원처럼 보이도록 고리를 그린 뒤 뒤쪽으로 선을 뻗는다.
	draw_arc(_burst_at, 6.0 + grow * 34.0, 0.0, TAU, 24,
		Color(tint.r, tint.g, tint.b, t * 0.55), 2.0)
	var back := -_burst_dir
	var side := _burst_dir.orthogonal()
	for offset: float in [-1.0, 0.0, 1.0]:
		var root: Vector2 = _burst_at + side * (offset * 7.0)
		draw_line(root, root + back * (10.0 + grow * 30.0),
			Color(tint.r, tint.g, tint.b, t * 0.4), 2.0)
