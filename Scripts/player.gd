extends CharacterBody2D

@export var max_speed: float = 190.0
@export var acceleration: float = 2600.0
@export var friction: float = 3600.0
@export var turn_boost: float = 1.6
@export var air_control: float = 0.85
@export var air_friction: float = 250.0
@export var jump_velocity: float = 180.0
@export var jump_forward_speed: float = 240.0
@export var jump_when_idle_uses_facing: bool = false
@export var hold_to_rejump: bool = true
@export var gravity: float = 450.0
@export var jump_through_enabled: bool = true
@export var jump_through_damageable: bool = true
@export var jump_through_objects: bool = true
@export var jump_through_group: StringName = &"jump_through"
@export var jump_z_boost: int = 10
@export_range(0.0, 1.0, 0.01) var landing_push_start: float = 0.5
@export var landing_push_speed: float = 420.0
@export var landing_clear_margin: float = 2.0
@export var landing_push_timeout: float = 1.0
@export var print_jump_debug: bool = false
@export var shadow_min_scale: float = 0.5
@export var shadow_min_alpha: float = 0.4
@export var shadow_fade_height: float = 25.0
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var move_up_action: StringName = &"move_up"
@export var move_down_action: StringName = &"move_down"
@export var jump_action: StringName = &"ui_accept"
@export var dash_action: StringName = &"dash"
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.1
@export var dash_end_speed_ratio: float = 0.4
@export var dash_invulnerable: bool = true
@export var dodge_window: float = 0.05
@export var knockback_decay: float = 900.0
@export var max_health: int = 100
@export var hurt_flash_time: float = 0.12
@export var hurt_flash_color: Color = Color(1.0, 0.25, 0.25)
@export var print_hurt_debug: bool = false
@export var hit_stop_time: float = 0.04
@export var hit_stop_time_scale: float = 0.03
@export var ui_blocker_group: StringName = &"ui_blocker"
@export var attack_action: StringName = &"attack"
@export var attack_hold_to_repeat: bool = true
@export var attack_buffer_time: float = 0.2
@export var attack_damage_min: int = 8
@export var attack_damage_max: int = 14
@export var attack_cooldown: float = 0.16
@export var attack_active_time: float = 0.1
@export var attack_range: float = 400.0
@export var attack_width: float = 80.0
@export var attack_start_distance: float = 8.0
@export var attack_arc_degrees: float = 140.0
@export var combo_window: float = 0.5
@export var finisher_windup_delay: float = 0.4
@export var finisher_recovery: float = 0.45
@export var finisher_active_time: float = 0.12
@export var finisher_range: float = 450.0
@export var finisher_width: float = 200.0
@export var finisher_arc_degrees: float = 0.0
@export var finisher_thrust_distance: float = 120.0
@export var finisher_damage_multiplier: float = 2.0
@export var attack_origin_offset: Vector2 = Vector2(0.0, -8.0)
@export_flags_2d_physics var attack_collision_mask: int = 1
@export var show_hitboxes: bool = true
@export var hitbox_linger: float = 0.12
@export var print_attack_debug: bool = false
@export var attack_hitbox_color: Color = Color(1.0, 0.2, 0.2, 0.9)
@export var attack_hitbox_fill: Color = Color(1.0, 0.2, 0.2, 0.25)

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var upgrades: Node = get_node_or_null("Upgrades")

var height: float = 0.0
var height_velocity: float = 0.0
var air_time: float = 0.0
var sprite_base_y: float = 0.0
var shadow_base_scale: Vector2 = Vector2.ONE
var base_z_index: int = 0
var jump_ignored_bodies: Array = []
var body_collider: CollisionShape2D
var separation_time: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var health: int = 0
var hurt_flash_left: float = 0.0
var hit_stop_active: bool = false
var pending_hits: Array[Dictionary] = []
var dash_grace_left: float = 0.0
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN
var facing: Vector2 = Vector2.DOWN
var attack_pivot: Node2D
var attack_shape: RectangleShape2D
var attack_time_left: float = 0.0
var attack_cooldown_left: float = 0.0
var attack_buffer_left: float = 0.0
var attack_aim_angle: float = 0.0
var attack_swing_sign: float = 1.0
var attack_hit_targets: Array[Object] = []
var hitbox_visible_left: float = 0.0
var combo_step: int = 0
var combo_reset_left: float = 0.0
var attack_current_range: float = 0.0
var attack_current_width: float = 0.0
var attack_current_arc: float = 0.0
var attack_current_thrust: float = 0.0
var attack_current_duration: float = 0.1
var attack_current_damage_multiplier: float = 1.0
var attack_thrust_offset: float = 0.0


