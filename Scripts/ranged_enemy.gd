extends CharacterBody2D

enum State { IDLE, KEEP_DISTANCE, AIM, FIRE, PAUSE, STUNNED }

const FLASH_SHADER_CODE: String = "shader_type canvas_item;\nuniform float flash_amount : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tCOLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash_amount);\n}\n"

@export var max_health: int = 100
@export var detect_range: float = 1000.0
@export var shoot_range: float = 600.0
@export var flee_distance: float = 220.0
@export var shoot_while_fleeing: bool = true
@export var move_speed: float = 150.0
@export var flee_speed: float = 200.0
@export var sprite_faces_right: bool = true
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 800.0
@export var projectile_damage: int = 8
@export var burst_count: int = 5
@export var burst_interval: float = 0.2
@export var burst_spread_degrees: float = 3.0
@export var muzzle_offset: Vector2 = Vector2(0.0, -12.0)
@export var muzzle_distance: float = 20.0
@export var aim_time: float = 0.45
@export var after_burst_pause: float = 0.3
@export var attack_cooldown: float = 2
@export var exclamation_flash_interval: float = 0.07
@export var exclamation_color: Color = Color(1.0, 0.1, 0.1)
@export var knockback_speed: float = 160.0
@export var knockback_decay: float = 900.0
@export var stun_tint: Color = Color(0.6, 0.85, 1.0)
@export var flash_time: float = 0.08
@export var death_fade_time: float = 0.25
@export var show_hitboxes: bool = true
@export var hurtbox_color: Color = Color(0.2, 1.0, 0.3, 0.9)
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
@onready var exclamation: Label = get_node_or_null("Exclamation") as Label
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var number_template: Label = get_node_or_null("DamageNumber") as Label

var state: State = State.IDLE
var state_time: float = 0.0
var health: int = 0
var dead: bool = false
var player: Node2D
var ignoring_player: bool = false
var facing_direction: Vector2 = Vector2.DOWN
var knockback_velocity: Vector2 = Vector2.ZERO
var stun_left: float = 0.0
var flash_left: float = 0.0
var flash_material: ShaderMaterial
var attack_cooldown_left: float = 0.0
var shots_fired: int = 0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	health = max_health
	add_to_group("enemy")

	if sprite != null:
		flash_material = ShaderMaterial.new()
		var shader: Shader = Shader.new()
		shader.code = FLASH_SHADER_CODE
		flash_material.shader = shader
		sprite.material = flash_material
	else:
		push_warning("Ranged enemy is missing a child node named Sprite")

	if exclamation != null:
		exclamation.text = "!"
		exclamation.add_theme_color_override("font_color", exclamation_color)
		exclamation.visible = false

	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = health

	if number_template != null:
		number_template.visible = false

	if projectile_scene == null:
		push_warning("Ranged enemy has no Projectile Scene assigned in the Inspector")

	if hurtbox == null:
		push_warning("Ranged enemy is missing a child node named CollisionShape2D")
	elif hurtbox.shape == null:
		push_warning("Ranged enemy's CollisionShape2D has no shape assigned")
	else:
		hurtbox.z_index = 100
		hurtbox.draw.connect(draw_hurtbox)
		hurtbox.queue_redraw()


func _process(delta: float) -> void:
	flash_left = maxf(flash_left - delta, 0.0)
	if flash_material != null:
		flash_material.set_shader_parameter("flash_amount", 1.0 if flash_left > 0.0 else 0.0)
	if sprite != null:
		sprite.modulate = stun_tint if state == State.STUNNED else Color.WHITE
	update_exclamation()


