# 저승·바리데기 — 구현 설계 (design.md)

이 문서는 **구현의 source of truth**다. 코드는 이 문서의 수치·스키마·스코프를 따른다.
서사·설정·비전은 Notion "저승·바리데기" 페이지가 정본이다. 충돌 시 수치·동작은 이 문서가,
스토리·테마는 Notion이 우선한다. 수치나 동작을 바꾸면 코드와 같은 커밋에서 이 문서를 갱신한다.

표기: `[지금]` = M0에서 확정한 기본값(고쳐도 됨, 초안). `[나중]` = 이후 마일스톤에서 결정.
모든 수치는 보수적 초안이며 플레이테스트로 튜닝한다.

---

## 0. 컨셉 요약 (구현 관점)
- 장르: 완결형 뱀서라이크. 탑다운 2D, 자동 공격, 이동만이 유일한 조작 verb.
- 테마: 한국 무속/저승. 주인공 = 무당. 무대 = 저승. 바리데기 모티프(열 관문 → 생명수 → 귀환).
- 차별점: 신내림 — 레벨업 시 능력 대신 "모실 신"을 고른다. 신 조합이 곧 빌드.
- 완성 기준(v1.0): 관문 3개 → 최종보스 → 엔딩까지 도는 최소 완결 빌드 + 신당 메타 루프.

---

## 1. MVP 코어 루프 `[지금]`
루프: 이동 → 최근접 자동공격 → 처치 → XP 젬 드롭 → 걸어서 수집 → XP 참 → 레벨업(게임 일시정지) →
신 3택1 → 재개 → 관문 타이머 생존.

| 항목 | 값 |
|---|---|
| 시점 | 탑다운 2D, 카메라 플레이어 추적, 고정 줌 |
| 이동 | 8방향, `Input.get_vector("move_left","move_right","move_up","move_down")`, 정규화 |
| 이동 속도 | 120 px/s |
| 픽업 반경 | 40 px |
| 플레이어 HP | 100, 접촉 데미지, 피격 후 i-frame 0.5s |
| 회피/구르기 | 없음 (v1) |
| 공격 | 완전 자동. 공격 버튼 없음 |
| 승패 | 관문 타이머 생존 = 클리어 / HP 0 = 사망 → 정산 |
| XP 곡선 | `xp_to_next(level) = 5 + (level - 1) * 4` → 5, 9, 13, 17 … (선형, 추후 튜닝) |

---

## 2. 무기 `[지금 형태, 수치는 튜닝]`
작두 = 기본 시작 무기(전원 보유). 부적 = 선택 또는 신(용왕·수신) 해금.

### 작두 (jakdu) — 근접, 자동 부채꼴 베기
최근접 적 방향으로 쿨다운마다 호(arc) 범위를 벤다. 궤도형 칼날이 아니라 "무당이 작두를 휘두르는" 형태.

| 파라미터 | 기본값 | 레벨 스케일 |
|---|---|---|
| damage | 10 | 레벨당 +3 |
| cooldown | 0.8 s | 3레벨마다 -0.1s |
| arc (각도) | 100° | 3레벨마다 +20° |
| range | 90 px | - |
| knockback | 120 | - |
| 판정 | 호 범위 내 모든 적 타격 | - |

### 부적 (bujeok) — 원거리, 유도 투사체
최근접 적에게 쿨다운마다 유도 부적 발사.

| 파라미터 | 기본값 | 레벨 스케일 |
|---|---|---|
| damage | 7 | 레벨당 +2 |
| cooldown | 1.2 s | - |
| projectile_speed | 320 px/s | - |
| homing_turn_rate | 4 rad/s | - |
| pierce | 1 | 2레벨마다 +1 |
| count | 1 | 고레벨에서 +1 |
| lifetime | 2.5 s | - |

---

## 3. 신내림 (god system) `[핵심, 모델 지금 / 콘텐츠 점증]`
- 레벨업 시 **3택1** 제시. 각 선택지 = (a) 새 신 or (b) 보유 신 +1레벨(VS식 스택).
- 런당 모시는 신 최대 ~6.
- 각 신 = `GodData` Resource. 대부분 순수 스탯/무기 수정자, 2~3개는 시그니처 메커닉.

