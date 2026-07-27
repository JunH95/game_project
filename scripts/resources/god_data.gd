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

@export_group("몸주 (런 시작 시 고르는 주신)")
## 몸주로 고를 수 있는 신인지. false 면 레벨업으로만 모신다.
@export var is_momju: bool = false
## 몸주로 골랐을 때 쥐고 시작하는 무기 id. 몸주 3종이 서로 다른 무기를 준다(design.md 3-1-1).
@export var momju_weapon: StringName
## 몸주로 골랐을 때만 한 번 붙는 스탯 수정자(레벨과 무관). stat_mods 와 키 체계는 같다.
## 수치형 패시브를 문자열 훅으로 처리하면 키마다 코드 분기가 생겨 데이터로 둔다.
@export var momju_stat_mods: Dictionary
## 몸주로 골랐을 때만 붙는 특수 훅 키(작두타기 게이지처럼 수치로 표현 못 하는 것).
@export var momju_passive: StringName

## 시그니처 메커닉 훅 키. 없으면 빈 값 (손님신/바리공주 같은 특수 신만 사용)
@export var special: StringName

@export var icon: Texture2D
@export_multiline var description: String
