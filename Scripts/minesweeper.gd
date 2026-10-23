extends Control

signal closed

@export var grid_width: int = 12
@export var grid_height: int = 12
@export var mine_count: int = 20
@export var header_height: float = 36.0
@export var font_size: int = 18
@export var background_color: Color = Color(0.1, 0.1, 0.12)
@export var hidden_color: Color = Color(0.35, 0.38, 0.45)
@export var revealed_color: Color = Color(0.75, 0.77, 0.82)
@export var mine_color: Color = Color(0.85, 0.2, 0.2)
@export var flag_color: Color = Color(1.0, 0.8, 0.1)
@export var text_color: Color = Color(0.95, 0.95, 0.95)
@export var cell_gap: float = 1.0
@export var number_colors: Array[Color] = [
	Color.TRANSPARENT,
	Color(0.1, 0.3, 0.9),
	Color(0.1, 0.55, 0.15),
	Color(0.85, 0.15, 0.15),
	Color(0.1, 0.1, 0.55),
	Color(0.55, 0.1, 0.1),
	Color(0.1, 0.5, 0.5),
	Color(0.1, 0.1, 0.1),
	Color(0.4, 0.4, 0.4),
]

var mines: Array[bool] = []
var revealed: Array[bool] = []
var flagged: Array[bool] = []
var counts: Array[int] = []
var placed: bool = false
var alive: bool = true
var won: bool = false
var elapsed: float = 0.0
var last_shown_second: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	reset_game()


func reset_game() -> void:
	var total: int = grid_width * grid_height
	mines.clear()
	revealed.clear()
	flagged.clear()
	counts.clear()
	for i in total:
		mines.append(false)
		revealed.append(false)
		flagged.append(false)
		counts.append(0)
	placed = false
	alive = true
	won = false
	elapsed = 0.0
	last_shown_second = -1
	queue_redraw()


func idx(cell: Vector2i) -> int:
	return cell.y * grid_width + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n := cell + Vector2i(dx, dy)
			if in_bounds(n):
				result.append(n)
	return result


func place_mines(safe: Vector2i) -> void:
	var candidates: Array[Vector2i] = []
	for x in grid_width:
		for y in grid_height:
			var c := Vector2i(x, y)
			if c != safe and not neighbors(safe).has(c):
				candidates.append(c)
	candidates.shuffle()
	var amount: int = min(mine_count, candidates.size())
	for i in amount:
		mines[idx(candidates[i])] = true
	for x in grid_width:
		for y in grid_height:
			var c := Vector2i(x, y)
			var total: int = 0
			for n in neighbors(c):
				if mines[idx(n)]:
					total += 1
			counts[idx(c)] = total
	placed = true


func reveal(cell: Vector2i) -> void:
	var stack: Array[Vector2i] = [cell]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		var i: int = idx(c)
		if revealed[i] or flagged[i]:
			continue
		revealed[i] = true
		if mines[i]:
			alive = false
			reveal_all_mines()
			return
		if counts[i] == 0:
			for n in neighbors(c):
				if not revealed[idx(n)]:
					stack.append(n)
	check_win()


func reveal_all_mines() -> void:
	for i in mines.size():
		if mines[i]:
			revealed[i] = true


func check_win() -> void:
	for i in mines.size():
		if not mines[i] and not revealed[i]:
			return
	won = true
	for i in mines.size():
		if mines[i]:
			flagged[i] = true


func chord(cell: Vector2i) -> void:
	var i: int = idx(cell)
	if not revealed[i] or counts[i] == 0:
		return
	var flags: int = 0
	for n in neighbors(cell):
		if flagged[idx(n)]:
			flags += 1
	if flags != counts[i]:
		return
	for n in neighbors(cell):
		if alive and not flagged[idx(n)] and not revealed[idx(n)]:
			reveal(n)


func get_layout() -> Dictionary:
	var cell: float = min(size.x / grid_width, (size.y - header_height) / grid_height)
	var board_size := Vector2(cell * grid_width, cell * grid_height)
	var origin := Vector2((size.x - board_size.x) * 0.5, header_height + (size.y - header_height - board_size.y) * 0.5)
	return {"cell": cell, "origin": origin, "board_size": board_size}


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if not alive or won:
		return
	var layout := get_layout()
	var cell_size: float = layout["cell"]
	var local: Vector2 = event.position - layout["origin"]
	var cell := Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))
	if not in_bounds(cell):
		return
	var i: int = idx(cell)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if revealed[i]:
			chord(cell)
		elif not flagged[i]:
			if not placed:
				place_mines(cell)
			reveal(cell)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if not revealed[i]:
			flagged[i] = not flagged[i]
	accept_event()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
	elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_R:
		reset_game()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not placed or not alive or won or not is_visible_in_tree():
		return
	elapsed += delta
	var whole: int = int(elapsed)
	if whole != last_shown_second:
		last_shown_second = whole
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	var layout := get_layout()
	var cell_size: float = layout["cell"]
	var origin: Vector2 = layout["origin"]
	var font := ThemeDB.fallback_font
	var flags_used: int = 0
	for f in flagged:
		if f:
			flags_used += 1
	var status: String = ""
	if won:
		status = "   You win - Enter to restart"
	elif not alive:
		status = "   Boom - Enter to restart"
	draw_string(font, Vector2(10, font.get_ascent(font_size) + 6), "Mines %d   Time %d%s" % [mine_count - flags_used, int(elapsed), status], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	var gap := Vector2(cell_gap, cell_gap)
	for x in grid_width:
		for y in grid_height:
			var c := Vector2i(x, y)
			var i: int = idx(c)
			var rect := Rect2(origin + Vector2(c) * cell_size + gap * 0.5, Vector2(cell_size, cell_size) - gap)
			if revealed[i]:
				draw_rect(rect, mine_color if mines[i] else revealed_color)
				if mines[i]:
					draw_circle(rect.get_center(), cell_size * 0.22, Color.BLACK)
				elif counts[i] > 0:
					draw_cell_text(str(counts[i]), rect, number_colors[counts[i]])
			else:
				draw_rect(rect, hidden_color)
				if flagged[i]:
					var center := rect.get_center()
					var s: float = cell_size * 0.25
					draw_colored_polygon(PackedVector2Array([center + Vector2(-s, -s), center + Vector2(s, 0), center + Vector2(-s, s)]), flag_color)


func draw_cell_text(text: String, rect: Rect2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs: int = int(rect.size.y * 0.65)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(rect.get_center().x - text_size.x * 0.5, rect.get_center().y - text_size.y * 0.5 + font.get_ascent(fs))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