### v1.0 판테온 (8신, MVP는 (MVP) 표시 3~4신)
| 신 | 효과 | 비고 |
|---|---|---|
| 산신 | 작두 damage↑, 작두 arc↑ | (MVP) |
| 용왕·수신 | 부적 부여/강화, homing↑, count↑ | (MVP) |
| 칠성신 | max HP↑, luck↑(업그레이드 확률) | (MVP) |
| 장군신 | 전체 공격속도↑(쿨 -%), 이동속도↑ | (MVP) |
| 삼신할미 | HP 재생 / 레벨업 시 회복 | |
| 조상신 | XP 획득량↑, 픽업 반경↑ | |
| 손님신 | 피격 적에 지속 데미지/저주 | 시그니처 |
| 바리공주 | 스토리 캡스톤: 1회 부활 or 광역 폭발 | 시그니처 |

- **신 조합 시너지("합")** `[나중]`: v1은 스택+스탯 중첩으로 빌드 다양성 확보. 이후 신-쌍 시너지를
  `SynergyData` Resource로 추가(예: 산신+장군신 → 작두 궤도화, 용왕+손님신 → 독 부적).

---

## 4. 적 / 스폰 / 웨이브 `[MVP 지금, 확장 나중]`
- **MVP: 추격 적 1종** — HP 10, 속도 60 px/s, 접촉 데미지 8, XP 1 드롭.
- **풀 관문(M5+): 4종** — chaser(스웜) / fast-weak(러시) / tank(고HP) / ranged(원거리 영). 각 `EnemyData` + 공용 enemy 씬.
- **스폰 디렉터**: 화면 밖 링(반경 ≈ 뷰포트 대각선/2 + 여유)에서 스폰. 시간에 따라 `WaveTable`로 스폰율 증가. 시작 1/s → 버스트로 램프. **동시 적 상한 ~150-200**(노트북 성능, 디렉터 하드캡).
- **원혼 드롭**: 드문 픽업. 처치의 5%가 원혼 1 드롭, 미니보스 10, 관문 보스 25.

---

## 5. 런 구조 `[지금]`
- **관문 = 5분 타이머 생존 스테이지.** 3:00에 저승사자 미니보스 스폰, 5:00 관문 클리어(또는 관문 보스 처치).
- **런 = 관문 시퀀스 → 최종보스 → 엔딩.**
- **v1.0은 3관문**(칼산 / 화탕 / 얼음 — 비주얼 강한 것 우선). 나머지 시왕 10지옥은 출시 후 무료 업데이트.
- **삼도천** = 런 전 허브/경계(신당 프레이밍).
- 런 종료: 사망 → 원혼 정산 → 신당 / 최종 관문 클리어 → 엔딩.

---

## 6. 보스 `[형태 지금, 무브셋 나중]`
- **저승사자** = 관문 미니보스(3:00). `EnemyData`에 `is_boss` 플래그 + 소형 행동 스크립트. 별도 씬 불필요(v1).
- **관문 보스** = 5:00 (후반 관문은 관문 자체가 보스).
- **최종보스** = 생명수를 지키는 마지막 시왕 관문 수문장. v1 전용 보스 씬 1개. 풀 무브셋 `[나중]`.
- **엔딩** = 정지 일러스트 + 한국어 내레이션(Hades식). 플레이스홀더 = 검정 배경 텍스트.

---

## 7. 신당 (메타 경제) `[구조 지금, 곡선 나중]`
- **재화: 원혼** — 런 간 영속.
- **획득** = 인런 드문 드롭 + 런 종료 정산: `floor(kills/10) + 관문클리어보너스(각 10) + 보스보너스`.
- **소비** = 신 해금(해금 전엔 런 풀에 미등장) / 장비 티어 강화(작두·부적·플레이어 영구 소폭 상승).
- **비용 곡선(초안)**: 신 해금 30 / 50 / 80 / 120 …, 장비 티어 강화 20 → 40 → 80 → 160 (×2).
- 신당은 v1에서 **단일 메뉴 씬**(탭 2개: 신 해금 / 장비 강화). 신당 건설 시뮬 아님.

---

