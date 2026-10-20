extends CharacterBody2D

enum State { IDLE, APPROACH, TELEGRAPH, CHARGE, RECOVER, STUNNED }

const FLASH_SHADER_CODE: String = "shader_type canvas_item;\nuniform float flash_amount : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tCOLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash_amount);\n}\n"

@export var max_health: int = 16
@export var detect_range: float = 900.0
@export var walk_speed: float = 90.0
@export var sprite_faces_right: bool = true
@export var charge_trigger_distance: float = 650.0
@export var telegraph_time: float = 0.7
@export var telegraph_shake: float = 2.0
@export var exclamation_flash_interval: float = 0.07
@export var exclamation_color: Color = Color(1.0, 0.1, 0.1)
@export var charge_speed: float = 650.0
@export var charge_acceleration: float = 2200.0
@export var charge_turn_rate_degrees: float = 135.0
@export var charge_duration: float = 1.6
@export var charge_damage: int = 1
@export var charge_hit_radius: float = 60.0
@export var charge_hit_offset: Vector2 = Vector2(0.0, -8.0)
@export var ram_knockback_angle_degrees: float = 30.0
@export var ram_knockback_speed: float = 500.0
@export var ram_enemy_damage: int = 6
@export_flags_2d_physics var ram_collision_mask: int = 1
@export var perfect_dodge_distance: float = 140.0
@export var recovery_time: float = 1.0
@export var crash_extra_recovery: float = 0.6
@export var shockwave_damage: float = 0.5
@export var shockwave_speed: float = 180.0
@export var shockwave_max_radius: float = 320.0
@export var shockwave_thickness: float = 26.0
@export var shockwave_clear_height: float = 10.0
@export var shockwave_hit_margin: float = 8.0
@export var shockwave_perfect_dodge_range: float = 60.0
@export var shockwave_color: Color = Color(1.0, 0.4, 0.1, 0.9)
@export var shockwave_fill_color: Color = Color(1.0, 0.4, 0.1, 0.3)
@export var knockback_speed: float = 120.0
@export var knockback_decay: float = 900.0
@export var stun_tint: Color = Color(0.6, 0.85, 1.0)
@export var flash_time: float = 0.08
@export var death_fade_time: float = 0.25
@export var show_hitboxes: bool = true
@export var charge_hitbox_color: Color = Color(1.0, 0.55, 0.1, 0.9)
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
var charge_direction: Vector2 = Vector2.DOWN
var charge_current_speed: float = 0.0
var charge_crashed: bool = false
var charge_hit_done: bool = false
var charge_dodge_counted: bool = false
var shockwave_dodge_counted: bool = false
var resolving_attack: int = 0
var pending_knock_direction: Vector2 = Vector2.RIGHT
var ram_shape: CircleShape2D
var ram_hit_enemies: Array = []
var knockback_velocity: Vector2 = Vector2.ZERO
var stun_left: float = 0.0
var flash_left: float = 0.0
var flash_material: ShaderMaterial
var sprite_rest_position: Vector2 = Vector2.ZERO
var shockwave_active: bool = false
var shockwave_radius: float = 0.0
var shockwave_origin: Vector2 = Vector2.ZERO
var shockwave_hit_player: bool = false
var effects_drawn_last_frame: bool = false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	health = max_health
	add_to_group("enemy")

	ram_shape = CircleShape2D.new()
	ram_shape.radius = charge_hit_radius

	if sprite != null:
		sprite_rest_position = sprite.position
		flash_material = ShaderMaterial.new()
		var shader: Shader = Shader.new()
		shader.code = FLASH_SHADER_CODE
		flash_material.shader = shader
		sprite.material = flash_material
	else:
		push_warning("Charger is missing a child node named Sprite")

	if exclamation != null:
		exclamation.text = "!"
		exclamation.add_theme_color_override("font_color", exclamation_color)
		exclamation.visible = false

	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = health

	if number_template != null:
		number_template.visible = false

	if hurtbox == null:
		push_warning("Charger is missing a child node named CollisionShape2D")
	else:
		if hurtbox.shape == null:
			push_warning("Charger's CollisionShape2D has no shape assigned")
		hurtbox.z_index = 100
		hurtbox.draw.connect(draw_hurtbox)
		hurtbox.queue_redraw()


func _process(delta: float) -> void:
	flash_left = maxf(flash_left - delta, 0.0)
	if flash_material != null:
		flash_material.set_shader_parameter("flash_amount", 1.0 if flash_left > 0.0 else 0.0)

	if sprite != null:
		sprite.modulate = stun_tint if state == State.STUNNED else Color.WHITE
		var shake: Vector2 = Vector2.ZERO
		if state == State.TELEGRAPH and telegraph_shake > 0.0:
			shake = Vector2(randf_range(-telegraph_shake, telegraph_shake), randf_range(-telegraph_shake, telegraph_shake))
		sprite.position = sprite_rest_position + shake

	update_exclamation()


