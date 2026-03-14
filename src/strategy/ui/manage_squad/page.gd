class_name ManageSquadPage
extends Control

@onready var presenter = $ManageSquadPagePresenter
@onready var overlay_panel: PanelContainer = $OverlayPanel

@onready var tab_tactics: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/TacticsBtn
@onready var tab_units: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/UnitsBtn
@onready var tab_formation: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/FormationBtn
@onready var tab_recruitment: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/RecruitmentBtn
@onready var close_button: Button = $OverlayPanel/MainMargin/MainVBox/NavBar/CloseBtn

@onready var tab_container: Control = $OverlayPanel/MainMargin/MainVBox/TabContainer

@onready var tactics_tab = $OverlayPanel/MainMargin/MainVBox/TabContainer/TacticsTab
@onready var units_tab = $OverlayPanel/MainMargin/MainVBox/TabContainer/UnitsTab
@onready var formation_tab = $OverlayPanel/MainMargin/MainVBox/TabContainer/FormationTab
@onready var recruitment_tab = $OverlayPanel/MainMargin/MainVBox/TabContainer/RecruitmentTab

var _nav_buttons: Array[Button] = []


func _ready() -> void:
	presenter.bind_view(self)

	_nav_buttons = [tab_tactics, tab_units, tab_formation, tab_recruitment]
	for btn in _nav_buttons:
		UIAnimations.register_button(btn)
	UIAnimations.register_button(close_button)

	tab_tactics.pressed.connect(func(): presenter.switch_tab(0))
	tab_units.pressed.connect(func(): presenter.switch_tab(1))
	tab_formation.pressed.connect(func(): presenter.switch_tab(2))
	tab_recruitment.pressed.connect(func(): presenter.switch_tab(3))
	close_button.pressed.connect(func(): presenter.close())

	tactics_tab.tactic_selected.connect(func(t): presenter.on_tactic_selected(t))
	formation_tab.formation_changed.connect(func(w, p): presenter.on_formation_changed(w, p))
	recruitment_tab.recruit_requested.connect(func(c, cost): presenter.on_recruit(c, cost))


func show_tab(tab: int) -> void:
	tactics_tab.visible = tab == 0
	units_tab.visible = tab == 1
	formation_tab.visible = tab == 2
	recruitment_tab.visible = tab == 3

	_update_nav_highlight(tab)


func _update_nav_highlight(tab: int) -> void:
	var active_btn: Button = _nav_buttons[tab]
	for btn in _nav_buttons:
		if btn == active_btn:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75, 1.0))
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")