func _ready() -> void:
	sprite_base_y = sprite.position.y
	shadow_base_scale = shadow.scale
	base_z_index = z_index
	health = max_health
	attack_current_range = attack_range
	attack_current_width = attack_width
	add_to_group("player")

	for child in get_children():
		if child is CollisionShape2D:
			body_collider = child as CollisionShape2D
			break

	build_attack_pivot()


func build_attack_pivot() -> void:
	attack_pivot = Node2D.new()
	attack_pivot.position = attack_origin_offset
	attack_pivot.z_index = 100
	attack_shape = RectangleShape2D.new()
	attack_shape.size = Vector2(attack_range, attack_width)
	attack_pivot.draw.connect(draw_attack_hitbox)
	add_child(attack_pivot)


func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector(move_left_action, move_right_action, move_up_action, move_down_action)

	if input_vector != Vector2.ZERO:
		facing = input_vector.normalized()
		if absf(input_vector.x) > 0.01:
			sprite.flip_h = input_vector.x < 0.0

	hurt_flash_left = maxf(hurt_flash_left - delta, 0.0)
	dash_grace_left = maxf(dash_grace_left - delta, 0.0)

	attack_buffer_left = maxf(attack_buffer_left - delta, 0.0)
	if Input.is_action_just_pressed(attack_action) and not is_pointer_over_ui():
		attack_buffer_left = attack_buffer_time

	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)

	if attack_cooldown_left <= 0.0 and attack_time_left <= 0.0 and wants_attack():
		start_attack()

	update_attack(delta)

	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)

	if dash_time_left <= 0.0 and dash_cooldown_left <= 0.0 and Input.is_action_just_pressed(dash_action):
		start_dash(input_vector)

	update_pending_hits(delta)

	var dashing: bool = dash_time_left > 0.0

	if is_grounded() and wants_jump():
		start_jump(input_vector, dashing)

	if is_grounded():
		update_grounded_separation(delta)

	if dashing:
		dash_time_left -= delta
		velocity = dash_direction * dash_speed
		if dash_time_left <= 0.0:
			velocity = dash_direction * max_speed * dash_end_speed_ratio
			dash_grace_left = dodge_window
	else:
		apply_movement(input_vector, delta)

	update_height(delta)
	move_and_slide()
	apply_separation_push(delta)
	apply_knockback_motion(delta)
	update_visuals()


func is_grounded() -> bool:
	return height <= 0.0 and height_velocity <= 0.0


func is_phasing() -> bool:
	return not is_grounded() or not jump_ignored_bodies.is_empty()


func get_jump_progress() -> float:
	if is_grounded():
		return 1.0
	var total_time: float = 2.0 * jump_velocity / maxf(gravity, 0.001)
	return clampf(air_time / maxf(total_time, 0.001), 0.0, 1.0)


func wants_jump() -> bool:
	if hold_to_rejump:
		return Input.is_action_pressed(jump_action)
	return Input.is_action_just_pressed(jump_action)


func wants_attack() -> bool:
	if attack_hold_to_repeat and Input.is_action_pressed(attack_action) and not is_pointer_over_ui():
		return true
	return attack_buffer_left > 0.0


func is_pointer_over_ui() -> bool:
	for node in get_tree().get_nodes_in_group(ui_blocker_group):
		if node.has_method("is_mouse_over") and node.is_mouse_over():
			return true
	return false


func apply_knockback(direction: Vector2, speed: float) -> void:
	if direction == Vector2.ZERO:
		return
	knockback_velocity = direction.normalized() * speed


func apply_knockback_motion(delta: float) -> void:
	if knockback_velocity == Vector2.ZERO:
		return
	move_and_collide(knockback_velocity * delta)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)


