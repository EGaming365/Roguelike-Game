extends StaticBody2D

@export var lifetime: float = 12.0
@export var max_triggers: int = 1
@export var shockwave_damage: int = 50
@export var shockwave_radius: float = 500.0
@export var stun_duration: float = 2.0
@export var shockwave_duration: float = 0.8
@export var shockwave_on_expire: bool = false
@export var placed_in_scene: bool = false
@export var fade_time: float = 0.3
@export_flags_2d_physics var target_collision_mask: int = 1
@export var show_hitbox: bool = true
@export var hitbox_color: Color = Color(0.2, 1.0, 0.3, 0.9)
@export var shockwave_color: Color = Color(1.0, 0.95, 0.25, 0.9)
@export var shockwave_hitbox_color: Color = Color(1.0, 0.95, 0.25, 0.3)
@export var shockwave_ring_width: float = 3.0
@export var print_triggers: bool = false

@onready var hurtbox: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var dead: bool = true
var flying: bool = false
var spent: bool = false
var flight_start: Vector2 = Vector2.ZERO
var flight_target: Vector2 = Vector2.ZERO
var flight_time: float = 0.5
var flight_arc_height: float = 0.0
var flight_elapsed: float = 0.0
var lifetime_left: float = 0.0
var triggers_left: int = 0
var shockwave_left: float = 0.0
var shockwave_shape: CircleShape2D


func _ready() -> void:
	shockwave_shape = CircleShape2D.new()
	shockwave_shape.radius = shockwave_radius

	if hurtbox == null:
		push_warning("Tesla Tower is missing a child node named CollisionShape2D")
	elif hurtbox.shape == null:
		push_warning("Tesla Tower's CollisionShape2D has no shape assigned")
	else:
		hurtbox.z_index = 100
		hurtbox.draw.connect(draw_hitbox)
		hurtbox.queue_redraw()

	if placed_in_scene:
		land()
	elif hurtbox != null:
		hurtbox.set_deferred("disabled", true)


func launch(start_position: Vector2, target_position: Vector2, time: float, arc_height: float) -> void:
	flight_start = start_position
	flight_target = target_position
	flight_time = maxf(time, 0.05)
	flight_arc_height = arc_height
	flight_elapsed = 0.0
	flying = true
	dead = true
	global_position = start_position
	if hurtbox != null:
		hurtbox.set_deferred("disabled", true)


func land() -> void:
	flying = false
	dead = false
	lifetime_left = lifetime
	triggers_left = max_triggers
	if hurtbox != null:
		hurtbox.set_deferred("disabled", false)
		hurtbox.queue_redraw()


func _physics_process(delta: float) -> void:
	if flying:
		update_flight(delta)
		return

	if shockwave_left > 0.0:
		shockwave_left = maxf(shockwave_left - delta, 0.0)
		if hurtbox != null:
			hurtbox.queue_redraw()

	if spent or dead:
		return

	lifetime_left -= delta
	if lifetime_left <= 0.0:
		expire()


func update_flight(delta: float) -> void:
	flight_elapsed += delta
	var t: float = clampf(flight_elapsed / flight_time, 0.0, 1.0)
	global_position = flight_start.lerp(flight_target, t) + Vector2(0.0, -flight_arc_height * 4.0 * t * (1.0 - t))
	if t >= 1.0:
		global_position = flight_target
		land()


func on_chain_lightning(_damage: int, _from_position: Vector2) -> void:
	if dead or flying or spent:
		return
	trigger_shockwave()


func trigger_shockwave() -> void:
	triggers_left -= 1
	shockwave_left = shockwave_duration
	if print_triggers:
		print("Tesla Tower shockwave")

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shockwave_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = target_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var already_hit: Array[Node] = []
	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var node: Node2D = result["collider"] as Node2D
		if node == null or node == self or already_hit.has(node):
			continue
		if node.is_in_group("player") or not node.has_method("take_damage"):
			continue
		if node.get("dead") == true:
			continue
		already_hit.append(node)
		node.take_damage(shockwave_damage, global_position)
		if node.has_method("stun"):
			node.stun(stun_duration)

	if triggers_left <= 0:
		begin_fade(shockwave_duration)


func expire() -> void:
	if shockwave_on_expire:
		triggers_left = 1
		trigger_shockwave()
	else:
		begin_fade(0.0)


func begin_fade(delay: float) -> void:
	spent = true
	dead = true
	if hurtbox != null:
		hurtbox.set_deferred("disabled", true)
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)


func draw_hitbox() -> void:
	if hurtbox == null:
		return

	var center: Vector2 = hurtbox.to_local(global_position)

	if show_hitbox and not flying:
		var rectangle: RectangleShape2D = hurtbox.shape as RectangleShape2D
		if rectangle != null:
			hurtbox.draw_rect(Rect2(-rectangle.size * 0.5, rectangle.size), hitbox_color, false, 1.0)
		var circle: CircleShape2D = hurtbox.shape as CircleShape2D
		if circle != null:
			hurtbox.draw_arc(Vector2.ZERO, circle.radius, 0.0, TAU, 32, hitbox_color, 1.0)

	if shockwave_left > 0.0:
		var progress: float = 1.0 - shockwave_left / maxf(shockwave_duration, 0.001)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		var ring: Color = shockwave_color
		ring.a *= 1.0 - progress
		hurtbox.draw_arc(center, shockwave_radius * eased, 0.0, TAU, 64, ring, shockwave_ring_width)
		if show_hitbox:
			hurtbox.draw_arc(center, shockwave_radius, 0.0, TAU, 64, shockwave_hitbox_color, 1.0)
