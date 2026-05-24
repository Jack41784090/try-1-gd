class_name RecruitmentView extends Control

signal recruitment_completed(warrior: Warrior)
signal closed

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var title_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var money_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/MoneyLabel
@onready var classes_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/ScrollContainer/ClassesContainer
@onready var close_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CloseButton

const WARRIOR_ITEM_SCENE = preload("res://scenes/warrior_item.tscn")

var actor: ActivityRunner
var current_squad: SquadData:
	get:
		return actor.player_squad

var _class_items: Array[RecruitmentClassItem]

func setup(_actor) -> void:
	assert(_actor is ActivityRunner)
	actor = _actor

func _ready() -> void:
	overlay_panel.visible = false
	close_button.pressed.connect(_on_close_pressed)

	for child in classes_container.get_children():
		var item := child as RecruitmentClassItem
		item.recruit_pressed.connect(_on_recruit_pressed_from_item)
		_class_items.append(item)

	for item in _class_items:
		item.visible = false

func show_recruitment_menu() -> void:
	self.visible = true
	overlay_panel.visible = true
	_update_display()
	await UIAnimations.show_overlay(self , overlay_panel)

func hide_recruitment_menu() -> void:
	await UIAnimations.hide_overlay(self , overlay_panel)
	overlay_panel.visible = false

func _update_display() -> void:
	title_label.text = "Recruit Warriors"
	money_label.text = "Available Money: %.0f" % current_squad.money

	var backgrounds := WarriorBackgroundFactory.all()
	for i in _class_items.size():
		if i < backgrounds.size():
			var bg: WarriorBackground = backgrounds[i]
			var can_afford := current_squad.money >= bg.cost
			_class_items[i].populate(bg, can_afford)
		else:
			_class_items[i].visible = false

func _on_recruit_pressed_from_item(background: WarriorBackground) -> void:
	var cost: int = background.cost
	if current_squad.money < cost:
		return

	var new_warrior = WarriorFactory.create_warrior(
		background.background_id,
		"warrior_%d_%d" % [actor.aem.world.current_hour, randi()],
		"%s Recruit" % background.display_name,
		StrategyTypes.Religion.CATHOLIC
	)

	current_squad.add_warrior(new_warrior)
	current_squad.money -= cost

	print("[RecruitmentView] Recruited %s for %d gold" % [new_warrior.name, cost])

	recruitment_completed.emit(new_warrior)
	hide_recruitment_menu()

func _on_close_pressed() -> void:
	hide_recruitment_menu()
	closed.emit()
