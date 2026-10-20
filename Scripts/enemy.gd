extends CharacterBody2D

enum State { IDLE, CHASE, WINDUP_ONE, SWING_ONE, PAUSE, WINDUP_TWO, DASH, DASH_TAIL, RECOVER, STUNNED }

const FLASH_SHADER_CODE: String = "shader_type canvas_item;\nuniform float flash_amount : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tCOLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash_amount);\n}\n"

@export var max_health: int = 10
@export var detect_range: float = 600.0
@export var attack_trigger_distance: float = 140.0
@export var move_speed: float = 100.0
@export var sprite_faces_right: bool = true
@export var windup_time: float = 0.5
@export var exclamation_flash_interval: float = 0.07
@export var exclamation_color: Color = Color(1.0, 0.1, 0.1)
@export var swing_active_time: float = 0.1
@export var swing_range: float = 120.0
@export var swing_width: float = 40.0
@export var swing_arc_degrees: float = 120.0
@export var swing_start_distance: float = 40.0
@export var swing_damage: float = 0.5
@export var swing_origin_offset: Vector2 = Vector2(0.0, -8.0)
@export var after_swing_delay: float = 0.55
@export var second_windup_time: float = 0.4
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.14
@export var dash_line_length: float = 150.0
@export var dash_line_width: float = 30.0
@export var dash_line_start_distance: float = 20.0
@export var dash_line_linger: float = 0.05
@export var dash_damage: float = 0.5
@export var recovery_time: float = 2.0
@export var knockback_speed: float = 160.0
@export var knockback_decay: float = 900.0
@export var stun_tint: Color = Color(0.6, 0.85, 1.0)
@export var flash_time: float = 0.08
@export var death_fade_time: float = 0.25
@export_flags_2d_physics var attack_collision_mask: int = 1
@export var show_hitboxes: bool = true
@export var hitbox_linger: float = 0.1
@export var swing_hitbox_color: Color = Color(1.0, 0.55, 0.1, 0.9)
@export var swing_hitbox_fill: Color = Color(1.0, 0.55, 0.1, 0.25)
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
var dash_direction: Vector2 = Vector2.DOWN
var knockback_velocity: Vector2 = Vector2.ZERO
var stun_left: float = 0.0
var flash_left: float = 0.0
var flash_material: ShaderMaterial
var swing_pivot: Node2D
var swing_shape: RectangleShape2D
var swing_aim_angle: float = 0.0
var swing_hit_targets: Array[Object] = []
var hitbox_visible_left: float = 0.0
var hit_start: float = 0.0
var hit_length: float = 0.0
var hit_width: float = 0.0
var hit_damage: float = 0


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
		push_warning("Enemy is missing a child node named Sprite")

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
		push_warning("Enemy is missing a child node named CollisionShape2D")
	elif hurtbox.shape == null:
		push_warning("Enemy's CollisionShape2D has no shape assigned")
	else:
		hurtbox.z_index = 100
		hurtbox.draw.connect(draw_hurtbox)
		hurtbox.queue_redraw()

	build_swing_pivot()


func build_swing_pivot() -> void:
	swing_pivot = Node2D.new()
	swing_pivot.position = swing_origin_offset
	swing_pivot.z_index = 100
	swing_shape = RectangleShape2D.new()
	set_hit_shape(swing_start_distance, swing_range, swing_width, swing_damage)
	swing_pivot.draw.connect(draw_swing_hitbox)
	add_child(swing_pivot)


func set_hit_shape(start: float, length: float, width: float, damage: float) -> void:
	hit_start = start
	hit_length = length
	hit_width = width
	hit_damage = damage
	swing_shape.size = Vector2(length, width)


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
				change_state(State.CHASE)
		State.CHASE:
			if distance > detect_range:
				change_state(State.IDLE)
			elif distance <= attack_trigger_distance:
				change_state(State.WINDUP_ONE)
			else:
				var direction: Vector2 = to_player.normalized()
				move_velocity = direction * move_speed
				facing_direction = direction
				update_sprite_facing(direction)
		State.WINDUP_ONE:
			face_player()
			if state_time >= windup_time:
				change_state(State.SWING_ONE)
		State.SWING_ONE:
			if state_time >= swing_active_time:
				change_state(State.PAUSE)
		State.PAUSE:
			if state_time >= after_swing_delay:
				change_state(State.WINDUP_TWO)
		State.WINDUP_TWO:
			face_player()
			if state_time >= second_windup_time:
				change_state(State.DASH)
		State.DASH:
			move_velocity = dash_direction * dash_speed
			if state_time >= dash_duration:
				change_state(State.DASH_TAIL)
		State.DASH_TAIL:
			if state_time >= dash_line_linger:
				change_state(State.RECOVER)
		State.RECOVER:
			if state_time >= recovery_time:
				change_state(State.CHASE)
		State.STUNNED:
			stun_left = maxf(stun_left - delta, 0.0)
			if stun_left <= 0.0:
				change_state(State.CHASE)

	update_swing(delta)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	velocity = move_velocity + knockback_velocity
	move_and_slide()