## 8. v1.0 콘텐츠 스코프 (결승선) `[지금]`
캐릭터 1(무당) · 무기 2(작두+부적) · 신 8 · 관문 3 + 미니보스 3 + 최종보스 · 엔딩 1 ·
신당(해금/강화) · 타이틀 + 설정 + 세이브 · 클리어 후 무한/난이도 모드.
그 외 전부 = 무료 업데이트.

---

## 9. 아트/오디오 플레이스홀더 `[지금]`
프로그래머 우선. 도형 + 엄격한 색 코드. `assets/placeholder/`에 두고 리소스로 참조(코드에 하드코딩 금지) → 이후 아트 패스는 폴더 교체.

| 대상 | 플레이스홀더 |
|---|---|
| 플레이어 | 흰 원 |
| 적 | 빨강 원 |
| 보스 | 큰 짙은 빨강 원 |
| XP 젬 | 청록 다이아 |
| 원혼 | 보라 구 |
| 작두 타격 | 흰 호(arc) |
| 부적 | 노랑 삼각 |

- 오디오: `AudioManager` autoload에 명명된 SFX 키만 배선. CC0 클립(Kenney/freesound)은 나중에 코드 변경 없이 투입.
- 규칙: 게임플레이는 비주얼/오디오를 Resource에서 읽는다. 플레이스홀더가 로직에 새지 않게.

---

## 10. 세이브 / 영속 `[지금]`
- **2계층**: 메타(영속) vs 런(v1은 인메모리, 런 중간 세이브 없음).
- **메타 세이브** = 원혼 잔액, 해금된 신, 장비 티어, 설정, 해금 플래그.
- `SaveManager` autoload가 `user://save.json`에 JSON 저장(사람이 읽기 쉬움, 디버그/버전/마이그레이션 용이). `version` 필드 포함.
- **원자적 쓰기**: temp 파일 → rename (크래시 시 손상 방지).
- **명시적 에러 처리**: 읽기 실패 시 로그 남기고 기본값 폴백. 빈 catch 금지.

---

## 11. 제목 `[지금 유지, 확정 나중]`
가제 "저승·바리데기" 유지. Steam용 영문 부제는 스토어 페이지 때(예: *Barideki: Ten Gates*). `[나중]`.

---

## 12. Resource 스키마 (커스텀 Resource 클래스)
`scripts/resources/*.gd`. 모든 콘텐츠는 이 클래스 기반 `.tres` 인스턴스로 `data/`에 둔다.

- **GodData** (`god_data.gd`): `id: StringName`, `display_name: String`, `tier: int`,
  `max_level: int`, `stat_mods: Dictionary`(레벨별 스탯 수정자), `grants_weapon: StringName`,
  `special: StringName`(시그니처 훅, 없으면 빈 값), `icon: Texture2D`, `description: String`.
- **WeaponData** (`weapon_data.gd`): `id: StringName`, `display_name: String`,
  `base_damage: float`, `cooldown: float`, `range: float`, `arc_degrees: float`(근접),
  `projectile_speed: float`, `homing_turn_rate: float`, `pierce: int`, `count: int`,
  `lifetime: float`(원거리), `knockback: float`, `is_melee: bool`, `level_scale: Dictionary`.
- **EnemyData** (`enemy_data.gd`): `id: StringName`, `display_name: String`, `max_hp: float`,
  `move_speed: float`, `contact_damage: float`, `xp_reward: int`, `wonhon_chance: float`,
  `is_boss: bool`, `texture: Texture2D`, `radius: float`.
- **GateData** (`gate_data.gd`): `id: StringName`, `display_name: String`, `duration_sec: float`,
  `wave_table: WaveTable`, `mid_boss: EnemyData`, `gate_boss: EnemyData`, `background: Texture2D`,
  `clear_color: Color`.
- **WaveTable** (`wave_table.gd`): 시간축 스폰 스케줄. `entries: Array`(각 항목 = 시작 시각,
  적 `EnemyData`, 스폰율, 버스트 크기). 상세 스키마는 M2/M5에서 확정.

---

## 13. 충돌 레이어 (2D physics) `[지금]`
`project.godot`의 `layer_names/2d_physics/layer_N`. 규칙: **hurtbox가 hitbox를 detect**(hurtbox가 mask 보유, hitbox는 자기 레이어에 수동).

