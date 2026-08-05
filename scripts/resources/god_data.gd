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

@export_subgroup("탈 (몸주일 때 쓰는 가면)")
## 탈의 형태 키. PlaceholderArt 가 해석한다 — jangsu(장수탈) / gaksi(각시탈) / yangban(양반탈).
## `[고증]` 굿에서 신을 청할 때 그 신의 탈을 쓴다. 신이 내리면 얼굴이 바뀐다는 관념이
## 그대로 캐릭터 차별화가 된다. 그리고 사람 얼굴을 그리지 않아도 되어 실루엣이 산다.
@export var mask_shape: StringName = &"jangsu"
@export var mask_color: Color = Color("F2EDE3")
## 탈에 그려진 무늬·눈매의 색. 형태만으로 부족한 구분을 여기서 낸다.
@export var mask_mark_color: Color = Color("B3352A")

@export_subgroup("무복 (몸주일 때 입는 옷)")
## 무복 색. 몸주가 바뀌면 외형이 갈리는 첫 번째 축이다.
@export var robe_color: Color = Color("F2EDE3")
@export var sash_color: Color = Color("E4543F")
## 천의 무게. 갑주 위 전포는 무겁게(1.45), 도포는 가볍게(0.70) — 같은 물리에 값만 다르다.
@export_range(0.3, 2.5) var cloth_weight: float = 1.0
## 치마 갈래 수. 많을수록 넓게 퍼진다.
@export_range(3, 12) var rib_count: int = 7
## 갈래 한 마디의 길이(px).
@export_range(4.0, 16.0) var segment_length: float = 9.0
## 옆으로 벌어지려는 힘. 0 이면 치마가 다리처럼 붙는다.
@export_range(0.0, 2.0) var cloth_spread: float = 1.0

@export_group("대가 (design.md 3-7)")
## 이 신을 모실 때 치르는 값. 빈 값이면 **순한 신**이다.
## lifespan(수명) · flesh(살) · soul(넋) · humanity(인간성) · memory(기억)
##
## 전부에 대가를 붙이면 성장이 안 되고, 없으면 선택에 무게가 안 생긴다 — **셋 중 하나꼴**로 둔다.
## `[설계 주의]` 값을 부르는 신은 같은 급 순한 신보다 확실히 세야 한다(3-7 초안 1.6~2.0배).
## 안 그러면 "대가 있는 신은 거르는 것이 최적"이 되어 시스템이 죽는다.
@export var price_kind: StringName

## 대가의 크기 배율. 종류마다 단위가 달라 여기서는 배수만 준다(수명이면 20초 × 이 값).
@export_range(0.25, 3.0) var price_scale: float = 1.0

## 시그니처 메커닉 훅 키. 없으면 빈 값 (손님신/바리공주 같은 특수 신만 사용)
@export var special: StringName

@export var icon: Texture2D
@export_multiline var description: String
