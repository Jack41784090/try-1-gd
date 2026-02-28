class_name RecruitmentView extends Control

signal recruitment_completed(warrior: CharacterSocialStats)
signal closed

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var title_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var money_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/MoneyLabel
@onready var classes_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/ScrollContainer/ClassesContainer
@onready var close_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CloseButton

const WARRIOR_ITEM_SCENE = preload("res://scenes/warrior_item.tscn")

var actor: ActivityRunner
var current_squad: SquadStrategicData:
	get:
		return actor.player_squad

var recruitment_costs: Dictionary = {
	"landsknecht": 100.0,
	"healer": 150.0
}

func setup(_actor) -> void:
	assert(_actor is ActivityRunner)
	actor = _actor

func _ready() -> void:
	overlay_panel.visible = false
	close_button.pressed.connect(_on_close_pressed)

func show_recruitment_menu() -> void:
	self.visible = true
	overlay_panel.visible = true
	_update_display()

func hide_recruitment_menu() -> void:
	overlay_panel.visible = false

func _update_display() -> void:
	_clear_class_items()
	
	title_label.text = "Recruit Warriors"
	money_label.text = "Available Money: %.0f" % current_squad.money
	
	for class_enum in EntityClasses.Types.values():
		_create_class_item(class_enum)

func _create_class_item(class_enum: EntityClasses.Types) -> void:
	var entity_template = EntityFactory.get_entity(class_enum)
	var class_id = entity_template.class_id
	var cost = recruitment_costs.get(class_id, 100.0)
	
	var item_panel = PanelContainer.new()
	item_panel.custom_minimum_size = Vector2(0, 100)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	item_panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var icon_rect = TextureRect.new()
	icon_rect.texture = entity_template.icon
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(spacer1)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = entity_template.entity_name
	name_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(name_label)
	
	var cost_label = Label.new()
	cost_label.text = "Cost: %.0f gold" % cost
	cost_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	info_vbox.add_child(cost_label)
	
	var stats_label = Label.new()
	stats_label.text = _format_stats(entity_template.stats)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(stats_label)
	
	var recruit_button = Button.new()
	recruit_button.text = "Recruit"
	recruit_button.custom_minimum_size = Vector2(100, 40)
	recruit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var can_afford = current_squad.money >= cost
	recruit_button.disabled = not can_afford
	
	if not can_afford:
		recruit_button.text = "Can't Afford"
		recruit_button.tooltip_text = "Need %.0f more gold" % (cost - current_squad.money)
	
	recruit_button.pressed.connect(_on_recruit_pressed.bind(class_enum, cost))
	hbox.add_child(recruit_button)
	
	classes_container.add_child(item_panel)

func _format_stats(stats: EntityBaseStats) -> String:
	if not stats:
		return "No stats available"
	
	return "STR:%.0f DEX:%.0f END:%.0f INT:%.0f" % [
		stats.strength,
		stats.dex,
		stats.endurance,
		stats.int_stat
	]

func _on_recruit_pressed(class_enum: EntityClasses.Types, cost: float) -> void:
	if current_squad.money < cost:
		return
	
	var entity_template = EntityFactory.get_entity(class_enum)
	
	var new_warrior = WarriorFactory.create_warrior(
		class_enum,
		"warrior_%d_%d" % [actor.aem.world.turn_count, randi()],
		"%s Recruit" % entity_template.entity_name,
		StrategyTypes.Religion.CATHOLIC,
		entity_template.stats.duplicate(true) if entity_template.stats else EntityBaseStats.new()
	)
	
	#new_warrior.equipment_weapon = WeaponFactory.get_weapon(entity_template.weapon_class).config
	#new_warrior.equipment_armor = ArmorFactory.get_armor(entity_template.armor_class).config
	new_warrior.logic_type = LogicFactory.LogicAvailable.Frontline
	new_warrior.location_prebattle = SquadBattleTypes.SquadEntityInSquadLocation.Front
	
	current_squad.add_warrior(new_warrior)
	current_squad.money -= cost
	
	print("[RecruitmentView] Recruited %s for %.0f gold" % [new_warrior.name, cost])
	
	recruitment_completed.emit(new_warrior)
	hide_recruitment_menu()

func _on_close_pressed() -> void:
	hide_recruitment_menu()
	closed.emit()

func _clear_class_items() -> void:
	for child in classes_container.get_children():
		child.queue_free()