| # | 레이어 이름 | 켜짐(body/area) | mask(감지 대상) |
|---|---|---|---|
| 1 | world | 경계/벽 | - |
| 2 | player | 플레이어 CharacterBody2D | world |
| 3 | enemy | 적 CharacterBody2D | world, enemy(soft-separation), player |
| 4 | player_hurtbox | 플레이어 Area2D | enemy_hitbox |
| 5 | enemy_hurtbox | 적 Area2D | player_hitbox |
| 6 | player_hitbox | 작두 호 / 부적 Area2D | (enemy_hurtbox가 감지) |
| 7 | enemy_hitbox | 적 접촉 / 투사체 | (player_hurtbox가 감지) |
| 8 | pickup | XP 젬 / 원혼 Area2D | (pickup_magnet이 감지) |
| 9 | pickup_magnet | 플레이어 Area2D(반경) | pickup |

---

## 14. 프로젝트 설정 `[지금]`
- 기본 클리어 컬러 `#0a0a12` (저승 톤).
- 기본 뷰포트 1920×1080, 스트레치 `canvas_items` / `expand`(기존 유지).
- 인풋 액션: `move_up/down/left/right`(WASD + 방향키 + 게임패드 스틱/D패드), `pause`(Esc + Start). 메뉴는 내장 `ui_accept/ui_cancel/ui_*` 재사용.
- Jolt 3D 물리는 2D 게임엔 무관 — 그대로 둔다(투자 안 함).
- `[나중]`: 픽셀 스냅(픽셀아트 확정 시), `max_fps` 캡, 렌더러 Mobile 전환 검토.

---

## 15. 오브젝트 풀링 `[지금 규칙, 구현 M2]`
투사체/적/XP 젬/데미지 숫자는 풀링(VS-like는 수백 개 스폰, 매 프레임 instantiate는 노트북에서 스터터).
프리워밍 초안: 투사체 200, 적 300, XP 젬 500, 데미지 숫자 100.

---

## 16. autoload 싱글톤 `[M0 스텁 → 점증]`
- `EventBus`: 디커플링 시그널(`enemy_died`, `xp_collected`, `player_level_up` 등).
- `GameState`: 메타(영속) 상태의 인메모리 보유.
- `RunManager`: 현재 런 상태(타이머, 레벨, 모신 신, 킬 수).
- `SaveManager`: JSON I/O (§10).
- `[나중, M2+]`: `ObjectPool`, `AudioManager`, `SceneRouter`(타이틀↔신당↔관문 전환).

---

## 17. 마일스톤 로드맵
- **M0 (초석, 현재 목표)**: CLAUDE.md, 폴더, design.md, 인풋맵, 충돌 레이어, git, `main.tscn` 부트스트랩 + autoload 스텁. 게임플레이 없음.
- **M1 (코어 루프 슬라이스)**: 8방향 이동 + 작두 자동공격 + 추격 적 1종 스폰/처치 + XP 젬/레벨업 + 신 3택1(스탯+신 혼합) + 5분 생존. 도형 플레이스홀더.
- **M2 (2번째 무기 + 풀링)**: 부적 유도, `ObjectPool`, 적 2~3종, HUD, 일시정지.
- **M3 (신내림 정식)**: `GodData` 리소스, 신 4, 스택, 실제 3택1 UI.
- **M4 (신당 메타 루프)**: 원혼 재화, `SaveManager` JSON 저장/로드, 신 1 해금, 타이틀→신당→런→정산→신당 사이클.
- **M5 (풀 관문 1개)**: WaveTable 램프, 저승사자 미니보스 + 관문 보스, 관문 클리어 흐름.
- **M6 (게임 필 패스)**: 히트스톱, 스크린셰이크, 데미지 숫자, 히트 플래시, 넉백 튜닝("그럭저럭 찰진").
- **M7 (최소 완결 빌드)**: 3관문 + 최종보스 + 엔딩 + 타이틀/설정 + 신 8 → Steam-ready.
- **출시 후**: 무한/하드 모드, 캐릭터/무기/신/관문 무료 업데이트, 신 시너지(합).
