# 저승·바리데기 (working title)

## 프로젝트 한 줄
한국 무속·저승 테마의 완결형 뱀서라이크(Vampire Survivors-like). 솔로 개발, Steam 출시.
**대가를 치르고 신을 모신다** — 모실수록 강해지지만 인간에서 멀어지고,
무엇을 내주었느냐가 결말을 가른다. 오행이 전투 속성이자 서사 루트(design.md 3-7·5-0).
관문은 4~5개를 반복해서 돌고 결말이 6개다. 고증은 재료지 규칙이 아니다(vision.md 1-B).

## 기술 스택
- Godot 4.7 · GDScript · 2D (top-down)
- 대상: Windows (Steam)
- 도구: VS Code + Claude Code + Godot MCP(`godot-ai`)

## 폴더 구조
- `data/` : 신·무기·적·웨이브·관문 데이터(`.tres`). 튜닝 수치의 실체.
- `scenes/` : `actors/`(player/enemies/projectiles/pickups), `ui/`, `stages/`, `main.tscn`
- `scripts/` :
  - `resources/` : 커스텀 Resource 클래스(`class_name` + `@export`)
  - `autoload/` : 싱글톤(GameState/RunManager/EventBus/SaveManager 등)
  - `components/` : 재사용 노드(health/hurtbox/hitbox/movement/xp) — M1에서 채움
  - `systems/` : 스폰/무기/레벨 등 시스템 — M1에서 채움
- `assets/` : 원본 아트·오디오. `placeholder/`는 임시 도형 리소스.
- `docs/` : `vision.md`(비전·서사·톤) · `design.md`(수치·스키마·스코프) · `lore.md`(고증) · `architecture.md`(구조) · `art_prompts.md`(아트 생성 프롬프트) · `기획서.html`(사람용 종합 뷰)
- `tests/` : 테스트
- 씬 전용 스크립트는 해당 `.tscn` 옆에, 공용 로직은 `scripts/` 아래에 둔다.
- `addons/godot_ai/`와 autoload `_mcp_game_helper`는 MCP 플러그인이다. 건드리지 않는다.

## GDScript 컨벤션
- 파일/폴더/함수/변수: `snake_case` · 클래스(`class_name`)/노드: `PascalCase` · 상수: `ALL_CAPS`
- private 의도 멤버: `_` 접두사
- 타입 명시 필수: `var hp: int = 100`, `func take_damage(amount: int) -> void`
- 시그널: 과거형(`health_changed`, `died`), 상태를 소유한 노드가 emit
- 노드 참조: `@onready` + 유니크 노드(`%Name`). 문자열 경로 하드코딩 최소화
- 튜닝 수치는 코드가 아니라 Resource(`.tres`)로. 신/무기/적/관문은 커스텀 Resource 클래스 기반(data-driven)
- 상속보다 컴포지션·씬 조합. 재사용 로직은 component 노드로
- 다수 개체(투사체/적/데미지 숫자)는 오브젝트 풀링 사용 (매 프레임 instantiate 금지)
- 전역 상태·이벤트는 autoload 싱글톤으로. 노드 간 직접 참조 대신 `EventBus` 시그널로 디커플링

## 주석·품질 규칙 (전역 규칙 상속)
- 주석은 한국어, 자명하지 않은 로직에만, WHAT이 아니라 WHY
- 이모지 금지 · 주석 처리된 코드 블록 금지 · `print`/디버그 출력 커밋 금지
- 에러는 명시적으로 처리. 빈 catch/무시 금지. 실패 시 로그 남기고 안전한 기본값으로 폴백
- 요청 스코프 밖 코드 변경 금지 · 요청 없이 변수/함수 이름 변경 금지

## Godot MCP 사용
- 씬/노드 생성·수정, 스크립트 작성, 실행·로그 확인은 `godot-ai` MCP 툴 사용
- 씬 트리 변경 후 `scene_save` · 동작 확인은 `project_run` + `logs_read(source="game")`
- 화면 확인은 `editor_screenshot(source="viewport_2d")` 또는 `source="game"`(실행 중)
- 파일시스템에 직접 쓴 `class_name` 스크립트는 `filesystem_manage(op="scan")`로 전역 클래스 테이블 갱신
- 다중 에디터면 `session_activate`로 세션 고정

