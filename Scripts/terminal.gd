extends StaticBody2D

@export var ui_scene: PackedScene
@export var interact_action: StringName = &"interact"
@export var prompt_text: String = "[E] Open terminal"
@export var lockout_msec: int = 250
@export var show_hitboxes: bool = true
@export var solid_hitbox_color: Color = Color(0.2, 1.0, 0.3, 0.9)
@export var zone_hitbox_color: Color = Color(0.3, 0.8, 1.0, 0.9)
@export var print_debug: bool = true

@onready var solid_collider: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var zone: Area2D = get_node_or_null("InteractZone") as Area2D
@onready var zone_collider: CollisionShape2D = get_node_or_null("InteractZone/CollisionShape2D") as CollisionShape2D
@onready var prompt: Label = get_node_or_null("Prompt") as Label

var ui_instance: Node = null
var lockout_until_msec: int = 0
var player_was_inside: bool = false


func _ready() -> void:
	if solid_collider == null:
		push_warning("Terminal is missing a child node named CollisionShape2D")
	elif solid_collider.shape == null:
		push_warning("Terminal's CollisionShape2D has no shape assigned")
	else:
		solid_collider.z_index = 100
		solid_collider.draw.connect(draw_solid_hitbox)
		solid_collider.queue_redraw()

	if zone == null:
		push_warning("Terminal is missing a child Area2D named InteractZone")
	elif zone_collider == null or zone_collider.shape == null:
		push_warning("Terminal's InteractZone needs a CollisionShape2D child with a shape")
	else:
		zone_collider.z_index = 100
		zone_collider.draw.connect(draw_zone_hitbox)
		zone_collider.queue_redraw()

	if prompt != null:
		prompt.text = prompt_text
		prompt.visible = false

	if ui_scene == null:
		push_warning("Terminal has no UI Scene assigned in the Inspector")

	if not InputMap.has_action(interact_action):
		push_warning("Input action " + String(interact_action) + " not found. Add it in Project Settings > Input Map")

	if print_debug:
		print("Terminal ready | solid shape: ", solid_collider != null and solid_collider.shape != null, " | zone: ", zone != null, " | ui scene: ", ui_scene != null, " | action exists: ", InputMap.has_action(interact_action))


func _physics_process(_delta: float) -> void:
	var player: Node2D = find_player_in_zone()
	var inside: bool = player != null
	var ui_open: bool = ui_instance != null and is_instance_valid(ui_instance)

	if print_debug and inside != player_was_inside:
		print("Terminal: player ", "entered" if inside else "left", " the interact zone")
	player_was_inside = inside

	if prompt != null:
		prompt.visible = inside and not ui_open

	if ui_open or not InputMap.has_action(interact_action):
		return

	if Input.is_action_just_pressed(interact_action):
		if not inside:
			if print_debug:
				print("Terminal: interact pressed but the player is not inside InteractZone")
			return
		if Time.get_ticks_msec() < lockout_until_msec:
			return
		open_ui()


func find_player_in_zone() -> Node2D:
	if zone == null:
		return null
	for body in zone.get_overlapping_bodies():
		if body.is_in_group("player"):
			return body as Node2D
	return null


func open_ui() -> void:
	if ui_scene == null:
		push_warning("Terminal has no UI Scene assigned in the Inspector")
		return
	ui_instance = ui_scene.instantiate()
	get_tree().current_scene.add_child(ui_instance)
	ui_instance.tree_exited.connect(on_ui_closed)
	if print_debug:
		print("Terminal: UI opened")


func on_ui_closed() -> void:
	ui_instance = null
	lockout_until_msec = Time.get_ticks_msec() + lockout_msec
	if print_debug:
		print("Terminal: UI closed")


func draw_solid_hitbox() -> void:
	if show_hitboxes:
		draw_outline(solid_collider, solid_hitbox_color)


func draw_zone_hitbox() -> void:
	if show_hitboxes:
		draw_outline(zone_collider, zone_hitbox_color)


func draw_outline(collider: CollisionShape2D, color: Color) -> void:
	if collider == null:
		return
	var rectangle: RectangleShape2D = collider.shape as RectangleShape2D
	if rectangle != null:
		collider.draw_rect(Rect2(-rectangle.size * 0.5, rectangle.size), color, false, 1.0)
		return
	var circle: CircleShape2D = collider.shape as CircleShape2D
	if circle != null:
		collider.draw_arc(Vector2.ZERO, circle.radius, 0.0, TAU, 32, color, 1.0)
