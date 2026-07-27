class_name SynergyData
extends Resource

## 신 조합 "합" 1종의 데이터. data/synergies/*.tres 로 인스턴스화한다(design.md 3-5).
## 두 신을 동시에 모시면 열리는, 이름 붙은 특별 효과다.
## 모든 조합에 넣으면 조합 폭발이 오므로 손으로 엄선한 페어만 둔다.

@export var id: StringName
@export var display_name: String

## 이 둘을 동시에 모시면 발동한다. 순서는 무관하다.
@export var god_a: StringName
@export var god_b: StringName

## 효과 훅 키. 이 값을 보고 각 시스템이 자기 몫을 켠다(예: &"jakdu_taegi").
@export var effect: StringName

@export_multiline var description: String