## 문서 아키텍처 (정본 = repo)
**정본은 전부 repo 마크다운이다. Notion은 은퇴했다(더 이상 읽지도 쓰지도 않는다).** 문서 지도:
- `docs/vision.md` — 비전·서사·톤·무드·재미 방향·떡밥·아트 방향 (WHY / 무엇을 느끼게)
- `docs/design.md` — 수치·리소스 스키마·스코프·마일스톤 (구현 정본, 코드가 따름)
- `docs/lore.md` — 무속·저승 고증(고증/각색/미확인 구분)
- `docs/architecture.md` — 시스템·이벤트 흐름·씬 컴포지션 다이어그램(Mermaid)
- `docs/art_prompts.md` — AI 이미지 생성 프롬프트·출력 규격·적용 절차 (아트 정본. 스타일 앵커는 함부로 고치지 않는다)
- `docs/ideas.md` — 브레인스토밍 아이디어의 판정 대장(채택/보류/축소/기각). 정본이 아니다. **기각 이유를 남겨 같은 아이디어가 다시 올라오는 것을 막는 곳**
- `docs/기획서.html` — 위 문서들을 합친 **사람용 종합 뷰**(파생물, 정본 아님)

규칙:
- 충돌 시: 수치·동작은 `design.md`, 서사·톤은 `vision.md`가 우선.
- **변경은 repo 마크다운에 먼저**, 코드와 같은 커밋에서 해당 문서를 갱신한다. 그 변경이 사람용 뷰에 영향 주면 같은 작업에서 `기획서.html`도 갱신한다(단방향 흐름 = 드리프트 차단). `기획서.html`을 손으로 먼저 고치지 않는다.
- **톤 유지**: 새 서사·카피·UI 문구를 쓸 땐 `vision.md`의 톤(§4)을 따른다 — 어둡고 신령하되 무겁지만은 않게, 현대 각색 우선.

## Git
- 기능 단위 브랜치, 커밋은 작게
- `.tres`/`.tscn`/`.import`는 커밋, `.godot/`·`/android/`는 무시(`.gitignore`)
- 요청 없이 커밋/푸시하지 않는다

## 현재 마일스톤
- **M0 (완료): 초석** — CLAUDE.md, 폴더 구조, `design.md`, 인풋맵, 충돌 레이어, git, `main.tscn` 부트스트랩 + autoload 스텁.
- **M1 (완료): 코어 루프 수직 슬라이스** — 8방향 이동 + 작두 자동공격 + 적 스폰/추격/처치 + XP 젬·레벨업 + 신 3택1 + 5분 관문·결과 화면. 도형 플레이스홀더 아트.
- **M2 (완료): 무기 확장 + 풀링** — `ObjectPool`·부적(유도)·언월도(궤도)·적 3종·정식 HUD·일시정지.
- **M3 (진행 중): 신내림 정식** — 완료: 몸주 선택, 몸주 3 ↔ 무기 3, 데미지 공식·치명·오행, 합 프레임 + 합 3종(장군 강림·궤도 작두·북두 방벽). 남은 것: 신 로스터 확장, 칠야(밤 상태 정의 필요).
- **아트 방향 전환**: 묘사 대신 **어둠 + 발광 + 절차적 천**. 무복은 verlet(`ClothBody`)으로 돌고, 몸주별 외형은 `GodData` 값이다. 강림은 능동 기술(`gangrim` 입력). 근거와 시연은 아트 디렉션 문서 참조.
- **M4 (성장·수집)**: 원혼·노잣돈 두 재화, 나루터, 무구 8종, 신단 트리, 도감 5종. 전부 출시 포함.
- **스코프 원칙**: 확장으로 미루지 않는다. 시간 압박이 없으므로 갖춰서 낸다(design.md §8).
- 전체 로드맵과 마일스톤 정의는 `docs/design.md` 참조.