func _physics_process(delta: float) -> void:
	if dead:
		return

	state_time += delta
	find_player()
	sync_player_collision()
	update_shockwave(delta)

	var to_player: Vector2 = Vector2.ZERO
	var distance: float = INF
	if player != null:
		to_player = player.global_position - global_position
		distance = to_player.length()

	var move_velocity: Vector2 = Vector2.ZERO

	match state:
		State.IDLE:
			if distance <= detect_range:
				change_state(State.APPROACH)
		State.APPROACH:
			if distance > detect_range:
				change_state(State.IDLE)
			elif distance <= charge_trigger_distance:
				change_state(State.TELEGRAPH)
			else:
				var direction: Vector2 = to_player.normalized()
				move_velocity = direction * walk_speed
				facing_direction = direction
				update_sprite_facing(direction)
		State.TELEGRAPH:
			face_player()
			if state_time >= telegraph_time:
				change_state(State.CHARGE)
		State.CHARGE:
			move_velocity = update_charge(delta, to_player)
			if charge_crashed or state_time >= charge_duration:
				end_charge()
		State.RECOVER:
			var rest_time: float = recovery_time + (crash_extra_recovery if charge_crashed else 0.0)
			if state_time >= rest_time:
				change_state(State.APPROACH)
		State.STUNNED:
			stun_left = maxf(stun_left - delta, 0.0)
			if stun_left <= 0.0:
				change_state(State.APPROACH)

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	velocity = move_velocity + knockback_velocity
	move_and_slide()

	if state == State.CHARGE:
		check_charge_crash()

	var drawing: bool = shockwave_active or state == State.CHARGE
	if hurtbox != null and (drawing or effects_drawn_last_frame):
		hurtbox.queue_redraw()
	effects_drawn_last_frame = drawing


func change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	match new_state:
		State.TELEGRAPH:
			face_player()
		State.CHARGE:
			charge_direction = direction_to_player()
			if charge_direction == Vector2.ZERO:
				charge_direction = facing_direction
			charge_current_speed = 0.0
			charge_crashed = false
			charge_hit_done = false
			charge_dodge_counted = false
			ram_hit_enemies.clear()


func update_charge(delta: float, to_player: Vector2) -> Vector2:
	if player != null and to_player != Vector2.ZERO:
		var difference: float = charge_direction.angle_to(to_player)
		var max_turn: float = deg_to_rad(charge_turn_rate_degrees) * delta
		charge_direction = charge_direction.rotated(clampf(difference, -max_turn, max_turn))

	charge_current_speed = move_toward(charge_current_speed, charge_speed, charge_acceleration * delta)
	facing_direction = charge_direction
	update_sprite_facing(charge_direction)
	apply_charge_hit(to_player)
	apply_enemy_rams()
	return charge_direction * charge_current_speed


func knockback_direction_for(target_position: Vector2) -> Vector2:
	var to_target: Vector2 = target_position - global_position
	var side: float = 1.0 if charge_direction.cross(to_target) >= 0.0 else -1.0
	return charge_direction.rotated(deg_to_rad(ram_knockback_angle_degrees) * side)


func apply_enemy_rams() -> void:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = ram_shape
	query.transform = Transform2D(0.0, global_position + charge_hit_offset)
	query.collision_mask = ram_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var node: Node2D = result["collider"] as Node2D
		if node == null or node == self or ram_hit_enemies.has(node):
			continue
		if not node.is_in_group("enemy") or not node.has_method("take_damage"):
			continue
		if node.get("dead") == true:
			continue

		ram_hit_enemies.append(node)
		var direction: Vector2 = knockback_direction_for(node.global_position)
		node.take_damage(ram_enemy_damage, global_position)
		if "knockback_velocity" in node:
			node.set("knockback_velocity", direction * ram_knockback_speed)


func check_charge_perfect_dodge(to_player: Vector2) -> void:
	if charge_dodge_counted or not player.has_method("is_dash_invulnerable") or not player.is_dash_invulnerable():
		return
	if to_player == Vector2.ZERO or to_player.length() > perfect_dodge_distance:
		return
	if charge_direction.dot(to_player.normalized()) <= 0.0:
		return
	charge_dodge_counted = true
	if player.has_method("register_dodge"):
		player.register_dodge()


func apply_charge_hit(to_player: Vector2) -> void:
	if player == null or not player.has_method("take_damage"):
		return

	check_charge_perfect_dodge(to_player)

	if charge_hit_done:
		return

	var center: Vector2 = global_position + charge_hit_offset
	if center.distance_to(player.global_position) <= charge_hit_radius:
		charge_hit_done = true
		resolving_attack = 1
		pending_knock_direction = knockback_direction_for(player.global_position)
		player.take_damage(charge_damage, global_position, self)


func check_charge_crash() -> void:
	for index in range(get_slide_collision_count()):
		var node: Node = get_slide_collision(index).get_collider() as Node
		if node != null and not node.is_in_group("player") and not node.is_in_group("enemy"):
			charge_crashed = true
			return