func change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	match new_state:
		State.WINDUP_ONE, State.WINDUP_TWO:
			face_player()
		State.SWING_ONE:
			start_swing()
		State.DASH:
			dash_direction = direction_to_player()
			if dash_direction == Vector2.ZERO:
				dash_direction = facing_direction
			start_dash_line()


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
	var winding_up: bool = state == State.WINDUP_ONE or state == State.WINDUP_TWO
	if winding_up and not dead:
		exclamation.visible = int(state_time / maxf(exclamation_flash_interval, 0.001)) % 2 == 0
	else:
		exclamation.visible = false


func start_swing() -> void:
	var direction: Vector2 = direction_to_player()
	if direction == Vector2.ZERO:
		direction = facing_direction
	facing_direction = direction
	update_sprite_facing(direction)
	swing_aim_angle = direction.angle()
	set_hit_shape(swing_start_distance, swing_range, swing_width, swing_damage)
	swing_hit_targets.clear()
	hitbox_visible_left = swing_active_time + hitbox_linger


func start_dash_line() -> void:
	facing_direction = dash_direction
	update_sprite_facing(dash_direction)
	set_hit_shape(dash_line_start_distance, dash_line_length, dash_line_width, dash_damage)
	swing_hit_targets.clear()
	hitbox_visible_left = hitbox_linger


func update_swing(delta: float) -> void:
	if state == State.SWING_ONE:
		var progress: float = clampf(state_time / maxf(swing_active_time, 0.001), 0.0, 1.0)
		var sweep: float = lerpf(-swing_arc_degrees * 0.5, swing_arc_degrees * 0.5, progress)
		swing_pivot.position = swing_origin_offset
		swing_pivot.rotation = swing_aim_angle + deg_to_rad(sweep)
		apply_hits()
	elif state == State.DASH or state == State.DASH_TAIL:
		swing_pivot.position = swing_origin_offset
		swing_pivot.rotation = dash_direction.angle()
		hitbox_visible_left = hitbox_linger
		apply_hits()

	if hitbox_visible_left > 0.0:
		hitbox_visible_left = maxf(hitbox_visible_left - delta, 0.0)
		swing_pivot.queue_redraw()


func apply_hits() -> void:
	for result in query_swing_targets():
		apply_swing_hit(result["collider"])


func query_swing_targets() -> Array[Dictionary]:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = swing_shape
	query.transform = swing_pivot.global_transform.translated_local(Vector2(hit_start + hit_length * 0.5, 0.0))
	query.collision_mask = attack_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 16)


func apply_swing_hit(target: Object) -> void:
	var node: Node = target as Node
	if node == null or node == self or swing_hit_targets.has(node):
		return
	if not node.is_in_group("player") or not node.has_method("take_damage"):
		return
	swing_hit_targets.append(node)
	node.take_damage(hit_damage, global_position)


func take_damage(amount: int, from_position: Vector2) -> void:
	if dead:
		return
	health = maxi(health - amount, 0)
	if print_hits:
		print("Enemy hit for ", amount, ", health ", health, "/", max_health)
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


func draw_swing_hitbox() -> void:
	if not show_hitboxes or hitbox_visible_left <= 0.0:
		return
	var rect: Rect2 = Rect2(Vector2(hit_start, -hit_width * 0.5), Vector2(hit_length, hit_width))
	swing_pivot.draw_rect(rect, swing_hitbox_fill, true)
	swing_pivot.draw_rect(rect, swing_hitbox_color, false, 1.0)


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
