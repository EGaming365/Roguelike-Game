extends StaticBody2D

const UPGRADE_NAMES: Dictionary = {
	"kinetic_ram": "Kinetic Ram",
	"arc_conduit": "Arc Conduit",
	"tesla_tower": "Tesla Tower",
	"overclocked_servos": "Overclocked Servos"
}

@export var upgrade_pool: Array[String] = ["kinetic_ram", "arc_conduit", "tesla_tower", "overclocked_servos"]
@export var interact_action: StringName = &"interact"
@export var prompt_text: String = "[E] Install upgrade"
@export var fry_time: float = 0.7
@export var fry_shake: float = 3.0
@export var fry_flicker_interval: float = 0.05
@export var fry_flash_color: Color = Color(1.0, 0.95, 0.4)
@export var fried_tint: Color = Color(0.25, 0.25, 0.28)
@export var result_width: float = 200.0
@export var result_rise: float = 40.0
@export var result_lifetime: float = 1.6
@export var show_hitboxes: bool = true
@export var solid_hitbox_color: Color = Color(0.2, 1.0, 0.3, 0.9)
@export var zone_hitbox_color: Color = Color(0.3, 0.8, 1.0, 0.9)
@export var print_debug: bool = false

@onready var solid_collider: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var zone: Area2D = get_node_or_null("InteractZone") as Area2D
@onready var zone_collider: CollisionShape2D = get_node_or_null("InteractZone/CollisionShape2D") as CollisionShape2D
@onready var prompt: Label = get_node_or_null("Prompt") as Label
@onready var sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D
@onready var fried_sprite: Sprite2D = get_node_or_null("FriedSprite") as Sprite2D
@onready var result_template: Label = get_node_or_null("ResultLabel") as Label

var used: bool = false
var fry_left: float = 0.0
var flicker_left: float = 0.0
var flicker_on: bool = false
var sprite_rest_position: Vector2 = Vector2.ZERO
var player_was_inside: bool = false


func _ready() -> void:
	if solid_collider == null:
		push_warning("Upgrade station is missing a child node named CollisionShape2D")
	elif solid_collider.shape == null:
		push_warning("Upgrade station's CollisionShape2D has no shape assigned")
	else:
		solid_collider.z_index = 100
		solid_collider.draw.connect(draw_solid_hitbox)
		solid_collider.queue_redraw()

	if zone == null:
		push_warning("Upgrade station is missing a child Area2D named InteractZone")
	elif zone_collider == null or zone_collider.shape == null:
		push_warning("Upgrade station's InteractZone needs a CollisionShape2D child with a shape")
	else:
		zone_collider.z_index = 100
		zone_collider.draw.connect(draw_zone_hitbox)
		zone_collider.queue_redraw()

	if prompt != null:
		prompt.text = prompt_text
		prompt.visible = false

	if sprite != null:
		sprite_rest_position = sprite.position
	if fried_sprite != null:
		fried_sprite.visible = false
	if result_template != null:
		result_template.visible = false

	if not InputMap.has_action(interact_action):
		push_warning("Input action " + String(interact_action) + " not found. Add it in Project Settings > Input Map")

	if print_debug:
		print("Upgrade station ready | solid shape: ", solid_collider != null and solid_collider.shape != null, " | zone: ", zone != null, " | pool size: ", upgrade_pool.size(), " | action exists: ", InputMap.has_action(interact_action))


func _physics_process(delta: float) -> void:
	update_fry(delta)

	var player: Node2D = find_player_in_zone()
	var inside: bool = player != null

	if print_debug and inside != player_was_inside:
		print("Upgrade station: player ", "entered" if inside else "left", " the interact zone")
	player_was_inside = inside

	if prompt != null:
		prompt.visible = inside and not used

	if not InputMap.has_action(interact_action):
		return

	if Input.is_action_just_pressed(interact_action):
		if not inside:
			if print_debug:
				print("Upgrade station: interact pressed but the player is not inside InteractZone")
			return
		if used:
			if print_debug:
				print("Upgrade station: already used")
			return
		use_station(player)


func find_player_in_zone() -> Node2D:
	if zone == null:
		return null
	for body in zone.get_overlapping_bodies():
		if body.is_in_group("player"):
			return body as Node2D
	return null


func use_station(player: Node2D) -> void:
	if upgrade_pool.is_empty():
		print("Upgrade station: the upgrade pool is empty")
		return
	if not player.has_method("add_upgrade"):
		print("Upgrade station: the player has no add_upgrade method, so player.gd may be an old version")
		return
	if player.get("upgrades") == null:
		print("Upgrade station: the Player has no child node named Upgrades")
		return

	var upgrade_id: String = upgrade_pool[randi() % upgrade_pool.size()]
	player.call("add_upgrade", upgrade_id)

	used = true
	fry_left = fry_time
	flicker_left = 0.0
	show_result(upgrade_id)

	if print_debug:
		print("Upgrade station gave: ", upgrade_id)


func update_fry(delta: float) -> void:
	if not used or fry_left <= 0.0:
		return

	fry_left = maxf(fry_left - delta, 0.0)
	flicker_left -= delta
	if flicker_left <= 0.0:
		flicker_on = not flicker_on
		flicker_left = fry_flicker_interval

	if sprite != null:
		sprite.position = sprite_rest_position + Vector2(randf_range(-fry_shake, fry_shake), randf_range(-fry_shake, fry_shake))
		sprite.modulate = fry_flash_color if flicker_on else Color.WHITE

	if fry_left <= 0.0:
		finish_fry()


func finish_fry() -> void:
	if sprite == null:
		return
	sprite.position = sprite_rest_position
	if fried_sprite != null:
		sprite.visible = false
		fried_sprite.visible = true
	else:
		sprite.modulate = fried_tint


func show_result(upgrade_id: String) -> void:
	if result_template == null:
		return

	var label: Label = result_template.duplicate() as Label
	label.text = String(UPGRADE_NAMES.get(upgrade_id, upgrade_id))
	label.visible = true
	label.z_index = 200
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = result_width
	get_tree().current_scene.add_child(label)

	var start: Vector2 = result_template.global_position - Vector2(result_width * 0.5, 0.0)
	label.global_position = start

	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", start.y - result_rise, result_lifetime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, result_lifetime * 0.4).set_delay(result_lifetime * 0.6)
	tween.chain().tween_callback(label.queue_free)


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
