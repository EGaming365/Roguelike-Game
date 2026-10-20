extends Control

@export var player_group: StringName = &"player"
@export var circle_radius: float = 14.0
@export var circle_spacing: float = 8.0
@export var circle_segments: int = 48
@export var fill_step: float = 0.5
@export var full_color: Color = Color(0.9, 0.2, 0.25)
@export var empty_color: Color = Color(0.2, 0.06, 0.08)
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var outline_width: float = 2.0
@export var full_texture: Texture2D
@export var empty_texture: Texture2D

var player: Node = null
var current: float = 0.0
var maximum: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		return

	var found: Node = get_tree().get_first_node_in_group(player_group)
	if found == null or not found.has_signal("health_changed"):
		return

	player = found
	found.connect("health_changed", on_health_changed)
	on_health_changed(float(found.get("health")), float(found.get("max_health")))


func on_health_changed(new_current: float, new_maximum: float) -> void:
	current = new_current
	maximum = new_maximum

	var count: int = ceili(maximum)
	var diameter: float = circle_radius * 2.0
	var total_width: float = float(count) * diameter + float(maxi(count - 1, 0)) * circle_spacing
	custom_minimum_size = Vector2(total_width, diameter)

	queue_redraw()


func _draw() -> void:
	var count: int = ceili(maximum)
	var diameter: float = circle_radius * 2.0

	var shown: float = current
	if fill_step > 0.0:
		shown = minf(ceilf(current / fill_step) * fill_step, maximum)

	for index in range(count):
		var center: Vector2 = Vector2(circle_radius + float(index) * (diameter + circle_spacing), circle_radius)
		var fraction: float = clampf(shown - float(index), 0.0, 1.0)
		if full_texture != null and empty_texture != null:
			draw_texture_slot(center, fraction)
		else:
			draw_circle_slot(center, fraction)


func draw_circle_slot(center: Vector2, fraction: float) -> void:
	draw_circle(center, circle_radius, empty_color)

	if fraction >= 1.0:
		draw_circle(center, circle_radius, full_color)
	elif fraction > 0.0:
		draw_colored_polygon(clipped_circle(center, fraction), full_color)

	draw_arc(center, circle_radius, 0.0, TAU, circle_segments, outline_color, outline_width, true)


func clipped_circle(center: Vector2, fraction: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var clip_x: float = center.x - circle_radius + circle_radius * 2.0 * fraction
	for step in range(circle_segments):
		var angle: float = TAU * float(step) / float(circle_segments)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * circle_radius
		point.x = minf(point.x, clip_x)
		points.append(point)
	return points


func draw_texture_slot(center: Vector2, fraction: float) -> void:
	var diameter: float = circle_radius * 2.0
	var rect: Rect2 = Rect2(center - Vector2(circle_radius, circle_radius), Vector2(diameter, diameter))

	draw_texture_rect(empty_texture, rect, false)

	if fraction >= 1.0:
		draw_texture_rect(full_texture, rect, false)
	elif fraction > 0.0:
		var source: Rect2 = Rect2(Vector2.ZERO, Vector2(float(full_texture.get_width()) * fraction, float(full_texture.get_height())))
		var target: Rect2 = Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y))
		draw_texture_rect_region(full_texture, target, source)
