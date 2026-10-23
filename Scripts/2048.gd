extends Control

signal closed

@export var grid_size: int = 4
@export var header_height: float = 64.0
@export var board_padding: float = 10.0
@export var tile_gap: float = 10.0
@export var tile_corner_radius: int = 6
@export var four_chance: float = 0.1
@export var win_value: int = 2048
@export var slide_time: float = 0.11
@export var pop_time: float = 0.12
@export var pop_scale: float = 1.18
@export var font_size: int = 18
@export var title_font_size: int = 30
@export var background_color: Color = Color(0.98, 0.97, 0.94)
@export var board_color: Color = Color(0.73, 0.68, 0.63)
@export var empty_color: Color = Color(0.8, 0.76, 0.71)
@export var box_color: Color = Color(0.73, 0.68, 0.63)
@export var title_color: Color = Color(0.47, 0.43, 0.4)
@export var light_text_color: Color = Color(0.98, 0.97, 0.94)
@export var dark_text_color: Color = Color(0.47, 0.43, 0.4)
@export var overlay_color: Color = Color(0.98, 0.97, 0.94, 0.75)
@export var super_tile_color: Color = Color(0.24, 0.23, 0.2)
@export var tile_colors: Dictionary = {
	2: Color(0.93, 0.89, 0.85),
	4: Color(0.93, 0.88, 0.78),
	8: Color(0.95, 0.69, 0.47),
	16: Color(0.96, 0.58, 0.39),
	32: Color(0.96, 0.48, 0.37),
	64: Color(0.96, 0.37, 0.23),
	128: Color(0.93, 0.81, 0.45),
	256: Color(0.93, 0.8, 0.38),
	512: Color(0.93, 0.78, 0.31),
	1024: Color(0.93, 0.77, 0.25),
	2048: Color(0.93, 0.76, 0.18),
}

var grid: Array[int] = []
var score: int = 0
var best: int = 0
var won: bool = false
var keep_playing: bool = false
var game_over: bool = false
var anim_tiles: Array[Dictionary] = []
var merged_cells: Array[Vector2i] = []
var spawned_cells: Array[Vector2i] = []
var anim_time: float = 10.0
var pending_dir: Vector2i = Vector2i.ZERO
var tile_style := StyleBoxFlat.new()
var cell_size: float = 80.0
var board_origin: Vector2 = Vector2.ZERO
var board_side: float = 360.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tile_style.set_corner_radius_all(tile_corner_radius)
	reset_game()


func reset_game() -> void:
	grid.clear()
	for i in grid_size * grid_size:
		grid.append(0)
	score = 0
	won = false
	keep_playing = false
	game_over = false
	anim_tiles.clear()
	merged_cells.clear()
	spawned_cells.clear()
	pending_dir = Vector2i.ZERO
	for i in 2:
		var cell := spawn_tile()
		if cell.x >= 0:
			spawned_cells.append(cell)
	anim_time = slide_time
	queue_redraw()


func spawn_tile() -> Vector2i:
	var free: Array[int] = []
	for i in grid.size():
		if grid[i] == 0:
			free.append(i)
	if free.is_empty():
		return Vector2i(-1, -1)
	var chosen: int = free[randi() % free.size()]
	grid[chosen] = 4 if randf() < four_chance else 2
	return Vector2i(chosen % grid_size, chosen / grid_size)


