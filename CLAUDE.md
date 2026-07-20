# 저승·바리데기 (working title)

## 프로젝트 한 줄
한국 무속·저승 테마의 완결형 뱀서라이크(Vampire Survivors-like). 솔로 개발, Steam 출시.
레벨업 시 능력이 아니라 "모실 신"을 고르는 신내림(god system)이 핵심 차별점.

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
- `docs/` : `design.md`(구현 기준 문서)
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

## 설계 문서
- 구현 기준(수치·리소스 스키마·현재 스코프)의 source of truth = `docs/design.md`
- 시스템 아키텍처·이벤트 흐름·씬 컴포지션 다이어그램(Mermaid) = `docs/architecture.md`
- 서사·설정·무드보드·비전은 Notion "저승·바리데기" 페이지
- 충돌 시: 수치·동작은 `design.md` 우선, 스토리·테마는 Notion 우선
- 수치나 동작을 바꾸면 코드와 같은 커밋에서 `design.md`를 갱신한다

## Git
- 기능 단위 브랜치, 커밋은 작게
- `.tres`/`.tscn`/`.import`는 커밋, `.godot/`·`/android/`는 무시(`.gitignore`)
- 요청 없이 커밋/푸시하지 않는다

## 현재 마일스톤
- **M0 (완료 목표): 초석** — CLAUDE.md, 폴더 구조, `design.md`, 인풋맵, 충돌 레이어, git, `main.tscn` 부트스트랩 + autoload 스텁. 게임플레이 코드 없음.
- **M1 (다음): 코어 루프 수직 슬라이스** — 8방향 이동 + 작두 자동공격 + 적 스폰/처치 + XP/레벨업 + 신 3택1 + 5분 생존. 도형 플레이스홀더 아트.
- 전체 로드맵과 마일스톤 정의는 `docs/design.md` 참조.
