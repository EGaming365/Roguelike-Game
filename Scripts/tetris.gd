extends Control

signal closed
signal challenge_selected(index: int)

enum Page { MENU, CHALLENGES, SKINS, SETTINGS, GAME }
enum State { PLAYING, PAUSED, OVER }

const SHAPES: Array = [
	[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
]
const SIZES: Array = [4, 2, 3, 3, 3, 3, 3]
const KICKS: Array = [0, -1, 1, -2, 2]

@export var apply_layout: bool = true
@export var challenge_columns: int = 5
@export var background_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var columns: int = 10
@export var rows: int = 20
@export var auto_fit: bool = true
@export var cell_size: float = 24.0
@export var base_fall_interval: float = 0.8
@export var level_speedup: float = 0.07
@export var min_fall_interval: float = 0.05
@export var soft_drop_interval: float = 0.04
@export var soft_drop_score: int = 1
@export var max_frame_delta: float = 0.05
@export var lock_delay: float = 0.5
@export var lock_reset_limit: int = 15
@export var lines_per_level: int = 10
@export var score_table: Array[int] = [0, 100, 300, 500, 800]
@export var left_actions: Array[StringName] = [&"ui_left", &"move_left"]
@export var right_actions: Array[StringName] = [&"ui_right", &"move_right"]
@export var rotate_actions: Array[StringName] = [&"ui_up", &"move_up"]
@export var hard_drop_actions: Array[StringName] = [&"space"]
@export var restart_actions: Array[StringName] = [&"ui_accept", &"select"]
@export var back_actions: Array[StringName] = [&"ui_cancel"]
@export var fast_actions: Array[StringName] = [&"ui_down", &"move_down"]
@export var pause_key: Key = KEY_P
@export var rotate_ccw_key: Key = KEY_Z
@export var font_scale: float = 0.7
@export var ghost_alpha: float = 0.25
@export var board_color: Color = Color(0.08, 0.09, 0.12)
@export var grid_color: Color = Color(1.0, 1.0, 1.0, 0.06)
@export var text_color: Color = Color(0.85, 0.95, 0.85)
@export var piece_colors: Array[Color] = [
	Color(0.2, 0.9, 0.95),
	Color(0.95, 0.85, 0.2),
	Color(0.7, 0.3, 0.9),
	Color(0.3, 0.9, 0.35),
	Color(0.95, 0.3, 0.3),
	Color(0.25, 0.4, 0.95),
	Color(0.95, 0.6, 0.2),
]

@onready var background: ColorRect = find_child("Background", true, false) as ColorRect
@onready var main_menu: Control = find_child("MainMenu", true, false) as Control
@onready var endless_button: BaseButton = find_child("EndlessButton", true, false) as BaseButton
@onready var challenges_button: BaseButton = find_child("ChallengesButton", true, false) as BaseButton
@onready var skins_button: BaseButton = find_child("SkinsButton", true, false) as BaseButton
@onready var settings_button: BaseButton = find_child("SettingsButton", true, false) as BaseButton
@onready var exit_button: BaseButton = find_child("ExitButton", true, false) as BaseButton
@onready var challenges_panel: Control = find_child("ChallengesPanel", true, false) as Control
@onready var challenge_grid: Container = find_child("ChallengeGrid", true, false) as Container
@onready var rotation_button: BaseButton = find_child("Rotation", true, false) as BaseButton
@onready var skins_panel: Control = find_child("SkinsPanel", true, false) as Control
@onready var settings_panel: Control = find_child("SettingsPanel", true, false) as Control
@onready var game_view: Control = find_child("GameView", true, false) as Control

var page: Page = Page.MENU
var board: Array[int] = []
var bag: Array[int] = []
var current_type: int = 0
var next_type: int = 0
var current_cells: Array[Vector2i] = []
var current_pos: Vector2i = Vector2i.ZERO
var gravity_timer: float = 0.0
var lock_timer: float = 0.0
var lock_resets: int = 0
var score: int = 0
var lines: int = 0
var level: int = 1
var high_score: int = 0
var state: State = State.OVER


func _ready() -> void:
	randomize()
	if apply_layout:
		apply_layout_settings()
	_reset_board()
	next_type = _pull()
	current_type = next_type
	current_cells = _base_cells(current_type)

	if game_view == null:
		push_warning("Tetris is missing a Control named GameView")
	else:
		game_view.draw.connect(draw_game)

	connect_button(endless_button, on_endless_pressed, "EndlessButton")
	connect_button(challenges_button, show_page.bind(Page.CHALLENGES), "ChallengesButton")
	connect_button(skins_button, show_page.bind(Page.SKINS), "SkinsButton")
	connect_button(settings_button, show_page.bind(Page.SETTINGS), "SettingsButton")
	connect_button(exit_button, on_exit_pressed, "ExitButton")

	for host: Control in [challenges_panel, skins_panel, settings_panel, game_view]:
		if host == null:
			continue
		var back: BaseButton = host.find_child("BackButton", true, false) as BaseButton
		if back != null:
			back.focus_mode = Control.FOCUS_NONE
			back.pressed.connect(show_page.bind(Page.MENU))

	if challenge_grid != null:
		var index: int = 0
		for child in challenge_grid.get_children():
			var button: BaseButton = child as BaseButton
			if button == null:
				continue
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(on_challenge_pressed.bind(index))
			index += 1

	show_page(Page.MENU)


func apply_layout_settings() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if background != null:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.color = background_color
		background.mouse_filter = Control.MOUSE_FILTER_STOP
		background.get_parent().move_child(background, 0)
	if game_view != null:
		game_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid: GridContainer = challenge_grid as GridContainer
	if grid != null:
		grid.columns = challenge_columns


func connect_button(button: BaseButton, callback: Callable, label: String) -> void:
	if button == null:
		push_warning("Tetris is missing a button named " + label)
		return
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)


