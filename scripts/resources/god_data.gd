class_name GodData
extends Resource

## 신내림으로 모실 수 있는 신 1종의 데이터. data/gods/*.tres 로 인스턴스화한다.

@export var id: StringName
@export var display_name: String
@export var tier: int = 1
@export var max_level: int = 5

## 오행(木火土金水). 관문 상성 계산에 쓴다(design.md 3-3, M5).
@export var element: StringName

## 레벨당 스탯 수정자. 키는 GodSystem 이 해석한다.
## 예: { "jakdu_damage_pct": 15.0, "jakdu_arc_deg": 8.0 }
@export var stat_mods: Dictionary

## 이 신이 부여하는 무기 id. 없으면 빈 값 (순수 스탯 신)
@export var grants_weapon: StringName

## 시그니처 메커닉 훅 키. 없으면 빈 값 (손님신/바리공주 같은 특수 신만 사용)
@export var special: StringName

@export var icon: Texture2D
@export_multiline var description: String
