class_name WaveTable
extends Resource

## 관문의 시간축 스폰 스케줄. data/waves/*.tres 로 인스턴스화한다.
## 상세 엔트리 스키마는 스폰 디렉터 구현(M2/M5)에서 확정한다.
## 각 엔트리 예: { "start_sec": 0.0, "enemy": EnemyData, "rate_per_sec": 1.0, "burst": 0 }

@export var entries: Array