func set_node_visible(node: CanvasItem, value: bool) -> void:
	if node != null:
		node.visible = value


func show_page(target: Page) -> void:
	page = target
	set_node_visible(main_menu, target == Page.MENU)
	set_node_visible(challenges_panel, target == Page.CHALLENGES)
	set_node_visible(skins_panel, target == Page.SKINS)
	set_node_visible(settings_panel, target == Page.SETTINGS)
	set_node_visible(game_view, target == Page.GAME)
	if game_view != null:
		game_view.queue_redraw()


func on_endless_pressed() -> void:
	start_game()
	show_page(Page.GAME)


func on_challenge_pressed(index: int) -> void:
	challenge_selected.emit(index)


func on_exit_pressed() -> void:
	closed.emit()


func start_game() -> void:
	_reset_board()
	score = 0
	lines = 0
	level = 1
	bag.clear()
	next_type = _pull()
	state = State.PLAYING
	_spawn()


func _reset_board() -> void:
	board.resize(columns * rows)
	board.fill(-1)


func _pull() -> int:
	if bag.is_empty():
		for i in 7:
			bag.append(i)
		bag.shuffle()
	return bag.pop_back()


func _base_cells(t: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in SHAPES[t]:
		out.append(c)
	return out


func _spawn() -> void:
	current_type = next_type
	next_type = _pull()
	current_cells = _base_cells(current_type)
	var min_y := 99
	for c in current_cells:
		min_y = mini(min_y, c.y)
	var n: int = SIZES[current_type]
	current_pos = Vector2i((columns - n) / 2, -min_y)
	gravity_timer = 0.0
	lock_timer = 0.0
	lock_resets = 0
	if _collides(current_cells, current_pos):
		_end_game()


func _end_game() -> void:
	state = State.OVER
	high_score = maxi(high_score, score)


func _collides(cells: Array[Vector2i], pos: Vector2i) -> bool:
	for c in cells:
		var x := c.x + pos.x
		var y := c.y + pos.y
		if x < 0 or x >= columns or y >= rows:
			return true
		if y >= 0 and board[y * columns + x] != -1:
			return true
	return false


func _try_move(d: Vector2i) -> bool:
	if _collides(current_cells, current_pos + d):
		return false
	current_pos += d
	return true


func _on_moved() -> void:
	if lock_resets < lock_reset_limit:
		lock_timer = 0.0
		lock_resets += 1


func _rotate(clockwise: bool) -> void:
	if current_type == 1:
		return
	var n: int = SIZES[current_type]
	var rotated: Array[Vector2i] = []
	for c in current_cells:
		if clockwise:
			rotated.append(Vector2i(n - 1 - c.y, c.x))
		else:
			rotated.append(Vector2i(c.y, n - 1 - c.x))
	for k in KICKS:
		var p := current_pos + Vector2i(k, 0)
		if not _collides(rotated, p):
			current_cells = rotated
			current_pos = p
			_on_moved()
			return


func _hard_drop() -> void:
	while _try_move(Vector2i(0, 1)):
		score += 2
	_lock()


func _lock() -> void:
	for c in current_cells:
		var p := c + current_pos
		if p.y < 0:
			_end_game()
			return
		board[p.y * columns + p.x] = current_type
	var cleared := _clear_lines()
	if cleared > 0:
		score += score_table[mini(cleared, score_table.size() - 1)] * level
		lines += cleared
		level = lines / lines_per_level + 1
	_spawn()


func _clear_lines() -> int:
	var cleared := 0
	var y := rows - 1
	while y >= 0:
		var full := true
		for x in columns:
			if board[y * columns + x] == -1:
				full = false
				break
		if full:
			for yy in range(y, 0, -1):
				for x in columns:
					board[yy * columns + x] = board[(yy - 1) * columns + x]
			for x in columns:
				board[x] = -1
			cleared += 1
		else:
			y -= 1
	return cleared


func _matches(event: InputEvent, actions: Array[StringName], allow_echo: bool = false) -> bool:
	for action in actions:
		if InputMap.has_action(action) and event.is_action_pressed(action, allow_echo):
			return true
	return false


func _fast_held() -> bool:
	for action in fast_actions:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false


func _process(delta: float) -> void:
	if page != Page.GAME or not is_visible_in_tree():
		return
	if game_view != null:
		game_view.queue_redraw()
	if state != State.PLAYING:
		return
	var interval := maxf(min_fall_interval, base_fall_interval - (level - 1) * level_speedup)
	var soft_dropping := _fast_held()
	if soft_dropping:
		interval = minf(interval, soft_drop_interval)
		gravity_timer = minf(gravity_timer, interval)
	gravity_timer += minf(delta, max_frame_delta)
	while gravity_timer >= interval:
		gravity_timer -= interval
		if _try_move(Vector2i(0, 1)):
			lock_resets = 0
			lock_timer = 0.0
			if soft_dropping:
				score += soft_drop_score
		else:
			gravity_timer = 0.0
			break
	if _collides(current_cells, current_pos + Vector2i(0, 1)):
		lock_timer += delta
		if lock_timer >= lock_delay:
			_lock()
	else:
		lock_timer = 0.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _matches(event, back_actions):
		if page != Page.MENU:
			show_page(Page.MENU)
			get_viewport().set_input_as_handled()
		return
	if page != Page.GAME:
		return
	if state == State.OVER:
		if _matches(event, restart_actions):
			start_game()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == pause_key:
		state = State.PAUSED if state == State.PLAYING else State.PLAYING
		get_viewport().set_input_as_handled()
		return
	if state != State.PLAYING:
		return
	if _matches(event, left_actions, true):
		if _try_move(Vector2i(-1, 0)):
			_on_moved()
	elif _matches(event, right_actions, true):
		if _try_move(Vector2i(1, 0)):
			_on_moved()
	elif _matches(event, rotate_actions):
		_rotate(true)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == rotate_ccw_key:
		_rotate(false)
	elif _matches(event, hard_drop_actions):
		_hard_drop()
	else:
		return
	get_viewport().set_input_as_handled()


func _cell_px() -> float:
	if auto_fit:
		return maxf(4.0, minf(game_view.size.y / (rows + 1.0), game_view.size.x / (columns + 7.5)))
	return cell_size


func draw_cell(pos: Vector2, cs: float, color: Color) -> void:
	game_view.draw_rect(Rect2(pos + Vector2.ONE, Vector2(cs - 2.0, cs - 2.0)), color)
	game_view.draw_rect(Rect2(pos + Vector2.ONE, Vector2(cs - 2.0, maxf(2.0, cs * 0.15))), color.lightened(0.35))


func draw_game() -> void:
	var cs := _cell_px()
	var board_size := Vector2(cs * columns, cs * rows)
	var panel_w := cs * 6.0
	var gap := cs * 0.5
	var total_w := board_size.x + gap + panel_w
	var origin := Vector2((game_view.size.x - total_w) * 0.5, (game_view.size.y - board_size.y) * 0.5)
	var font := ThemeDB.fallback_font
	var fs := maxi(8, int(cs * font_scale))

	game_view.draw_rect(Rect2(origin, board_size), board_color)
	for gx in range(1, columns):
		game_view.draw_line(origin + Vector2(gx * cs, 0.0), origin + Vector2(gx * cs, board_size.y), grid_color)
	for gy in range(1, rows):
		game_view.draw_line(origin + Vector2(0.0, gy * cs), origin + Vector2(board_size.x, gy * cs), grid_color)

	for by in rows:
		for bx in columns:
			var t: int = board[by * columns + bx]
			if t != -1:
				draw_cell(origin + Vector2(bx, by) * cs, cs, piece_colors[t])

	if state != State.OVER:
		var gp := current_pos
		while not _collides(current_cells, gp + Vector2i(0, 1)):
			gp.y += 1
		var gc: Color = piece_colors[current_type]
		gc.a = ghost_alpha
		for c in current_cells:
			var gpp := c + gp
			if gpp.y >= 0:
				draw_cell(origin + Vector2(gpp) * cs, cs, gc)
		for c in current_cells:
			var cp := c + current_pos
			if cp.y >= 0:
				draw_cell(origin + Vector2(cp) * cs, cs, piece_colors[current_type])

	var px := origin.x + board_size.x + gap
	var ty := origin.y + fs
	game_view.draw_string(font, Vector2(px, ty), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	var box := Rect2(Vector2(px, ty + cs * 0.4), Vector2(cs * 5.0, cs * 3.5))
	game_view.draw_rect(box, board_color)
	var next_cells := _base_cells(next_type)
	var min_c := Vector2i(99, 99)
	var max_c := Vector2i(-99, -99)
	for c in next_cells:
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var shape_px := Vector2(max_c - min_c + Vector2i.ONE) * cs
	var shape_origin := box.position + (box.size - shape_px) * 0.5
	for c in next_cells:
		draw_cell(shape_origin + Vector2(c - min_c) * cs, cs, piece_colors[next_type])

	var sy := box.end.y + cs * 1.2
	var step := cs * 1.7
	var labels := ["SCORE", "LINES", "LEVEL", "BEST"]
	var values := [score, lines, level, high_score]
	for i in labels.size():
		game_view.draw_string(font, Vector2(px, sy + step * i), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color.darkened(0.35))
		game_view.draw_string(font, Vector2(px, sy + step * i + fs * 1.1), str(values[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	if state != State.PLAYING:
		game_view.draw_rect(Rect2(origin, board_size), Color(0.0, 0.0, 0.0, 0.6))
		var msg := "PAUSED" if state == State.PAUSED else "GAME OVER"
		var big := int(fs * 1.4)
		game_view.draw_string(font, origin + Vector2(0.0, board_size.y * 0.45), msg, HORIZONTAL_ALIGNMENT_CENTER, board_size.x, big, text_color)
		if state == State.OVER:
			game_view.draw_string(font, origin + Vector2(0.0, board_size.y * 0.45 + big * 1.6), "PRESS ENTER", HORIZONTAL_ALIGNMENT_CENTER, board_size.x, fs, text_color.darkened(0.2))
