extends Node2D

## 저승 톤 배경 위에 옅은 격자를 그린다. 카메라가 플레이어를 따라가므로
## 격자가 스크롤되어 이동이 눈에 보인다. 임시 플레이스홀더 — 아트 패스 때 교체.

const SPACING: float = 64.0
const EXTENT: float = 3000.0
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.05)


func _draw() -> void:
	var x := -EXTENT
	while x <= EXTENT:
		draw_line(Vector2(x, -EXTENT), Vector2(x, EXTENT), LINE_COLOR)
		x += SPACING
	var y := -EXTENT
	while y <= EXTENT:
		draw_line(Vector2(-EXTENT, y), Vector2(EXTENT, y), LINE_COLOR)
		y += SPACING
