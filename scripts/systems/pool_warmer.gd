extends Node

## 관문 시작 전에 풀을 미리 채운다. 첫 스폰·첫 발사에서 instantiate 가 몰리면
## 노트북에서 눈에 띄는 끊김이 생긴다(design.md 15절의 프리워밍 초안 수치).
##
## ObjectPool 은 autoload 라 씬을 다시 열어도 살아남는다. 이미 채워져 있으면
## prewarm 이 그만큼 더 만들어 버리므로 런당 한 번만 돌도록 막는다.

@export var enemy_scene: PackedScene
@export var enemy_count: int = 300
@export var xp_gem_scene: PackedScene
@export var xp_gem_count: int = 500
@export var projectile_scene: PackedScene
@export var projectile_count: int = 200

static var _warmed: bool = false


func _ready() -> void:
	if _warmed:
		return
	_warmed = true
	if enemy_scene != null:
		ObjectPool.prewarm(enemy_scene, enemy_count)
	if xp_gem_scene != null:
		ObjectPool.prewarm(xp_gem_scene, xp_gem_count)
	if projectile_scene != null:
		ObjectPool.prewarm(projectile_scene, projectile_count)
