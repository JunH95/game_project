extends Node

## 메타(영속) 상태의 인메모리 보유소. SaveManager 가 이 값을 직렬화/역직렬화한다.
## M0 스텁 — 실제 필드와 로직은 M4(신당 메타 루프)에서 채운다.

var wonhon: int = 0
var unlocked_gods: Array[StringName] = []
var gear_tiers: Dictionary = {}
