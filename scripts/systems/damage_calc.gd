class_name DamageCalc

## 데미지 공식 한 곳(design.md 2-2). 무기 셋이 각자 치명·오행을 굴리면 반드시 어긋나므로
## 계산은 전부 여기를 거친다.
##
##   최종 = 기본 × (1 + 신 데미지% 합계/100) × 오행 배율 × (치명 시 치명 배율)
##
## 신 효과를 곱연산으로 쌓으면 신을 모을수록 폭발하므로 **가산 후 1회 곱**으로 고정한다.

const CRIT_BASE_CHANCE_PCT: float = 5.0
const CRIT_BASE_MULT: float = 2.0

const COUNTER_MULT: float = 1.25
const RESISTED_MULT: float = 0.80

## 상극 관계(design.md 3-3): 木→土, 土→水, 水→火, 火→金, 金→木
const OVERCOMES: Dictionary = {
	&"wood": &"earth",
	&"earth": &"water",
	&"water": &"fire",
	&"fire": &"metal",
	&"metal": &"wood",
}


## 공격자 기운이 대상 오행을 극하면 1.25, 반대로 극당하면 0.80, 그 외 1.0.
static func element_multiplier(attacker: StringName, target: StringName) -> float:
	if attacker == &"" or target == &"":
		return 1.0
	if OVERCOMES.get(attacker, &"") == target:
		return COUNTER_MULT
	if OVERCOMES.get(target, &"") == attacker:
		return RESISTED_MULT
	return 1.0


## 적 노드에서 오행을 읽는다. EnemyData 가 없으면 무속성으로 친다.
static func target_element(target: Node) -> StringName:
	if target == null or not is_instance_valid(target):
		return &""
	var data: EnemyData = target.get(&"data")
	return data.element if data != null else &""


## 한 번의 타격을 계산한다. weapon_damage_key 는 무기 전용 데미지 키(예: &"jakdu_damage_pct").
## 반환: { "amount": float, "is_crit": bool }
static func resolve(
	base_damage: float,
	god_system: Node,
	weapon_damage_key: StringName,
	target: Node
) -> Dictionary:
	var damage_pct := 0.0
	var crit_chance := CRIT_BASE_CHANCE_PCT
	var crit_mult := CRIT_BASE_MULT
	var attacker_element: StringName = &""

	# 무기는 GodSystem 없이도 단독으로 동작해야 한다(테스트·프리뷰).
	if god_system != null:
		# 범용 데미지와 무기 전용 데미지를 먼저 더하고 마지막에 한 번만 곱한다.
		damage_pct = god_system.get_mod(&"damage_pct")
		if weapon_damage_key != &"":
			damage_pct += god_system.get_mod(weapon_damage_key)
		crit_chance += god_system.get_mod(&"crit_chance_pct")
		crit_mult *= 1.0 + god_system.get_mod(&"crit_damage_pct") * 0.01
		attacker_element = god_system.get_element()

	var amount := base_damage * (1.0 + damage_pct * 0.01)
	amount *= element_multiplier(attacker_element, target_element(target))

	# 치명은 타격마다 개별 판정한다 — 다발 무기(부적 7발)도 발마다 굴린다.
	var is_crit := randf() * 100.0 < crit_chance
	if is_crit:
		amount *= crit_mult

	return {"amount": amount, "is_crit": is_crit}
