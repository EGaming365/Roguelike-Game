extends CanvasLayer

@export var nav_left_actions: Array[StringName] = [&"ui_left", &"move_left"]
@export var nav_right_actions: Array[StringName] = [&"ui_right", &"move_right"]
@export var nav_up_actions: Array[StringName] = [&"ui_up", &"move_up"]
@export var nav_down_actions: Array[StringName] = [&"ui_down", &"move_down"]
@export var select_actions: Array[StringName] = [&"select"]
@export var close_actions: Array[StringName] = [&"ui_cancel", &"interact"]
@export var pause_game: bool = true
@export var close_guard_msec: int = 200
@export var highlight_color: Color = Color(1.0, 0.95, 0.25, 1.0)
@export var highlight_width: float = 3.0
@export var highlight_padding: float = 6.0

@onready var grid: GridContainer = find_child("Grid", true, false) as GridContainer
@onready var app_holder: Control = find_child("AppHolder", true, false) as Control

var apps: Array[AppIcon] = []
var selected_index: int = 0
var active_app: Control = null
var opened_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	opened_msec = Time.get_ticks_msec()

	if pause_game:
		get_tree().paused = true

	if grid == null:
		push_warning("App screen is missing a GridContainer named Grid")
		return

	grid.draw.connect(draw_highlight)
	grid.sort_children.connect(grid.queue_redraw)

	for child in grid.get_children():
		var icon: AppIcon = child as AppIcon
		if icon == null:
			continue
		var index: int = apps.size()
		apps.append(icon)
		icon.mouse_entered.connect(select_index.bind(index))
		icon.pressed.connect(open_app.bind(index))

	grid.queue_redraw()


func _exit_tree() -> void:
	if pause_game:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if matches(event, close_actions):
		if Time.get_ticks_msec() - opened_msec < close_guard_msec:
			return
		get_viewport().set_input_as_handled()
		if active_app != null:
			close_app()
		else:
			close_screen()
		return

	if active_app != null or apps.is_empty():
		return

	if matches(event, nav_left_actions, true):
		move_selection(-1, 0)
	elif matches(event, nav_right_actions, true):
		move_selection(1, 0)
	elif matches(event, nav_up_actions, true):
		move_selection(0, -1)
	elif matches(event, nav_down_actions, true):
		move_selection(0, 1)
	elif matches(event, select_actions):
		open_app(selected_index)
	else:
		return

	get_viewport().set_input_as_handled()


func matches(event: InputEvent, actions: Array[StringName], allow_echo: bool = false) -> bool:
	for action in actions:
		if InputMap.has_action(action) and event.is_action_pressed(action, allow_echo):
			return true
	return false


func move_selection(dx: int, dy: int) -> void:
	var columns: int = maxi(grid.columns, 1)
	var row: int = floori(float(selected_index) / float(columns))
	var column: int = selected_index - row * columns
	var new_column: int = column + dx
	var new_row: int = row + dy

	if new_column < 0 or new_column >= columns or new_row < 0:
		return

	var candidate: int = new_row * columns + new_column
	if candidate >= apps.size():
		if dy != 0 and new_row * columns < apps.size():
			candidate = apps.size() - 1
		else:
			return

	select_index(candidate)


func select_index(index: int) -> void:
	if active_app != null or index < 0 or index >= apps.size():
		return
	selected_index = index
	grid.queue_redraw()


func open_app(index: int) -> void:
	if active_app != null or index < 0 or index >= apps.size():
		return

	selected_index = index
	var icon: AppIcon = apps[index]
	if icon.app_scene == null:
		print("App has no scene assigned: ", icon.app_title)
		return

	var instance: Control = icon.app_scene.instantiate() as Control
	if instance == null:
		push_warning("App scene root must be a Control: " + icon.app_title)
		return

	var holder: Node = app_holder if app_holder != null else self
	holder.add_child(instance)
	active_app = instance

	if instance.has_signal("closed"):
		instance.connect("closed", close_app)

	grid.queue_redraw()


func close_app() -> void:
	if active_app != null and is_instance_valid(active_app):
		active_app.queue_free()
	active_app = null
	grid.queue_redraw()


func close_screen() -> void:
	queue_free()


func draw_highlight() -> void:
	if active_app != null or selected_index < 0 or selected_index >= apps.size():
		return
	var rect: Rect2 = apps[selected_index].get_rect().grow(highlight_padding)
	grid.draw_rect(rect, highlight_color, false, highlight_width)
