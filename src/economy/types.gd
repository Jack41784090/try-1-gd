extends RefCounted
class_name EconomyTypes

enum SocialClass {
	PEASANT,
	BOURGEOIS,
	NOBLE,
}

enum JobType {
	FARMER,
	MERCHANT,
	LANDLORD,
	CRAFTSMAN,
	LABORER,
	SERVANT,
	TAX_COLLECTOR,
	UNEMPLOYED,
}

enum MoveState {
	PLANNED,
	IN_TRANSIT,
	COMPLETED,
	CANCELLED,
	CAPTURED,
}

enum RuleAction {
	EXTRACT,
	PRODUCE,
	IMPORT,
}

enum ThingType {
	FOOD,
	MONEY,
	CLOTH,
	TOOLS,
	LUXURY,
}
