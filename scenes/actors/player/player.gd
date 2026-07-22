extends CharacterBody2D

## 플레이어. M1: 8방향 이동 + 접촉 피격(HP·i-frame) + 사망 시 씬 리셋.
## 픽업 자석·작두 무기는 이후 조각에서 붙인다. 플레이스홀더 외형 = 흰 원(_draw).

const RADIUS: float = 12.0

@onready var _movement: MovementComponent = %MovementComponent
@onready var _health: HealthComponent = %HealthComponent
@onready var _hurtbox: HurtboxComponent = %HurtboxComponent


func _ready() -> void:
	_hurtbox.health = _health
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_movement.move(direction)


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_health_changed.emit(current, maximum)
	# 피격 플래시: 붉게 물들었다가 흰색으로 복귀
	modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)


func _on_died() -> void:
	EventBus.player_died.emit()
	get_tree().reload_current_scene()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
