extends Node

## 효과음·BGM 재생. 게임플레이는 **키만** 알고 파일은 모른다(design.md 9절) —
## 지금 재생되는 것은 합성한 플레이스홀더이고, 나중에 진짜 에셋으로 갈아 끼울 때 코드는 안 바뀐다.
##
## 같은 프레임에 같은 소리가 수십 번 요청될 수 있어(작두 한 번에 적 20마리 타격)
## 키마다 최소 간격을 두고 겹침을 막는다. 안 그러면 소리가 뭉개지고 클리핑이 난다.

const SFX_DIR: String = "res://assets/audio/"
const SFX_FILES: Dictionary = {
	&"jakdu_swing": "sfx_jakdu_swing.wav",
	&"hit": "sfx_hit.wav",
	&"crit": "sfx_crit.wav",
	&"enemy_die": "sfx_enemy_die.wav",
	&"pickup": "sfx_pickup.wav",
	&"level_up": "sfx_level_up.wav",
	&"god_pick": "sfx_god_pick.wav",
	&"synergy": "sfx_synergy.wav",
	&"taegi": "sfx_taegi.wav",
	&"player_hurt": "sfx_player_hurt.wav",
	&"gate_clear": "sfx_gate_clear.wav",
	&"player_die": "sfx_player_die.wav",
}
const BGM_FILE: String = "res://assets/audio/bgm_gate_loop.wav"

## 같은 키를 이 간격 안에 다시 요청하면 무시한다(초).
const DEFAULT_MIN_INTERVAL: float = 0.05
const MIN_INTERVAL: Dictionary = {
	&"hit": 0.045,
	&"pickup": 0.06,
	&"enemy_die": 0.05,
	&"crit": 0.08,
	&"jakdu_swing": 0.1,
}
## 동시에 울릴 수 있는 효과음 수. 넘으면 가장 오래된 것을 재사용한다.
const VOICES: int = 16

@export var sfx_volume_db: float = -6.0
@export var bgm_volume_db: float = -16.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}
var _bgm: AudioStreamPlayer
## 체력이 줄었는지 판정하려고 직전 값을 들고 있는다.
var _last_hp: float = 0.0


func _ready() -> void:
	# 일시정지 중에도 UI 소리와 BGM 은 나야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		player.volume_db = sfx_volume_db
		add_child(player)
		_players.append(player)

	for key: StringName in SFX_FILES:
		var path: String = SFX_DIR + SFX_FILES[key]
		var stream := load(path) as AudioStream
		if stream == null:
			push_error("효과음을 불러오지 못했다: %s" % path)
			continue
		_streams[key] = stream

	_bgm = AudioStreamPlayer.new()
	_bgm.bus = &"Master"
	_bgm.volume_db = bgm_volume_db
	add_child(_bgm)
	var bgm_stream := load(BGM_FILE) as AudioStream
	if bgm_stream == null:
		push_error("BGM 을 불러오지 못했다: %s" % BGM_FILE)
	else:
		# WAV 는 임포트 설정이 아니라 코드에서 루프를 켠다(에셋 교체 시에도 유지되도록).
		if bgm_stream is AudioStreamWAV:
			(bgm_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(bgm_stream as AudioStreamWAV).loop_end = (bgm_stream as AudioStreamWAV).data.size() / 2
		_bgm.stream = bgm_stream

	_connect_cues()


## 이벤트로 알 수 있는 소리는 여기서 한 번에 묶는다 — 게임플레이 코드에 재생 호출을 흩뿌리면
## 어디서 무슨 소리가 나는지 추적이 안 된다. 무기 타격음처럼 이벤트가 없는 것만 호출부에 남긴다.
func _connect_cues() -> void:
	EventBus.damage_dealt.connect(func(_pos, _amount, is_crit): play(&"crit" if is_crit else &"hit"))
	EventBus.enemy_died.connect(func(_e, _p): play(&"enemy_die"))
	EventBus.xp_collected.connect(func(_amount): play(&"pickup"))
	EventBus.player_leveled_up.connect(func(_level): play(&"level_up"))
	EventBus.god_served.connect(func(_god): play(&"god_pick"))
	EventBus.synergy_formed.connect(func(_synergy): play(&"synergy"))
	EventBus.gate_cleared.connect(func(_gate): play(&"gate_clear"))
	EventBus.player_died.connect(func(): play(&"player_die"))
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.taegi_state_changed.connect(func(active): if active: play(&"taegi"))
	# 몸주가 정해지는 순간이 런의 시작이다.
	EventBus.momju_chosen.connect(func(_god): play_bgm())


## 체력 신호는 회복·최대치 변경에도 오므로 줄어든 경우만 피격으로 친다.
func _on_player_health_changed(current: float, _maximum: float) -> void:
	if current < _last_hp:
		play(&"player_hurt")
	_last_hp = current


func play(key: StringName, pitch_variation: float = 0.06) -> void:
	if not _streams.has(key):
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	var gap: float = MIN_INTERVAL.get(key, DEFAULT_MIN_INTERVAL)
	if now - float(_last_played.get(key, -999.0)) < gap:
		return
	_last_played[key] = now

	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = _streams[key]
	# 같은 소리가 반복될 때 음정을 미세하게 흔들면 기계적으로 들리지 않는다.
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.volume_db = sfx_volume_db
	player.play()


func play_bgm() -> void:
	if _bgm != null and _bgm.stream != null and not _bgm.playing:
		_bgm.play()


func stop_bgm() -> void:
	if _bgm != null:
		_bgm.stop()
