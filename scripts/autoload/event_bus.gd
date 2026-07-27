extends Node

## 게임플레이 이벤트 버스. 노드 간 직접 참조 대신 이 시그널들로 디커플링한다.
## emit 하는 쪽은 상태를 소유한 노드, 구독하는 쪽은 관심 있는 시스템/UI.
## M0 스텁 — 시그널 목록은 각 시스템 구현(M1 이후) 시 추가/조정한다.

# 이벤트 버스의 시그널은 모두 다른 스크립트에서 emit 한다.
# 선언 클래스 안에서는 안 쓰이므로 unused_signal 경고를 이 블록에서만 끈다.
@warning_ignore_start("unused_signal")
signal enemy_died(enemy: Node2D, world_position: Vector2)
## 타격이 들어간 순간. 소리·데미지 숫자·히트스톱이 전부 이걸 구독한다 —
## 무기마다 연출을 직접 호출하면 무기를 더할 때마다 빠뜨린다.
signal damage_dealt(world_position: Vector2, amount: float, is_crit: bool)
signal xp_collected(amount: int)
signal wonhon_collected(amount: int)
signal player_leveled_up(new_level: int)
signal momju_chosen(god: GodData)
## 신을 실제로 모신 순간. player_leveled_up 은 "고르기 전"에 오므로 능력치·합 판정은 이걸 봐야 한다.
signal god_served(god: GodData)
signal synergy_formed(synergy: SynergyData)
## 작두타기처럼 잠시 켜졌다 꺼지는 상태. UI·연출이 구독한다.
signal taegi_state_changed(active: bool)
signal player_health_changed(current_hp: float, max_hp: float)
signal player_died
signal gate_cleared(gate_id: StringName)
@warning_ignore_restore("unused_signal")
