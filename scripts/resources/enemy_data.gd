class_name EnemyData
extends Resource

## 적 1종의 데이터. data/enemies/*.tres 로 인스턴스화한다.
## 공용 enemy 씬이 이 리소스를 읽어 스탯/외형을 구성한다(data-driven).

@export var id: StringName
@export var display_name: String
@export var max_hp: float = 10.0
@export var move_speed: float = 60.0
@export var contact_damage: float = 8.0
@export var xp_reward: int = 1

## 처치 시 원혼 드롭 확률 (0.0 ~ 1.0)
@export_range(0.0, 1.0) var wonhon_chance: float = 0.05

## 미니보스/보스 여부. 별도 씬 없이 이 플래그 + 소형 행동 스크립트로 처리
@export var is_boss: bool = false

@export var texture: Texture2D
@export var radius: float = 8.0

## 도형 플레이스홀더 색(design.md 9절). 종류가 눈에 구분돼야 위협을 가늠할 수 있다.
## 아트 패스에서 texture 로 대체된다.
@export var placeholder_color: Color = Color(0.85, 0.16, 0.16)
