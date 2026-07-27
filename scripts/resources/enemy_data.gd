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

## 오행(木火土金水). DamageCalc 가 공격자 기운과 대조해 상성 배율을 낸다(design.md 3-3).
## 빈 값이면 무속성으로 쳐서 배율 1.0. 적의 오행은 기본적으로 관문 오행을 따른다(design.md 4절).
@export var element: StringName

@export_group("등급과 스킬 (design.md 6-4)")
## 잡귀에게 스킬을 주면 화면이 안 읽힌다. 스킬은 elite 이상만 가진다.
@export_enum("minion", "elite", "miniboss", "boss") var rank: String = "minion"
## EnemySkills 가 해석하는 키 목록. tether / lunge / split / summon
@export var skills: Array[StringName] = []
@export var skill_cooldown: float = 4.0
## 엘리트는 눈에 띄어야 한다 — 같아 보이는데 특수 능력이 있으면 불공정하게 느껴진다.
## 크기·테두리 중 최소 둘로 구분한다(design.md 0-2 읽히는 설계).
@export var elite_scale: float = 1.0
@export var outline_color: Color = Color(0, 0, 0, 0)

@export var texture: Texture2D
@export var radius: float = 8.0

## 도형 플레이스홀더 색(design.md 9절). 종류가 눈에 구분돼야 위협을 가늠할 수 있다.
## 아트 패스에서 texture 로 대체된다.
@export var placeholder_color: Color = Color(0.85, 0.16, 0.16)

## 플레이스홀더 실루엣 종류. 색만으로는 난전 중에 종류가 안 읽혀 형태로도 가른다.
## PlaceholderArt 가 해석한다. texture 가 있으면 무시된다.
@export_enum("wraith", "rusher", "hulk") var silhouette: String = "wraith"

## 이동 방향으로 몸을 돌릴지. 화살촉처럼 방향이 있는 실루엣만 켠다.
@export var faces_movement: bool = false
