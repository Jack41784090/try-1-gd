class_name EntityBaseStats extends Resource

@export var strength: float
@export var dex: float
@export var acr: float
@export var spd: float
@export var siz: float
@export var int_stat: float
@export var spr: float
@export var fai: float
@export var cha: float
@export var beu: float
@export var wil: float
@export var endurance: float
	
func _init(
	p_id: String = "",
	p_str: float= 1, p_dex: float= 1, p_acr: float= 1,
	p_spd: float= 1, p_siz: float= 1, p_int: float= 1, p_spr: float= 1,
	p_fai: float= 1, p_cha: float= 1, p_beu: float= 1, p_wil: float= 1,
	p_end: float= 1):
	strength = p_str
	dex = p_dex
	acr = p_acr
	spd = p_spd
	siz = p_siz
	int_stat = p_int
	spr = p_spr
	fai = p_fai
	cha = p_cha
	beu = p_beu
	wil = p_wil
	endurance = p_end
