extends Control

signal closed

@export var app_title: String = "Blank App"

@onready var title_label: Label = find_child("Title", true, false) as Label
@onready var close_button: Button = find_child("CloseButton", true, false) as Button


func _ready() -> void:
	if title_label != null:
		title_label.text = app_title

	if close_button == null:
		push_warning("Blank app is missing a Button named CloseButton")
		return

	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)


func close() -> void:
	closed.emit()
