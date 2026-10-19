class_name AppIcon
extends Button

@export var app_title: String = "App"
@export var app_scene: PackedScene


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	if text.is_empty():
		text = app_title
