extends StaticBody2D

const FLASH_SHADER_CODE: String = "shader_type canvas_item;\nuniform float flash_amount : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tCOLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash_amount);\n}\n"

@export var max_health: int = 200
@export var reset_delay: float = 1.0
@export var flash_time: float = 0.08
@export var hit_push: float = 5.0
@export var hit_push_recovery: float = 40.0
@export var show_hitbox: bool = true
@export var hitbox_color: Color = Color(0.2, 1.0, 0.3, 0.9)
@export var print_hits: bool = false
@export var number_width: float = 48.0
@export var number_lifetime: float = 0.8
@export var number_direction_degrees: float = -90.0
@export var number_spread_degrees: float = 55.0
@export var number_distance_min: float = 22.0
@export var number_distance_max: float = 40.0
@export var number_pop_scale: float = 1.6
@export var number_pop_time: float = 0.14
@export var number_fade_start: float = 0.55

@onready var hurtbox: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var number_template: Label = get_node_or_null("DamageNumber") as Label

var health: int = 0
var flash_left: float = 0.0
var reset_left: float = 0.0
var push_offset: Vector2 = Vector2.ZERO
var sprite_rest_position: Vector2 = Vector2.ZERO
var flash_material: ShaderMaterial


func _ready() -> void:
	health = max_health

	if hurtbox == null:
		push_warning("Dummy is missing a child node named CollisionShape2D")
	elif hurtbox.shape == null:
		push_warning("Dummy's CollisionShape2D has no shape assigned, so attacks cannot hit it")
	else:
		hurtbox.z_index = 100
		hurtbox.draw.connect(draw_hitbox)
		hurtbox.queue_redraw()

	if sprite == null:
		push_warning("Dummy is missing a child node named Sprite")
	else:
		sprite_rest_position = sprite.position
		flash_material = ShaderMaterial.new()
		var shader: Shader = Shader.new()
		shader.code = FLASH_SHADER_CODE
		flash_material.shader = shader
		sprite.material = flash_material

	if health_bar == null:
		push_warning("Dummy is missing a child node named HealthBar")
	else:
		health_bar.max_value = max_health
		health_bar.value = health

	if number_template == null:
		push_warning("Dummy is missing a child node named DamageNumber")
	else:
		number_template.visible = false


func _process(delta: float) -> void:
	flash_left = maxf(flash_left - delta, 0.0)
	push_offset = push_offset.move_toward(Vector2.ZERO, hit_push_recovery * delta)

	if sprite != null:
		sprite.position = sprite_rest_position + push_offset
		flash_material.set_shader_parameter("flash_amount", 1.0 if flash_left > 0.0 else 0.0)

	if reset_left > 0.0:
		reset_left -= delta
		if reset_left <= 0.0:
			health = max_health
			update_health_bar()


func take_damage(amount: int, from_position: Vector2) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	if print_hits:
		print("Dummy hit for ", amount, ", health ", health, "/", max_health)
	update_health_bar()
	flash_left = flash_time
	var away: Vector2 = global_position - from_position
	if away != Vector2.ZERO:
		push_offset = away.normalized() * hit_push
	spawn_damage_number(amount)
	if health <= 0:
		reset_left = reset_delay


func update_health_bar() -> void:
	if health_bar != null:
		health_bar.value = health


func spawn_damage_number(amount: int) -> void:
	if number_template == null:
		return

	var label: Label = number_template.duplicate() as Label
	label.text = str(amount)
	label.visible = true
	label.z_index = 200
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = number_width
	get_tree().current_scene.add_child(label)

	var label_size: Vector2 = label.get_minimum_size()
	label.pivot_offset = Vector2(number_width * 0.5, label_size.y * 0.5)

	var start: Vector2 = number_template.global_position - Vector2(number_width * 0.5, label_size.y * 0.5)
	label.global_position = start

	var angle: float = deg_to_rad(number_direction_degrees + randf_range(-number_spread_degrees, number_spread_degrees))
	var distance: float = randf_range(number_distance_min, number_distance_max)
	var target: Vector2 = start + Vector2.from_angle(angle) * distance

	label.scale = Vector2.ONE * number_pop_scale

	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", target, number_lifetime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(label, "scale", Vector2.ONE, number_pop_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 0.0, number_lifetime * (1.0 - number_fade_start)).set_delay(number_lifetime * number_fade_start)
	tween.chain().tween_callback(label.queue_free)


func draw_hitbox() -> void:
	if not show_hitbox or hurtbox == null:
		return
	var rectangle: RectangleShape2D = hurtbox.shape as RectangleShape2D
	if rectangle != null:
		hurtbox.draw_rect(Rect2(-rectangle.size * 0.5, rectangle.size), hitbox_color, false, 1.0)
		return
	var circle: CircleShape2D = hurtbox.shape as CircleShape2D
	if circle != null:
		hurtbox.draw_arc(Vector2.ZERO, circle.radius, 0.0, TAU, 32, hitbox_color, 1.0)
