class_name GateData
extends Resource

## 관문(스테이지) 1개의 데이터. data/gates/*.tres 로 인스턴스화한다.
## 공용 gate 씬이 이 리소스를 읽어 스폰 스케줄/보스/배경을 구성한다.

@export var id: StringName
@export var display_name: String
@export var duration_sec: float = 300.0

@export var wave_table: WaveTable
@export var mid_boss: EnemyData
@export var gate_boss: EnemyData

@export var background: Texture2D
@export var clear_color: Color = Color("0a0a12")
