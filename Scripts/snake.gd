extends Control

signal closed

@export var grid_presets: Array[Vector2i] = [Vector2i(10, 9), Vector2i(17, 15), Vector2i(24, 21)]
@export var preset_index: int = 1
@export var start_step_time: float = 0.14
@export var min_step_time: float = 0.08
@export var speed_up_per_food: float = 0.001
@export_range(0.0, 1.0) var snap_amount: float = 0.2
@export var header_height: float = 44.0
@export var board_margin: float = 8.0
@export var font_size: int = 20
@export var apple_radius_ratio: float = 0.38
@export var background_color: Color = Color(0.34, 0.54, 0.2)
@export var header_color: Color = Color(0.29, 0.46, 0.17)
@export var light_tile_color: Color = Color(0.667, 0.843, 0.318)
@export var dark_tile_color: Color = Color(0.635, 0.816, 0.282)
@export var snake_color: Color = Color(0.306, 0.486, 0.965)
@export var apple_color: Color = Color(0.906, 0.22, 0.157)
@export var leaf_color: Color = Color(0.2, 0.6, 0.2)
@export var stem_color: Color = Color(0.4, 0.25, 0.1)
@export var trophy_color: Color = Color(1.0, 0.8, 0.1)
@export var text_color: Color = Color(1, 1, 1)
@export var banner_color: Color = Color(0, 0, 0, 0.65)

var grid_width: int = 17
var grid_height: int = 15
var snake: Array[Vector2i] = []
var removed_tail: Vector2i = Vector2i.ZERO
var has_removed_tail: bool = false
var direction: Vector2i = Vector2i.RIGHT
var prev_direction: Vector2i = Vector2i.RIGHT
var queued: Array[Vector2i] = []
var food: Vector2i = Vector2i.ZERO
var timer: float = 0.0
var current_step: float = 0.14
var score: int = 0
var best: int = 0
var alive: bool = true
var started: bool = false
var cell_size: float = 20.0
var board_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	apply_preset(preset_index)


func apply_preset(index: int) -> void:
	preset_index = clampi(index, 0, grid_presets.size() - 1)
	grid_width = grid_presets[preset_index].x
	grid_height = grid_presets[preset_index].y
	best = 0
	reset_game()


func reset_game() -> void:
	snake.clear()
	var start := Vector2i(max(2, grid_width / 4), grid_height / 2)
	for i in 3:
		snake.append(start - Vector2i(i, 0))
	has_removed_tail = false
	direction = Vector2i.RIGHT
	prev_direction = Vector2i.RIGHT
	queued.clear()
	score = 0
	timer = 0.0
	current_step = start_step_time
	alive = true
	started = false
	food = Vector2i(grid_width * 3 / 4, grid_height / 2)
	queue_redraw()


func spawn_food() -> void:
	var free: Array[Vector2i] = []
	for x in grid_width:
		for y in grid_height:
			var cell := Vector2i(x, y)
			if not snake.has(cell):
				free.append(cell)
	if free.is_empty():
		alive = false
		has_removed_tail = false
		best = max(best, score)
		return
	food = free[randi() % free.size()]


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_R:
		if not alive:
			reset_game()
		get_viewport().set_input_as_handled()
		return
	if (not started or not alive) and key >= KEY_1 and key <= KEY_9:
		var index: int = key - KEY_1
		if index < grid_presets.size():
			apply_preset(index)
			get_viewport().set_input_as_handled()
			return
	var wanted := Vector2i.ZERO
	if key == KEY_UP or key == KEY_W:
		wanted = Vector2i.UP
	elif key == KEY_DOWN or key == KEY_S:
		wanted = Vector2i.DOWN
	elif key == KEY_LEFT or key == KEY_A:
		wanted = Vector2i.LEFT
	elif key == KEY_RIGHT or key == KEY_D:
		wanted = Vector2i.RIGHT
	if wanted == Vector2i.ZERO or not alive:
		return
	get_viewport().set_input_as_handled()
	var last: Vector2i = direction
	if not queued.is_empty():
		last = queued.back()
	if wanted == last or wanted == -last:
		return
	if queued.size() < 2:
		queued.append(wanted)
	started = true


func _process(delta: float) -> void:
	if not started or not alive or not is_visible_in_tree():
		return
	timer += delta
	while timer >= current_step and alive:
		timer -= current_step
		step()
	queue_redraw()


func step() -> void:
	prev_direction = direction
	if not queued.is_empty():
		direction = queued.pop_front()
	var new_head: Vector2i = snake[0] + direction
	var eating: bool = new_head == food
	var hit: bool = new_head.x < 0 or new_head.y < 0 or new_head.x >= grid_width or new_head.y >= grid_height
	if not hit:
		var body_to_check: Array[Vector2i] = snake.duplicate()
		if not eating:
			body_to_check.pop_back()
		hit = body_to_check.has(new_head)
	if hit:
		direction = prev_direction
		alive = false
		has_removed_tail = false
		best = max(best, score)
		return
	snake.push_front(new_head)
	if eating:
		has_removed_tail = false
		score += 1
		best = max(best, score)
		current_step = max(min_step_time, current_step - speed_up_per_food)
		spawn_food()
	else:
		removed_tail = snake.pop_back()
		has_removed_tail = true


func get_progress() -> float:
	if not started or not alive:
		return 1.0
	var linear: float = clampf(timer / current_step, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - linear, 3.0)
	return lerpf(linear, eased, snap_amount)


