class_name EntityBaseStats extends Resource

#@export var id: String
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
	
func _init(p_id: String = "", p_str: float = 10, p_dex: float = 10, p_acr: float = 10,
		p_spd: float = 10, p_siz: float = 10, p_int: float = 10, p_spr: float = 10,
		p_fai: float = 10, p_cha: float = 10, p_beu: float = 10, p_wil: float = 10,
		p_end: float = 10):
	#id = p_id
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
