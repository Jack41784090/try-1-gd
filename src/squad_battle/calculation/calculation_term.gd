class_name CalculationTerm extends Resource

## Curve domain convention: every curve here is authored with min_domain=0.0,
## max_domain=5.0, sampling the raw stat/reality value directly (no normalization).
## See AGENTS.md combat section.
enum InputSource { STAT, REALITY }

@export var source: InputSource = InputSource.STAT
@export var stat: StatName.I
@export var reality: SquadBattleTypes.Reality
@export var curve: Curve


func sample(entity: CombatEntity) -> float:
	var x: float = entity.get_stat_value(stat) if source == InputSource.STAT \
		else entity.calculate_reality_value(reality)
	assert(curve != null, "CalculationTerm has no curve assigned")
	assert(x <= curve.max_domain, "CalculationTerm input %.2f exceeds curve max_domain %.2f — curve would clamp silently" % [x, curve.max_domain])
	return curve.sample(x)
