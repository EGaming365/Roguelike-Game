extends Area2D

@export var speed: float = 320.0
@export var damage: int = 8
@export var lifetime: float = 3.0
@export var rotate_to_direction: bool = true
@export var destroy_on_world_hit: bool = true
@export var show_hitbox: bool = true
@export var hitbox_color: Color = Color(1.0, 0.55, 0.1, 0.9)

@onready var collider: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var age: float = 0.0
var awaiting_result: bool = false
var dodge_counted: bool = false


func _ready() -> void:
	if collider == null:
		push_warning("Projectile is missing a child node named CollisionShape2D")
	elif collider.shape == null:
		push_warning("Projectile's CollisionShape2D has no shape assigned")
	else:
		collider.z_index = 100
		collider.draw.connect(draw_hitbox)
		collider.queue_redraw()


func launch(new_direction: Vector2, new_speed: float, new_damage: int) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage
	if rotate_to_direction:
		rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if awaiting_result:
		return

	global_position += direction * speed * delta
	age += delta
	if age >= lifetime:
		queue_free()
		return

	check_overlaps()


func check_overlaps() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			try_hit(body)
			if awaiting_result:
				return
		elif body.is_in_group("enemy") or body.has_method("take_damage"):
			continue
		elif destroy_on_world_hit:
			queue_free()
			return


func try_hit(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	if body.has_method("is_dash_invulnerable") and body.is_dash_invulnerable():
		if not dodge_counted:
			dodge_counted = true
			if body.has_method("register_dodge"):
				body.register_dodge()
		return
	awaiting_result = true
	body.take_damage(damage, global_position, self)


func on_hit_resolved(dealt: bool) -> void:
	awaiting_result = false
	if dealt:
		queue_free()
	else:
		dodge_counted = true


func draw_hitbox() -> void:
	if not show_hitbox or collider == null:
		return
	var rectangle: RectangleShape2D = collider.shape as RectangleShape2D
	if rectangle != null:
		collider.draw_rect(Rect2(-rectangle.size * 0.5, rectangle.size), hitbox_color, false, 1.0)
		return
	var circle: CircleShape2D = collider.shape as CircleShape2D
	if circle != null:
		collider.draw_arc(Vector2.ZERO, circle.radius, 0.0, TAU, 32, hitbox_color, 1.0)
