# 저승·바리데기 — 아키텍처 다이어그램

이 문서는 **M1~M4 목표 아키텍처**를 그린 설계도다. 코드가 커져도 구조(디커플링·컴포지션)가
흐트러지지 않게 큰 그림만 잡는다. 세부 수치·스키마는 `design.md`가 정본이다.

현재(M0) 상태: autoload 4종은 스텁으로만 존재하고, 아래 시스템·컴포넌트·UI·액터 씬은 아직 없다.
구현하면서 이 그림을 갱신한다. 과설계를 피하려고 딱 4개만 둔다.

---

## 1. 게임 플로우 상태도
타이틀에서 시작해 신당(허브)과 관문 런을 오가는 최상위 흐름. 씬 전환은 `SceneRouter`(M2+)가,
런 내부 상태(생존/레벨업 일시정지)는 `RunManager`가 소유한다.

```mermaid
stateDiagram-v2
    [*] --> Prologue: 첫 플레이(세이브 없음)
    [*] --> Title: 이후
    Prologue --> Title: 내림굿 — 작도대신이 실린다
    Title --> Shrine: 시작
    Shrine --> MomjuSelect: 관문 진입
    Shrine --> [*]: 종료
    MomjuSelect --> GateRun: 몸주 확정(시작 무기 결정)
    GateRun --> LevelUp: XP 참, 일시정지
    LevelUp --> GateRun: 신 3택1 선택
    GateRun --> Payout: 사망
    GateRun --> GateClear: 타이머/보스 클리어
    GateClear --> GateRun: 다음 관문
    GateClear --> Ending: 최종 관문
    Payout --> Shrine: 원혼 정산
    Ending --> Shrine
```

- **Prologue** = 첫 플레이 전용. 무병 → 허주풀이 → 내림굿으로 첫 몸주(작도대신)를 받는다.
  몸주는 고르는 것이 아니라 내려온다는 고증을 도입부에 쓰고, 이후부터 선택제로 넘어간다(design.md 3-1-2).
- **MomjuSelect** = 해금된 몸주 중 선택. 몸주가 시작 무기를 정하므로 런의 성격이 여기서 갈린다.

---

## 2. 시스템·이벤트 흐름도
노드끼리 직접 참조하지 않고 **EventBus 시그널**로만 통신한다(디커플링). 화살표 라벨이 시그널 이름이다.
누가 emit 하고 누가 구독하는지가 이 그림의 핵심 계약이다.

```mermaid
graph LR
    subgraph AL["Autoload 싱글톤 (상시)"]
        EB["EventBus (시그널 허브)"]
        GS["GameState (메타 상태)"]
        RM["RunManager (런 상태)"]
        SM["SaveManager (JSON 세이브)"]
    end
    subgraph SYS["런 시스템 (M1+)"]
        SD["SpawnDirector"]
        WS["WeaponSystem"]
        LS["LevelSystem"]
    end
    subgraph ACT["액터"]
        PL["Player"]
        EN["Enemy"]
        PU["Pickup (XP/원혼)"]
    end
    subgraph UIG["UI"]
        HUD["HUD"]
        GSEL["GodSelect (3택1)"]
    end

    EN -->|enemy_died| EB
    PL -->|player_health_changed| EB
    PL -->|player_died| EB
    PU -->|xp_collected| EB
    PU -->|wonhon_collected| EB
    LS -->|player_leveled_up| EB

    EB -->|xp_collected| LS
    EB -->|enemy_died| SD
    EB -->|enemy_died| RM
    EB -->|player_leveled_up| RM
    EB -->|player_leveled_up| GSEL
    EB -->|player_leveled_up| HUD
    EB -->|player_health_changed| HUD
    EB -->|wonhon_collected| GS
    EB -->|player_died| RM

    GSEL -->|선택한 신 적용| RM
    RM -->|무기·스탯 갱신| WS
    RM -->|세이브 요청| SM
    SM -.->|로드 복원| GS
```

---

## 3. 엔티티 컴포지션도
상속이 아니라 **컴포넌트 조합**으로 만든다. `HealthComponent`/`HurtboxComponent`는 플레이어·적·보스가
공유한다. 적은 단일 `enemy.tscn`이 `EnemyData` 리소스를 읽어 스탯·외형을 구성한다(data-driven).

```mermaid
graph TD
    subgraph PLS["player.tscn"]
        P["CharacterBody2D · player.gd"]
        P --> PH["HealthComponent"]
        P --> PHB["HurtboxComponent · Area2D"]
        P --> PM["MovementComponent"]
        P --> PMag["PickupMagnet · Area2D"]
        P --> PW["WeaponSystem (작두/부적)"]
        P --> PSpr["Sprite2D · 도형"]
        P --> PCol["CollisionShape2D"]
    end
    subgraph ENS["enemy.tscn · EnemyData 구동"]
        E["CharacterBody2D · enemy.gd"]
        E --> EH["HealthComponent"]
        E --> EHB["HurtboxComponent · Area2D"]
        E --> EHit["HitboxComponent · 접촉 데미지"]
        E --> ESpr["Sprite2D · 도형"]
        E --> ECol["CollisionShape2D"]
    end
```

재사용 컴포넌트(`HealthComponent`, `HurtboxComponent`, `HitboxComponent`)는 `scripts/components/`에 두고
player/enemy/boss가 각자 조립한다. 투사체·적·XP 젬은 오브젝트 풀에서 꺼내 쓴다(design.md 15절).

---

## 4. 코어 루프 시퀀스
한 판 안에서 "처치 → XP → 레벨업 → 신 3택1 → 재개"가 런타임에 어떻게 오가는지. 실제 시그널은 모두
EventBus를 거치지만(2번 그림), 여기선 논리 흐름만 단순화해 보인다.

```mermaid
sequenceDiagram
    participant WS as WeaponSystem
    participant EN as Enemy
    participant PU as XP젬
    participant LS as LevelSystem
    participant RM as RunManager
    participant UI as GodSelectUI

    WS->>EN: 작두/부적 데미지
    EN->>EN: HP 0, enemy_died
    EN->>PU: XP젬 드롭
    PU->>LS: xp_collected (수집)
    LS->>LS: XP 누적
    alt XP >= 다음 레벨
        LS->>RM: player_leveled_up
        RM->>RM: 게임 일시정지
        RM->>UI: 신 3택1 표시
        UI->>RM: 선택한 신 적용
        RM->>WS: 무기·스탯 갱신
        RM->>RM: 재개
    else 아직
        LS->>LS: 다음 젬 대기
    end
```

---

## 갱신 규칙
- 시스템·시그널·씬 구조가 바뀌면 이 문서의 해당 다이어그램을 **같은 커밋에서** 갱신한다.
- 수치·스키마는 여기 말고 `design.md`에 쓴다(중복 금지). 이 문서는 "관계·흐름"만 담는다.
