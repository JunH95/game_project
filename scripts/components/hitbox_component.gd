class_name HitboxComponent
extends Area2D

## 데미지를 싣고 다니는 영역. HurtboxComponent 가 이걸 감지해 데미지를 받아간다.
## 충돌 레이어는 이 노드를 붙이는 액터 씬에서 설정한다(예: enemy_hitbox / player_hitbox).

@export var damage: float = 8.0
@export var knockback: float = 0.0
