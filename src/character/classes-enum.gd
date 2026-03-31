class_name EntityClasses
enum Types {
	Landsknecht,
	Healer,
	Crossbowman,
	Arquebusier,
	Pikeman,
	Feldprediger,
	Gelehrter
}

const SPEED_TABLE: Dictionary = {
	Types.Landsknecht: 5.0,
	Types.Healer: 5.5,
	Types.Crossbowman: 4.5,
	Types.Arquebusier: 4.5,
	Types.Pikeman: 4.0,
	Types.Feldprediger: 5.0,
	Types.Gelehrter: 4.5,
}
