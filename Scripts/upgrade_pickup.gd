extends Area2D

@export_enum("kinetic_ram", "arc_conduit", "tesla_tower", "overclocked_servos") var upgrade_id: String = "kinetic_ram"
@export var print_pickups: bool = false
@export var show_hitbox: bool = true
@export var hitbox_color: Color = Color(0.3, 0.8, 1.0, 0.9)

@onready var collider: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	body_entered.connect(on_body_entered)

	if collider == null:
		push_warning("Upgrade pickup is missing a child node named CollisionShape2D")
	elif collider.shape == null:
		push_warning("Upgrade pickup's CollisionShape2D has no shape assigned")
	else:
		collider.z_index = 100
		collider.draw.connect(draw_hitbox)
		collider.queue_redraw()


func on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("add_upgrade"):
		return
	body.add_upgrade(upgrade_id)
	if print_pickups:
		print("Picked up ", upgrade_id)
	queue_free()


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