func end_charge() -> void:
	start_shockwave()
	change_state(State.RECOVER)


func start_shockwave() -> void:
	shockwave_active = true
	shockwave_radius = 0.0
	shockwave_origin = global_position
	shockwave_hit_player = false
	shockwave_dodge_counted = false


func check_shockwave_perfect_dodge(distance: float, band_gap: float) -> void:
	if shockwave_dodge_counted or not player.has_method("is_dash_invulnerable") or not player.is_dash_invulnerable():
		return
	if distance < shockwave_radius - shockwave_thickness * 0.5 - shockwave_hit_margin:
		return
	if band_gap > shockwave_perfect_dodge_range:
		return
	shockwave_dodge_counted = true
	if player.has_method("register_dodge"):
		player.register_dodge()


func update_shockwave(delta: float) -> void:
	if not shockwave_active:
		return

	shockwave_radius += shockwave_speed * delta
	if shockwave_radius >= shockwave_max_radius:
		shockwave_active = false
		return

	if player == null or not player.has_method("take_damage"):
		return

	var distance: float = player.global_position.distance_to(shockwave_origin)
	var band_gap: float = absf(distance - shockwave_radius)

	check_shockwave_perfect_dodge(distance, band_gap)

	if shockwave_hit_player:
		return

	var height_value: Variant = player.get("height")
	if height_value != null and float(height_value) >= shockwave_clear_height:
		return

	if band_gap <= shockwave_thickness * 0.5 + shockwave_hit_margin:
		shockwave_hit_player = true
		resolving_attack = 2
		player.take_damage(shockwave_damage, shockwave_origin, self)


func has_counted_dodge() -> bool:
	if resolving_attack == 1:
		return charge_dodge_counted
	if resolving_attack == 2:
		return shockwave_dodge_counted
	return false


func on_hit_resolved(dealt: bool) -> void:
	if dealt:
		if resolving_attack == 1 and player != null and player.has_method("apply_knockback"):
			player.apply_knockback(pending_knock_direction, ram_knockback_speed)
		return
	if resolving_attack == 1:
		charge_dodge_counted = true
	elif resolving_attack == 2:
		shockwave_dodge_counted = true


func stun(duration: float) -> void:
	if dead:
		return
	stun_left = maxf(stun_left, duration)
	if state != State.STUNNED:
		change_state(State.STUNNED)


func find_player() -> void:
	if player != null and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as Node2D


func sync_player_collision() -> void:
	if player == null:
		return
	var height_value: Variant = player.get("height")
	var airborne: bool = height_value != null and float(height_value) > 0.0
	var phasing: bool = airborne or (player.has_method("is_phasing") and player.is_phasing())
	if phasing and not ignoring_player:
		add_collision_exception_with(player)
		ignoring_player = true
	elif not phasing and ignoring_player:
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
	if state == State.TELEGRAPH and not dead:
		exclamation.visible = int(state_time / maxf(exclamation_flash_interval, 0.001)) % 2 == 0
	else:
		exclamation.visible = false


func take_damage(amount: int, from_position: Vector2) -> void:
	if dead:
		return
	health = maxi(health - amount, 0)
	if print_hits:
		print("Charger hit for ", amount, ", health ", health, "/", max_health)
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
	shockwave_active = false
	velocity = Vector2.ZERO
	if hurtbox != null:
		hurtbox.set_deferred("disabled", true)
		hurtbox.queue_redraw()
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
	if hurtbox == null:
		return

	if show_hitboxes:
		var rectangle: RectangleShape2D = hurtbox.shape as RectangleShape2D
		if rectangle != null:
			hurtbox.draw_rect(Rect2(-rectangle.size * 0.5, rectangle.size), hurtbox_color, false, 1.0)
		var circle: CircleShape2D = hurtbox.shape as CircleShape2D
		if circle != null:
			hurtbox.draw_arc(Vector2.ZERO, circle.radius, 0.0, TAU, 32, hurtbox_color, 1.0)
		if state == State.CHARGE:
			hurtbox.draw_arc(hurtbox.to_local(global_position + charge_hit_offset), charge_hit_radius, 0.0, TAU, 32, charge_hitbox_color, 1.0)

	if shockwave_active:
		var center: Vector2 = hurtbox.to_local(shockwave_origin)
		var progress: float = clampf(shockwave_radius / maxf(shockwave_max_radius, 1.0), 0.0, 1.0)
		var fill: Color = shockwave_fill_color
		fill.a *= 1.0 - progress
		var edge: Color = shockwave_color
		edge.a *= 1.0 - progress
		hurtbox.draw_arc(center, shockwave_radius, 0.0, TAU, 96, fill, shockwave_thickness)
		hurtbox.draw_arc(center, shockwave_radius, 0.0, TAU, 96, edge, 2.0)
