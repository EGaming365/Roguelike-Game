extends Control

enum Phase { IDLE, DYING, WAITING, CONTINUING }

@export var player_group: StringName = &"player"
@export var continue_action: StringName = &"select"
@export var death_message: String = "Death"
@export var prompt_message: String = "Press Enter to continue"
@export var fade_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var fade_to_black_time: float = 2.0
@export var message_delay: float = 1.0
@export var message_fade_in_time: float = 0.8
@export var prompt_delay: float = 2.0
@export var prompt_fade_in_time: float = 0.8
@export var text_fade_out_time: float = 0.8
@export var black_hold_time: float = 0.4
@export var fade_from_black_time: float = 0.3

@onready var fade: ColorRect = find_child("Fade", true, false) as ColorRect
@onready var message: Label = find_child("Message", true, false) as Label
@onready var prompt: Label = find_child("Prompt", true, false) as Label

var phase: Phase = Phase.IDLE
var player: Node = null
var sequence: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	if fade == null or message == null or prompt == null:
		push_warning("DeathScreen needs children named Fade (ColorRect), Message (Label) and Prompt (Label)")
		set_process(false)
		set_process_input(false)
		return

	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(fade_color, 0.0)
	message.modulate.a = 0.0
	prompt.modulate.a = 0.0


func _process(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		return

	var found: Node = get_tree().get_first_node_in_group(player_group)
	if found == null or not found.has_signal("died"):
		return

	player = found
	found.connect("died", on_player_died)


func _input(event: InputEvent) -> void:
	if phase != Phase.WAITING:
		return
	if not InputMap.has_action(continue_action) or not event.is_action_pressed(continue_action):
		return
	get_viewport().set_input_as_handled()
	begin_continue()


func kill_sequence() -> void:
	if sequence != null and sequence.is_valid():
		sequence.kill()


func on_player_died() -> void:
	kill_sequence()
	phase = Phase.DYING
	visible = true

	message.text = death_message
	prompt.text = prompt_message
	fade.color = Color(fade_color, 0.0)
	message.modulate.a = 0.0
	prompt.modulate.a = 0.0

	sequence = create_tween()
	sequence.set_parallel(true)
	sequence.tween_property(fade, "color:a", fade_color.a, fade_to_black_time)
	sequence.tween_property(message, "modulate:a", 1.0, message_fade_in_time).set_delay(message_delay)
	sequence.tween_property(prompt, "modulate:a", 1.0, prompt_fade_in_time).set_delay(message_delay + prompt_delay)
	sequence.chain().tween_callback(on_prompt_ready)


func on_prompt_ready() -> void:
	phase = Phase.WAITING


func begin_continue() -> void:
	phase = Phase.CONTINUING
	kill_sequence()
	
	sequence = create_tween()
	sequence.set_parallel(true)
	sequence.tween_property(message, "modulate:a", 0.0, text_fade_out_time)
	sequence.tween_property(prompt, "modulate:a", 0.0, text_fade_out_time)
	sequence.chain().tween_callback(respawn_player)
	sequence.chain().tween_interval(black_hold_time)
	sequence.chain().tween_property(fade, "color:a", 0.0, fade_from_black_time)
	sequence.chain().tween_callback(finish)


func respawn_player() -> void:
	if player != null and is_instance_valid(player) and player.has_method("respawn"):
		player.respawn()


func finish() -> void:
	phase = Phase.IDLE
	visible = false