func add_upgrade(upgrade_id: String) -> void:
	if upgrades == null:
		push_warning("Player has no child node named Upgrades, so the upgrade was not applied")
		return
	upgrades.call("add_upgrade", upgrade_id)


func get_upgrade_stacks(upgrade_id: String) -> int:
	if upgrades == null:
		return 0
	return int(upgrades.call("get_stacks", upgrade_id))


func get_attack_speed() -> float:
	if upgrades == null:
		return 1.0
	return maxf(float(upgrades.call("get_attack_speed_multiplier")), 0.1)


func register_dodge() -> void:
	if upgrades != null:
		upgrades.call("on_dodge")


func is_dash_invulnerable() -> bool:
	return dash_invulnerable and (dash_time_left > 0.0 or dash_grace_left > 0.0)


func dodge_already_counted(source) -> bool:
	return is_instance_valid(source) and source.has_method("has_counted_dodge") and source.has_counted_dodge()


func take_damage(amount: int, _from_position: Vector2, source: Object = null) -> void:
	if is_dash_invulnerable():
		if print_hurt_debug:
			print("Player dodged a hit with dash i-frames")
		var already_counted: bool = dodge_already_counted(source)
		notify_hit_source(source, false)
		if not already_counted:
			register_dodge()
		return
	if not dash_invulnerable or dodge_window <= 0.0:
		apply_damage(amount)
		notify_hit_source(source, true)
		return
	pending_hits.append({"amount": amount, "time_left": dodge_window, "source": source})


func update_pending_hits(delta: float) -> void:
	if pending_hits.is_empty():
		return
	for index in range(pending_hits.size() - 1, -1, -1):
		pending_hits[index]["time_left"] -= delta
		if pending_hits[index]["time_left"] <= 0.0:
			var amount: int = pending_hits[index]["amount"]
			var source = pending_hits[index]["source"]
			pending_hits.remove_at(index)
			apply_damage(amount)
			notify_hit_source(source, true)


func notify_hit_source(source, dealt: bool) -> void:
	if is_instance_valid(source) and source.has_method("on_hit_resolved"):
		source.on_hit_resolved(dealt)


func apply_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	hurt_flash_left = hurt_flash_time
	if upgrades != null:
		upgrades.call("on_player_damaged")
	if print_hurt_debug:
		print("Player hit for ", amount, ", health ", health, "/", max_health)
	if health <= 0:
		health = max_health


func hit_stop() -> void:
	if hit_stop_time <= 0.0 or hit_stop_active:
		return
	hit_stop_active = true
	Engine.time_scale = hit_stop_time_scale
	await get_tree().create_timer(hit_stop_time, true, false, true).timeout
	Engine.time_scale = 1.0
	hit_stop_active = false


func start_attack() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - (global_position + attack_origin_offset)
	attack_aim_angle = to_mouse.angle() if to_mouse != Vector2.ZERO else facing.angle()
	if absf(to_mouse.x) > 0.01:
		sprite.flip_h = to_mouse.x < 0.0

	var attack_speed: float = get_attack_speed()
	var is_finisher: bool = combo_step >= 2
	var follow_up_delay: float = attack_cooldown
	if combo_step == 1:
		follow_up_delay = finisher_windup_delay
	elif is_finisher:
		follow_up_delay = finisher_recovery
	follow_up_delay /= attack_speed

	attack_current_range = finisher_range if is_finisher else attack_range
	attack_current_width = finisher_width if is_finisher else attack_width
	attack_current_arc = finisher_arc_degrees if is_finisher else attack_arc_degrees
	attack_current_thrust = finisher_thrust_distance if is_finisher else 0.0
	attack_current_damage_multiplier = finisher_damage_multiplier if is_finisher else 1.0
	attack_current_duration = maxf((finisher_active_time if is_finisher else attack_active_time) / attack_speed, 0.001)
	attack_swing_sign = -1.0 if combo_step == 1 else 1.0
	attack_shape.size = Vector2(attack_current_range, attack_current_width)
	attack_thrust_offset = 0.0

	attack_time_left = attack_current_duration
	attack_cooldown_left = follow_up_delay
	combo_reset_left = follow_up_delay + combo_window
	attack_buffer_left = 0.0
	hitbox_visible_left = attack_time_left + hitbox_linger
	attack_hit_targets.clear()

	if print_attack_debug:
		print("Swing started | combo step ", combo_step + 1, " | speed x", attack_speed, " | mask ", attack_collision_mask)

	combo_step = (combo_step + 1) % 3


