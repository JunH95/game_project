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
var radius: float = 12.0
## 정식 아트가 들어오면 여기에 물리고, 도형 실루엣은 자동으로 비켜난다(design.md 9-3).
var texture: Texture2D


func _draw() -> void:
	if PlaceholderArt.draw_texture_centered(self, texture, radius * 3.0):
		return
	PlaceholderArt.draw_shaman_body(self, radius, bob, taegi, facing, swing, pose)
