extends Node2D

## 떠오르는 데미지 숫자. 수백 개가 생겼다 사라지므로 풀링 대상이다.
## 얼마나 아팠는지 숫자로 보이지 않으면 신을 골라도 세졌는지 알 수가 없다.

const RISE_SPEED: float = 46.0
const LIFETIME: float = 0.7
## 치명은 크고 금색으로. 평타와 한눈에 구분돼야 한다.
const COLOR_NORMAL: Color = Color(0.95, 0.93, 0.88)
const COLOR_CRIT: Color = Color(1.0, 0.82, 0.32)
const FONT_SIZE_NORMAL: int = 15
const FONT_SIZE_CRIT: int = 22

var _text: String = ""
var _color: Color = COLOR_NORMAL
var _font_size: int = FONT_SIZE_NORMAL
var _life_left: float = 0.0
var _drift: float = 0.0
var _font: Font


func _ready() -> void:
	# 프로젝트 기본 폰트. 아트 패스에서 전용 폰트로 바꾼다.
	_font = ThemeDB.fallback_font


## 스포너가 풀에서 꺼낸 직후 호출한다.
func setup(amount: float, is_crit: bool) -> void:
	_text = str(int(round(amount)))
	_color = COLOR_CRIT if is_crit else COLOR_NORMAL
	_font_size = FONT_SIZE_CRIT if is_crit else FONT_SIZE_NORMAL
	_life_left = LIFETIME
	# 같은 자리에 여러 숫자가 겹치면 읽히지 않으므로 좌우로 흩는다.
	_drift = randf_range(-24.0, 24.0)
	queue_redraw()


func _pool_reset() -> void:
	_life_left = 0.0


func _process(delta: float) -> void:
	if _life_left <= 0.0:
		return
	_life_left -= delta
	if _life_left <= 0.0:
		ObjectPool.release(self)
		return
	var t := 1.0 - _life_left / LIFETIME
	position.y -= RISE_SPEED * delta
	position.x += _drift * delta * (1.0 - t)
	queue_redraw()


func _draw() -> void:
	if _life_left <= 0.0 or _font == null:
		return
	# 끝에서 흐려진다. 처음부터 흐리면 정작 읽어야 할 때 안 보인다.
	var alpha: float = clampf(_life_left / (LIFETIME * 0.45), 0.0, 1.0)
	var size := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size)
	var origin := Vector2(-size.x * 0.5, 0.0)
	# 어두운 배경에서도 읽히도록 외곽선 대신 그림자를 한 겹 깐다.
	_font.draw_string(get_canvas_item(), origin + Vector2(1.0, 1.5), _text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, Color(0.0, 0.0, 0.0, alpha * 0.65))
	_font.draw_string(get_canvas_item(), origin, _text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, Color(_color.r, _color.g, _color.b, alpha))