func _physics_process(delta: float) -> void:
	if dead:
		return

	state_time += delta
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	find_player()
	sync_player_collision()

	var to_player: Vector2 = Vector2.ZERO
	var distance: float = INF
	if player != null:
		to_player = player.global_position - global_position
		distance = to_player.length()

	var move_velocity: Vector2 = Vector2.ZERO

	match state:
		State.IDLE:
			if distance <= detect_range:
				change_state(State.KEEP_DISTANCE)
		State.KEEP_DISTANCE:
			if distance > detect_range:
				change_state(State.IDLE)
			else:
				face_player()
				var direction: Vector2 = to_player.normalized()
				var can_shoot: bool = attack_cooldown_left <= 0.0 and distance <= shoot_range
				if can_shoot and (shoot_while_fleeing or distance >= flee_distance):
					change_state(State.AIM)
				elif distance < flee_distance:
					move_velocity = -direction * flee_speed
				elif distance > shoot_range:
					move_velocity = direction * move_speed
		State.AIM:
			face_player()
			if state_time >= aim_time:
				change_state(State.FIRE)
		State.FIRE:
			face_player()
			if shots_fired < burst_count and state_time >= float(shots_fired) * burst_interval:
				fire_projectile()
				shots_fired += 1
			if shots_fired >= burst_count:
				attack_cooldown_left = attack_cooldown
				change_state(State.PAUSE)
		State.PAUSE:
			face_player()
			if state_time >= after_burst_pause:
				change_state(State.KEEP_DISTANCE)
		State.STUNNED:
			stun_left = maxf(stun_left - delta, 0.0)
			if stun_left <= 0.0:
				change_state(State.KEEP_DISTANCE)

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	velocity = move_velocity + knockback_velocity
	move_and_slide()


func change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	match new_state:
		State.AIM:
			face_player()
		State.FIRE:
			shots_fired = 0


func stun(duration: float) -> void:
	if dead:
		return
	stun_left = maxf(stun_left, duration)
	if state != State.STUNNED:
		change_state(State.STUNNED)


func fire_projectile() -> void:
	if projectile_scene == null:
		return
	var muzzle_position: Vector2 = global_position + muzzle_offset
	var direction: Vector2 = facing_direction
	if player != null:
		direction = (player.global_position - muzzle_position).normalized()
	direction = direction.rotated(deg_to_rad(randf_range(-burst_spread_degrees, burst_spread_degrees)))
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		return
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle_position + direction * muzzle_distance
	projectile.call("launch", direction, projectile_speed, projectile_damage)


func find_player() -> void:
	if player != null and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as Node2D


func sync_player_collision() -> void:
	if player == null:
		return
	var height_value: Variant = player.get("height")
	var airborne: bool = height_value != null and float(height_value) > 0.0
	if airborne and not ignoring_player:
		add_collision_exception_with(player)
		ignoring_player = true
	elif not airborne and ignoring_player:
		remove_collision_exception_with(player)
		ignoring_player = false


func direction_to_player() -> Vector2:
	if player == null:
		return Vector2.ZERO
	return (player.global_position - global_position).normalized()


func face_player() -> void:
	var direction: Vector2 = direction_to_player()
	if direction != Vector2.ZERO:
		facing_direction = direction
		update_sprite_facing(direction)


func update_sprite_facing(direction: Vector2) -> void:
	if sprite != null and absf(direction.x) > 0.01:
		sprite.flip_h = (direction.x < 0.0) == sprite_faces_right


func update_exclamation() -> void:
	if exclamation == null:
		return
	if state == State.AIM and not dead:
		exclamation.visible = int(state_time / maxf(exclamation_flash_interval, 0.001)) % 2 == 0
	else:
		exclamation.visible = false


func take_damage(amount: int, from_position: Vector2) -> void:
	if dead:
		return
	health = maxi(health - amount, 0)
	if print_hits:
		print("Ranged enemy hit for ", amount, ", health ", health, "/", max_health)
	if health_bar != null:
		health_bar.value = health
	flash_left = flash_time
	var away: Vector2 = global_position - from_position
	if away != Vector2.ZERO:
		knockback_velocity = away.normalized() * knockback_speed
	spawn_damage_number(amount)
	if health <= 0:
		die()


func die() -> void:
	dead = true
	velocity = Vector2.ZERO
	if hurtbox != null:
		hurtbox.set_deferred("disabled", true)
	var tween: Tween = create_tween()
	tween.tween_interval(flash_time)
	tween.tween_property(self, "modulate:a", 0.0, death_fade_time)
	tween.tween_callback(queue_free)


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


func draw_hurtbox() -> void:
	if not show_hitboxes or hurtbox == null:
		return
	var rectangle: RectangleShape2D = hurtbox.shape as RectangleShape2D
	if rectangle != null:
		hurtbox.draw_rect(Rect2(-rectangle.size * 0.5, rectangle.size), hurtbox_color, false, 1.0)
		return
	var circle: CircleShape2D = hurtbox.shape as CircleShape2D
	if circle != null:
		hurtbox.draw_arc(Vector2.ZERO, circle.radius, 0.0, TAU, 32, hurtbox_color, 1.0)
