extends Node

## 게임플레이 이벤트 버스. 노드 간 직접 참조 대신 이 시그널들로 디커플링한다.
## emit 하는 쪽은 상태를 소유한 노드, 구독하는 쪽은 관심 있는 시스템/UI.
## M0 스텁 — 시그널 목록은 각 시스템 구현(M1 이후) 시 추가/조정한다.

# 이벤트 버스의 시그널은 모두 다른 스크립트에서 emit 한다.
# 선언 클래스 안에서는 안 쓰이므로 unused_signal 경고를 이 블록에서만 끈다.
@warning_ignore_start("unused_signal")
signal enemy_died(enemy: Node2D, world_position: Vector2)
signal xp_collected(amount: int)
signal wonhon_collected(amount: int)
signal player_leveled_up(new_level: int)
signal momju_chosen(god: GodData)
signal player_health_changed(current_hp: float, max_hp: float)
signal player_died
signal gate_cleared(gate_id: StringName)
@warning_ignore_restore("unused_signal")