func get_line(index: int, dir: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	for i in grid_size:
		if dir == Vector2i.LEFT:
			line.append(Vector2i(i, index))
		elif dir == Vector2i.RIGHT:
			line.append(Vector2i(grid_size - 1 - i, index))
		elif dir == Vector2i.UP:
			line.append(Vector2i(index, i))
		else:
			line.append(Vector2i(index, grid_size - 1 - i))
	return line


func try_move(dir: Vector2i) -> void:
	var new_grid: Array[int] = []
	new_grid.resize(grid_size * grid_size)
	new_grid.fill(0)
	var tiles: Array[Dictionary] = []
	var merges: Array[Vector2i] = []
	var gained: int = 0
	var moved: bool = false
	for index in grid_size:
		var line := get_line(index, dir)
		var target: int = 0
		var last_slot: int = -1
		var last_value: int = 0
		var last_merged: bool = false
		for j in line.size():
			var c: Vector2i = line[j]
			var v: int = grid[c.y * grid_size + c.x]
			if v == 0:
				continue
			if last_slot >= 0 and not last_merged and last_value == v:
				var merge_dest: Vector2i = line[last_slot]
				tiles.append({"value": v, "from": c, "to": merge_dest})
				new_grid[merge_dest.y * grid_size + merge_dest.x] = v * 2
				merges.append(merge_dest)
				gained += v * 2
				last_merged = true
				last_value = v * 2
				moved = true
			else:
				var dest: Vector2i = line[target]
				tiles.append({"value": v, "from": c, "to": dest})
				new_grid[dest.y * grid_size + dest.x] = v
				if dest != c:
					moved = true
				last_slot = target
				last_value = v
				last_merged = false
				target += 1
	if not moved:
		return
	grid = new_grid
	score += gained
	best = max(best, score)
	anim_tiles = tiles
	merged_cells = merges
	spawned_cells.clear()
	var spawned := spawn_tile()
	if spawned.x >= 0:
		spawned_cells.append(spawned)
	for m in merges:
		if grid[m.y * grid_size + m.x] >= win_value and not won:
			won = true
	if not can_move():
		game_over = true
	anim_time = 0.0
	queue_redraw()


func can_move() -> bool:
	for x in grid_size:
		for y in grid_size:
			var v: int = grid[y * grid_size + x]
			if v == 0:
				return true
			if x + 1 < grid_size and grid[y * grid_size + x + 1] == v:
				return true
			if y + 1 < grid_size and grid[(y + 1) * grid_size + x] == v:
				return true
	return false


func blocked() -> bool:
	return game_over or (won and not keep_playing)


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
	var enter: bool = key == KEY_ENTER or key == KEY_KP_ENTER
	if key == KEY_R or (enter and game_over):
		reset_game()
		get_viewport().set_input_as_handled()
		return
	if enter and won and not keep_playing:
		keep_playing = true
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if blocked():
		return
	var dir := Vector2i.ZERO
	if key == KEY_UP or key == KEY_W:
		dir = Vector2i.UP
	elif key == KEY_DOWN or key == KEY_S:
		dir = Vector2i.DOWN
	elif key == KEY_LEFT or key == KEY_A:
		dir = Vector2i.LEFT
	elif key == KEY_RIGHT or key == KEY_D:
		dir = Vector2i.RIGHT
	if dir == Vector2i.ZERO:
		return
	get_viewport().set_input_as_handled()
	if anim_time < slide_time:
		pending_dir = dir
	else:
		try_move(dir)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var was_animating: bool = anim_time < slide_time + pop_time
	anim_time += delta
	if pending_dir != Vector2i.ZERO and anim_time >= slide_time:
		var dir := pending_dir
		pending_dir = Vector2i.ZERO
		if not blocked():
			try_move(dir)
		was_animating = true
	if was_animating:
		queue_redraw()


func update_layout() -> void:
	var available := Vector2(size.x - 20.0, size.y - header_height - 10.0)
	board_side = max(40.0, min(available.x, available.y))
	board_origin = Vector2((size.x - board_side) * 0.5, header_height + (size.y - header_height - board_side) * 0.5)
	cell_size = (board_side - board_padding * 2.0 - tile_gap * (grid_size - 1)) / grid_size


func cell_pos(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(board_padding, board_padding) + Vector2(cell) * (cell_size + tile_gap)


func _draw() -> void:
	update_layout()
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	draw_header()
	tile_style.bg_color = board_color
	draw_style_box(tile_style, Rect2(board_origin, Vector2(board_side, board_side)))
	for x in grid_size:
		for y in grid_size:
			tile_style.bg_color = empty_color
			draw_style_box(tile_style, Rect2(cell_pos(Vector2i(x, y)), Vector2(cell_size, cell_size)))
	if anim_time < slide_time and not anim_tiles.is_empty():
		var p: float = clampf(anim_time / slide_time, 0.0, 1.0)
		p = 1.0 - pow(1.0 - p, 3.0)
		for t in anim_tiles:
			var from_cell: Vector2i = t["from"]
			var to_cell: Vector2i = t["to"]
			draw_tile(t["value"], cell_pos(from_cell).lerp(cell_pos(to_cell), p), 1.0)
	else:
		var q: float = clampf((anim_time - slide_time) / pop_time, 0.0, 1.0)
		for x in grid_size:
			for y in grid_size:
				var v: int = grid[y * grid_size + x]
				if v == 0:
					continue
				var c := Vector2i(x, y)
				var tile_scale: float = 1.0
				if merged_cells.has(c):
					tile_scale = 1.0 + (pop_scale - 1.0) * sin(PI * q)
				if spawned_cells.has(c):
					tile_scale = q
				draw_tile(v, cell_pos(c), tile_scale)
	if anim_time >= slide_time + pop_time:
		if game_over:
			draw_overlay("Game over - Enter to restart")
		elif won and not keep_playing:
			draw_overlay("You made 2048! Enter to keep playing")


func draw_tile(value: int, pos: Vector2, tile_scale: float) -> void:
	if tile_scale <= 0.001:
		return
	var side: float = cell_size * tile_scale
	var center: Vector2 = pos + Vector2(cell_size, cell_size) * 0.5
	var rect := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	tile_style.bg_color = tile_colors.get(value, super_tile_color)
	draw_style_box(tile_style, rect)
	var text: String = str(value)
	var length: int = text.length()
	var ratio: float = 0.5
	if length == 3:
		ratio = 0.4
	elif length == 4:
		ratio = 0.32
	elif length > 4:
		ratio = 0.25
	var label_color: Color = dark_text_color if value <= 4 else light_text_color
	draw_centered_text(text, center, int(side * ratio), label_color)


func draw_centered_text(text: String, center: Vector2, fs: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(center.x - text_size.x * 0.5, center.y - text_size.y * 0.5 + font.get_ascent(fs))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func draw_header() -> void:
	var title_center := Vector2(60, header_height * 0.5)
	draw_centered_text("2048", title_center, title_font_size, title_color)
	var box_size := Vector2(86, header_height - 16.0)
	var best_pos := Vector2(size.x - 10.0 - box_size.x, 8.0)
	var score_pos := Vector2(best_pos.x - 8.0 - box_size.x, 8.0)
	draw_score_box("SCORE", score, Rect2(score_pos, box_size))
	draw_score_box("BEST", best, Rect2(best_pos, box_size))


func draw_score_box(label: String, value: int, rect: Rect2) -> void:
	tile_style.bg_color = box_color
	draw_style_box(tile_style, rect)
	var center := rect.get_center()
	draw_centered_text(label, center + Vector2(0, -rect.size.y * 0.25), int(font_size * 0.6), Color(0.93, 0.89, 0.85))
	draw_centered_text(str(value), center + Vector2(0, rect.size.y * 0.15), font_size, light_text_color)


func draw_overlay(text: String) -> void:
	tile_style.bg_color = overlay_color
	draw_style_box(tile_style, Rect2(board_origin, Vector2(board_side, board_side)))
	draw_centered_text(text, board_origin + Vector2(board_side, board_side) * 0.5, font_size + 4, dark_text_color)
