class_name GodData
extends Resource

## 신내림으로 모실 수 있는 신 1종의 데이터. data/gods/*.tres 로 인스턴스화한다.

@export var id: StringName
@export var display_name: String
@export var tier: int = 1
@export var max_level: int = 5

## 레벨별 스탯 수정자. 예: { "jakdu_damage": 3, "jakdu_arc": 20 } (레벨당 가산치)
@export var stat_mods: Dictionary

## 이 신이 부여하는 무기 id. 없으면 빈 값 (순수 스탯 신)
@export var grants_weapon: StringName

## 시그니처 메커닉 훅 키. 없으면 빈 값 (손님신/바리공주 같은 특수 신만 사용)
@export var special: StringName

@export var icon: Texture2D
@export_multiline var description: String
