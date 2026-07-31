class_name JointSpring
extends RefCounted

## 관절 하나의 스프링. 목표를 **덜 감쇠된** 상태로 좇아 살짝 지나쳤다가 되돌아온다.
##
## 왜 필요한가: 회전을 목표값에 그냥 대입하면 프레임마다 정확히 그 각도가 되고,
## 그래서 **딱딱하다**. 사람의 팔은 목표를 지나쳤다가 돌아오고(오버슛), 몸통이 먼저 돌고
## 팔이 늦게 따라온다(래그). 이 둘이 자연스러움의 거의 전부다.
## 2D 판에서 손을 `lerp` 로 늦게 좇게 한 것이 효과가 컸던 것도 같은 이유다 —
## 여기서는 그걸 감쇠 진동으로 바꿔 **되돌아오는 맛**까지 준다.
##
## 임계 감쇠는 `damping = 2*sqrt(stiffness)` 다. 그보다 낮게 주면 오버슛이 생긴다.

var value: Vector3
var velocity: Vector3

## 프레임이 튈 때 폭발하지 않게 한 번에 적분할 시간을 자른다.
const MAX_STEP: float = 1.0 / 30.0


func _init(initial: Vector3 = Vector3.ZERO) -> void:
	value = initial


## 아직 한 번도 안 돈 상태면 목표에 바로 앉힌다. 시작하자마자 팔이 휘두르는 것을 막는다.
func snap(target: Vector3) -> void:
	value = target
	velocity = Vector3.ZERO


func step(target: Vector3, stiffness: float, damping: float, delta: float) -> Vector3:
	var remaining := delta
	while remaining > 0.0:
		var dt := minf(remaining, MAX_STEP)
		remaining -= dt
		var accel := (target - value) * stiffness - velocity * damping
		velocity += accel * dt
		value += velocity * dt
	return value