func update_layout() -> void:
	var available := Vector2(size.x - board_margin * 2.0, size.y - header_height - board_margin * 2.0)
	cell_size = max(4.0, min(available.x / grid_width, available.y / grid_height))
	var board_size := Vector2(cell_size * grid_width, cell_size * grid_height)
	board_origin = Vector2((size.x - board_size.x) * 0.5, header_height + (size.y - header_height - board_size.y) * 0.5)


func cell_center(cell: Vector2) -> Vector2:
	return board_origin + (cell + Vector2(0.5, 0.5)) * cell_size


func _draw() -> void:
	update_layout()
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	for x in grid_width:
		for y in grid_height:
			var color: Color = light_tile_color if (x + y) % 2 == 0 else dark_tile_color
			draw_rect(Rect2(board_origin + Vector2(x, y) * cell_size, Vector2(cell_size, cell_size)), color)
	draw_apple(cell_center(Vector2(food)))
	draw_snake()
	draw_header()
	if not started and alive:
		draw_banner("Arrow keys or WASD to start    1 2 3 = grid size")
	elif not alive:
		draw_banner("Game over - Enter to restart    1 2 3 = grid size")


func draw_apple(center: Vector2) -> void:
	var radius: float = cell_size * apple_radius_ratio
	draw_circle(center + Vector2(0, radius * 0.1), radius, apple_color)
	draw_line(center + Vector2(0, -radius * 0.8), center + Vector2(radius * 0.15, -radius * 1.25), stem_color, max(1.0, radius * 0.18))
	var leaf_base := center + Vector2(radius * 0.1, -radius * 0.9)
	draw_colored_polygon(PackedVector2Array([leaf_base, leaf_base + Vector2(radius * 0.7, -radius * 0.5), leaf_base + Vector2(radius * 0.8, radius * 0.05)]), leaf_color)


func draw_snake() -> void:
	var t: float = get_progress()
	var full := Vector2(cell_size, cell_size)
	for i in range(1, snake.size()):
		draw_rect(Rect2(board_origin + Vector2(snake[i]) * cell_size, full), snake_color)
	if has_removed_tail and alive:
		var tail_dir := Vector2(snake.back() - removed_tail)
		var tail_abs := Vector2(absf(tail_dir.x), absf(tail_dir.y))
		var tail_offset := Vector2(maxf(tail_dir.x, 0.0), maxf(tail_dir.y, 0.0)) * cell_size * t
		var tail_size: Vector2 = full - tail_abs * cell_size * t
		draw_rect(Rect2(board_origin + Vector2(removed_tail) * cell_size + tail_offset, tail_size), snake_color)
	var head_dir := Vector2(snake[0] - snake[1])
	var head_abs := Vector2(absf(head_dir.x), absf(head_dir.y))
	var head_offset := Vector2(maxf(-head_dir.x, 0.0), maxf(-head_dir.y, 0.0)) * cell_size * (1.0 - t)
	var head_size: Vector2 = full - head_abs * cell_size * (1.0 - t)
	draw_rect(Rect2(board_origin + Vector2(snake[0]) * cell_size + head_offset, head_size), snake_color)
	var eye_cell: Vector2 = Vector2(snake[1]).lerp(Vector2(snake[0]), t)
	if not started:
		eye_cell = Vector2(snake[0])
	var eye_center: Vector2 = cell_center(eye_cell)
	var eye_angle: float = lerp_angle(Vector2(prev_direction).angle(), Vector2(direction).angle(), t)
	var forward: Vector2 = Vector2.from_angle(eye_angle)
	var side := Vector2(-forward.y, forward.x)
	for sign_value in [-1.0, 1.0]:
		var eye: Vector2 = eye_center + forward * cell_size * 0.12 + side * sign_value * cell_size * 0.2
		draw_circle(eye, cell_size * 0.15, Color.WHITE)
		draw_circle(eye + forward * cell_size * 0.05, cell_size * 0.08, Color(0.1, 0.1, 0.15))


func draw_header() -> void:
	draw_rect(Rect2(0, 0, size.x, header_height), header_color)
	var font := ThemeDB.fallback_font
	var baseline: float = header_height * 0.5 - font.get_height(font_size) * 0.5 + font.get_ascent(font_size)
	draw_apple_icon(Vector2(26, header_height * 0.5))
	var score_text: String = str(score)
	draw_string(font, Vector2(46, baseline), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	var score_width: float = font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var trophy_x: float = 46.0 + score_width + 40.0
	draw_trophy(Vector2(trophy_x, header_height * 0.5))
	draw_string(font, Vector2(trophy_x + 20, baseline), str(best), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func draw_apple_icon(center: Vector2) -> void:
	draw_circle(center + Vector2(0, 1), 10.0, apple_color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(1, -9), center + Vector2(8, -13), center + Vector2(9, -7)]), leaf_color)


func draw_trophy(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-9, -9), center + Vector2(9, -9), center + Vector2(6, 2), center + Vector2(-6, 2)]), trophy_color)
	draw_rect(Rect2(center + Vector2(-2, 2), Vector2(4, 5)), trophy_color)
	draw_rect(Rect2(center + Vector2(-6, 7), Vector2(12, 3)), trophy_color)


func draw_banner(text: String) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var board_center := board_origin + Vector2(cell_size * grid_width, cell_size * grid_height) * 0.5
	var pos := Vector2(board_center.x - text_size.x * 0.5, board_center.y - text_size.y * 0.5 + font.get_ascent(font_size))
	draw_rect(Rect2(pos - Vector2(12, font.get_ascent(font_size) + 6), text_size + Vector2(24, 12)), banner_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
