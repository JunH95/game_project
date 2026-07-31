extends Node2D

## 무당의 몸 **그림만** 담는 노드.
##
## 무기(작두 부채꼴·궤도)는 플레이어 루트에 달려 있으므로, 이 노드는 아무리 돌리고
## 찌그러뜨려도 판정에 영향을 주지 않는다. 역동성이 여기서 나온다 —
## 그림과 판정을 같은 노드에 두면 몸을 기울이는 순간 부채꼴까지 같이 돌아가
## "몸을 못 돌린다"는 제약이 생긴다(그래서 이 노드를 갈라냈다).
##
## 상태는 player.gd 가 매 프레임 넣어 준다. 여기서는 그리기만 한다.

var bob: float = 0.0
var taegi: bool = false
var facing: float = 0.0
var swing: float = 0.0
var pose: StringName = PlaceholderArt.POSE_SLASH
## 탈 — 몸주가 정한다. 신이 내리면 얼굴이 바뀐다.
var mask_shape: StringName = &"jangsu"
var mask_color: Color = PlaceholderArt.HOBUN
var mask_mark_color: Color = PlaceholderArt.JUSA
var radius: float = 12.0
## 정식 아트가 들어오면 여기에 물리고, 도형 실루엣은 자동으로 비켜난다(design.md 9-3).
var texture: Texture2D

## 손은 목표 위치를 **반 박자 늦게** 좇는다. 계산값을 그대로 그리면 팔이 딱딱 끊겨 움직인다 —
## 사지가 부드러워 보이는 것은 관절이 많아서가 아니라 **따라오는 지연** 때문이다.
const HAND_FOLLOW: float = 26.0

var _hand: Vector2 = Vector2.ZERO
var _hand_ready: bool = false


func _process(delta: float) -> void:
	var target := PlaceholderArt.shaman_hand(radius, bob, facing, swing, pose)
	if not _hand_ready:
		_hand = target
		_hand_ready = true
	else:
		# 프레임률과 무관하게 같은 속도로 좇는다.
		_hand = _hand.lerp(target, 1.0 - exp(-HAND_FOLLOW * delta))
	queue_redraw()


## 천(지전)이 매달릴 실제 손 위치. 그리는 값과 같아야 종이 술이 손에서 논다.
func get_hand() -> Vector2:
	return _hand


func _draw() -> void:
	if PlaceholderArt.draw_texture_centered(self, texture, radius * 3.0):
		return
	PlaceholderArt.draw_shaman_body(self, radius, bob, taegi, facing, swing, pose,
		mask_shape, mask_color, mask_mark_color, _hand)