func update_attack(delta: float) -> void:
	if combo_reset_left > 0.0:
		combo_reset_left = maxf(combo_reset_left - delta, 0.0)
		if combo_reset_left <= 0.0 and attack_time_left <= 0.0:
			combo_step = 0

	if attack_time_left > 0.0:
		attack_time_left = maxf(attack_time_left - delta, 0.0)
		var progress: float = 1.0 - attack_time_left / attack_current_duration
		var sweep: float = lerpf(-attack_current_arc * 0.5, attack_current_arc * 0.5, progress)
		attack_thrust_offset = attack_current_thrust * progress
		attack_pivot.position = attack_origin_offset
		attack_pivot.rotation = attack_aim_angle + deg_to_rad(sweep) * attack_swing_sign
		for result in query_attack_targets():
			apply_hit(result["collider"])

	if hitbox_visible_left > 0.0:
		hitbox_visible_left = maxf(hitbox_visible_left - delta, 0.0)
		attack_pivot.queue_redraw()


func query_attack_targets() -> Array[Dictionary]:
	var query:PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = attack_pivot.global_transform.translated_local(Vector2(attack_start_distance + attack_thrust_offset + attack_current_range * 0.5, 0.0))
	query.collision_mask = attack_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 16)


func apply_hit(target: Object) -> void:
	if target == null or target == self or attack_hit_targets.has(target):
		return
	attack_hit_targets.append(target)
	var can_damage: bool = target.has_method("take_damage")
	if print_attack_debug:
		print("Swing touched ", target, " | can take damage: ", can_damage)
	if can_damage:
		var damage: int = int(round(randi_range(attack_damage_min, attack_damage_max) * attack_current_damage_multiplier))
		target.take_damage(damage, global_position)
		hit_stop()
		if upgrades != null:
			upgrades.call("on_player_hit", target, global_position)


func draw_attack_hitbox() -> void:
	if not show_hitboxes or hitbox_visible_left <= 0.0:
		return
	var rect: Rect2 = Rect2(Vector2(attack_start_distance + attack_thrust_offset, -attack_current_width * 0.5), Vector2(attack_current_range, attack_current_width))
	attack_pivot.draw_rect(rect, attack_hitbox_fill, true)
	attack_pivot.draw_rect(rect, attack_hitbox_color, false, 1.0)


func start_dash(input_vector: Vector2) -> void:
	dash_direction = input_vector.normalized() if input_vector != Vector2.ZERO else facing
	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown + dash_duration
	if upgrades != null:
		upgrades.call("on_dash_started")
	if not pending_hits.is_empty():
		for hit in pending_hits:
			var already_counted: bool = dodge_already_counted(hit["source"])
			notify_hit_source(hit["source"], false)
			if not already_counted:
				register_dodge()
		pending_hits.clear()
		if print_hurt_debug:
			print("Player dashed inside the dodge window and avoided the hit")


func start_jump(input_vector: Vector2, dashing: bool) -> void:
	height_velocity = jump_velocity
	air_time = 0.0
	enter_jump_state()
	if dashing:
		return
	var jump_direction: Vector2 = Vector2.ZERO
	if input_vector != Vector2.ZERO:
		jump_direction = input_vector.normalized()
	elif jump_when_idle_uses_facing:
		jump_direction = facing
	if jump_direction != Vector2.ZERO:
		velocity = jump_direction * jump_forward_speed


func should_jump_through(node: Node) -> bool:
	if jump_through_damageable and node.has_method("take_damage"):
		return true
	if jump_through_objects and (node.has_method("on_chain_lightning") or node.has_node("InteractZone")):
		return true
	return false


func collect_jump_through_bodies() -> Array[Node]:
	var found: Array[Node] = []

	for node in get_tree().get_nodes_in_group(jump_through_group):
		if node is PhysicsBody2D and node != self and not found.has(node):
			found.append(node)

	var scene_root: Node = get_tree().current_scene
	if scene_root != null and (jump_through_damageable or jump_through_objects):
		for node in scene_root.find_children("*", "PhysicsBody2D", true, false):
			if node != self and not found.has(node) and should_jump_through(node):
				found.append(node)

	return found


func enter_jump_state() -> void:
	z_index = base_z_index + jump_z_boost
	if not jump_through_enabled:
		return
	prune_ignored_bodies()
	for body in collect_jump_through_bodies():
		if jump_ignored_bodies.has(body):
			continue
		add_collision_exception_with(body)
		jump_ignored_bodies.append(body)
	if print_jump_debug:
		print("Jump ignoring ", jump_ignored_bodies.size(), " bodies: ", jump_ignored_bodies)


func prune_ignored_bodies() -> void:
	var valid_bodies: Array = []
	for index in range(jump_ignored_bodies.size()):
		var body = jump_ignored_bodies[index]
		if is_instance_valid(body):
			valid_bodies.append(body)
	jump_ignored_bodies = valid_bodies


func get_overlapping_ignored_bodies() -> Array[Node]:
	var result: Array[Node] = []
	if body_collider == null or body_collider.shape == null or jump_ignored_bodies.is_empty():
		return result

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = body_collider.shape
	query.transform = body_collider.global_transform
	query.margin = landing_clear_margin
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var collider: Node = hit["collider"] as Node
		if collider != null and jump_ignored_bodies.has(collider) and not result.has(collider):
			result.append(collider)

	return result


func update_grounded_separation(delta: float) -> void:
	z_index = base_z_index
	prune_ignored_bodies()

	if jump_ignored_bodies.is_empty():
		separation_time = 0.0
		return

	var overlapping: Array[Node] = get_overlapping_ignored_bodies()
	var timed_out: bool = separation_time >= landing_push_timeout
	var kept: Array = []

	for body in jump_ignored_bodies:
		if overlapping.has(body) and not timed_out:
			kept.append(body)
		else:
			remove_collision_exception_with(body)

	jump_ignored_bodies = kept

	if overlapping.is_empty():
		separation_time = 0.0
	else:
		separation_time += delta


func apply_separation_push(delta: float) -> void:
	if body_collider == null:
		return
	prune_ignored_bodies()
	if jump_ignored_bodies.is_empty():
		return
	if not is_grounded() and get_jump_progress() < landing_push_start:
		return

	var overlapping: Array[Node] = get_overlapping_ignored_bodies()
	if overlapping.is_empty():
		return

	var push: Vector2 = Vector2.ZERO
	for body in overlapping:
		var body_node: Node2D = body as Node2D
		if body_node == null:
			continue
		var away: Vector2 = global_position - body_node.global_position
		if away != Vector2.ZERO:
			push += away.normalized()

	if push == Vector2.ZERO:
		push = -facing

	move_and_collide(push.normalized() * landing_push_speed * delta)


func apply_movement(input_vector: Vector2, delta: float) -> void:
	var grounded: bool = is_grounded()

	if input_vector != Vector2.ZERO:
		var accel: float = acceleration if grounded else acceleration * air_control
		if velocity != Vector2.ZERO and velocity.normalized().dot(input_vector.normalized()) < 0.5:
			accel *= turn_boost
		velocity = velocity.move_toward(input_vector * max_speed, accel * delta)
	else:
		var drag: float = friction if grounded else air_friction
		velocity = velocity.move_toward(Vector2.ZERO, drag * delta)


func update_height(delta: float) -> void:
	if height > 0.0 or height_velocity > 0.0:
		air_time += delta
		height_velocity -= gravity * delta
		height += height_velocity * delta
		if height <= 0.0:
			height = 0.0
			height_velocity = 0.0
			air_time = 0.0


func update_visuals() -> void:
	sprite.position.y = sprite_base_y - height
	sprite.modulate = hurt_flash_color if hurt_flash_left > 0.0 else Color.WHITE
	var t: float = clampf(height / shadow_fade_height, 0.0, 1.0)
	shadow.scale = shadow_base_scale * lerpf(1.0, shadow_min_scale, t)
	shadow.modulate.a = lerpf(1.0, shadow_min_alpha, t)
