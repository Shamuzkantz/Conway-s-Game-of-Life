extends Node2D
class_name World

@export var matriz_edge_size : int = 32
@export var matriz_max_edge_size : int = 64
@export var cell_size : float = 16.0
@export_range(0.0, 1.0) var starting_alive_cells_percentage : float = 0.5
@export var gap : float = 2.0
@export var manual_start : bool = true
@export var randomize_rulestrings : bool = false
@export var restart_world_manually : bool = true
@export var randomize_alive_cell_color : bool = false
@export var randomize_dead_cell_color : bool = false
@export var movable_camera : MovableCamera
@export var alive_cell_color : Color = Color.STEEL_BLUE
@export var dead_cell_color : Color = Color.DIM_GRAY
@export var world_canvas_layer : WorldCanvasLayer
@export var update_world_timer : Timer
@export var birth_rule_amount : Array[int] = [3]
@export var survive_rule_amount : Array[int] = [2,3]

var cells_rid_list : Array[RID] = []
var alive_cells_indexes : Array[int] = []
var updates : int = 0

func _ready() -> void:
	if randomize_rulestrings:
		set_random_birth_amount_rule(2, 8)
		set_random_survive_amount_rule(2, 8)
	if randomize_alive_cell_color:
		alive_cell_color = Color(randf_range(0.4, 0.8), randf_range(0.4, 0.8), randf_range(0.4, 0.8))
	if randomize_dead_cell_color:
		var random_color_value : float = randf_range(0.1, 0.2)
		#dead_cell_color = Color(randf_range(0.1, 0.2), randf_range(0.1, 0.2), randf_range(0.1, 0.2))
		dead_cell_color = Color(random_color_value, random_color_value, random_color_value)
	world_canvas_layer.matriz_size.text = str(matriz_edge_size) + "x" + str(matriz_edge_size)
	world_canvas_layer.rulestring_label.text = "B" + str(birth_rule_amount).replace("[", "").replace("]", "").replace(", ", "") + "/S" + str(survive_rule_amount).replace("[", "").replace("]", "").replace(", ", "")
	matriz_edge_size = min(matriz_max_edge_size, matriz_edge_size)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_starting_alive_cells_indexes()
	set_world()
	centralize_camera()
	if !manual_start:
		update_world_timer.start()

var t : float = 0.0
func _physics_process(_delta : float) -> void:
	world_canvas_layer.fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
	if !restart_world_manually:
		t += _delta
		if t >= 5.0 || ((alive_cells_indexes.size() == 0 || updates < 20) && t >= 0.8):
			set_physics_process(false)
			get_tree().call_deferred("reload_current_scene")

func _input(_event : InputEvent) -> void:
	if Input.is_action_pressed("update_world"):
		update_world()
	if Input.is_action_just_pressed("reset_world"):
		get_tree().call_deferred("reload_current_scene")
	if Input.is_action_pressed("set_timer"):
		if update_world_timer.is_stopped():
			update_world_timer.start()
		else:
			update_world_timer.stop()

func set_starting_alive_cells_indexes() -> void:
	var alive_cells_amount : int = int(matriz_edge_size**2*starting_alive_cells_percentage)
	var max_index : int = matriz_edge_size**2-1
	var indexes : Array[int] = []
	while indexes.size() < alive_cells_amount:
		var random_index : int = randi_range(0, max_index)
		if !(random_index in indexes):
			indexes.append(random_index)
	alive_cells_indexes.append_array(indexes)

func set_world() -> void:
	var global_index : int = 0
	for y : int in range(matriz_edge_size):
		for x : int in range(matriz_edge_size):
			var sprite_instance : RID = RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(sprite_instance, get_canvas_item())
			if global_index in alive_cells_indexes:
				RenderingServer.canvas_item_add_rect(sprite_instance, Rect2(get_cell_position(x, y), Vector2(cell_size, cell_size)), alive_cell_color)
			else:
				RenderingServer.canvas_item_add_rect(sprite_instance, Rect2(get_cell_position(x, y), Vector2(cell_size, cell_size)), dead_cell_color)
			cells_rid_list.append(sprite_instance)
			global_index += 1

func centralize_camera() -> void:
	movable_camera.global_position = Vector2(
		((matriz_edge_size/2.0) * cell_size) + ((matriz_edge_size/2.0) * gap) - gap/2.0,
		((matriz_edge_size/2.0) * cell_size) + ((matriz_edge_size/2.0) * gap) - gap/2.0
	)

func update_world() -> void:
	var actual_generation_updates : int = 0
	if alive_cells_indexes.size() == 0:
		return
	var new_dead_cells_indexes : Array[int] = []
	var dead_cells_analysis : Dictionary = {}
	var directions : Array[int] = [
		-matriz_edge_size-1, -matriz_edge_size, -matriz_edge_size+1,
		-1,+1,
		matriz_edge_size-1, matriz_edge_size, matriz_edge_size+1,
	]
	
	# Checagem de células vizinhas
	for index : int in alive_cells_indexes:
		var alive_neighbors : int = 0
		@warning_ignore("unused_variable")
		var dead_neighbors : int = 8
		for direction : int in directions:
			if index % matriz_edge_size == 0 and direction in [directions[0], directions[3], directions[5]]:
				continue
			if index % matriz_edge_size == matriz_edge_size-1 and direction in [directions[2], directions[4], directions[7]]:
				continue
			var neighbor_index : int = index + direction
			if neighbor_index in alive_cells_indexes:
				alive_neighbors += 1
				dead_neighbors -= 1
			elif neighbor_index >= 0 and neighbor_index < matriz_edge_size**2:
				if dead_cells_analysis.has(neighbor_index):
					dead_cells_analysis.set(neighbor_index, dead_cells_analysis.get(neighbor_index)+1)
				else:
					dead_cells_analysis.set(neighbor_index, 1)
		if !(alive_neighbors in survive_rule_amount):
			actual_generation_updates = true
			new_dead_cells_indexes.append(index)
			RenderingServer.canvas_item_clear(cells_rid_list[index])
			RenderingServer.canvas_item_add_rect(cells_rid_list[index], Rect2(get_cell_position_by_index(index), Vector2(cell_size, cell_size)), dead_cell_color)
	
	# Retirando as células que não passaram nas regras de sobrevivência
	for index : int in new_dead_cells_indexes:
		alive_cells_indexes.erase(index)
	
	# Checangem células que atendam às regras de nascimento
	for index : int in dead_cells_analysis:
		if dead_cells_analysis[index] in birth_rule_amount:
			actual_generation_updates += 1
			alive_cells_indexes.append(index)
			RenderingServer.canvas_item_clear(cells_rid_list[index])
			RenderingServer.canvas_item_add_rect(cells_rid_list[index], Rect2(get_cell_position_by_index(index), Vector2(cell_size, cell_size)), alive_cell_color)
	updates = actual_generation_updates

func get_cell_position(_x : int, _y : int) -> Vector2:
	return Vector2(
		((_x) * cell_size) + ((_x) * gap),
		((_y) * cell_size) + ((_y) * gap)
	)

func get_cell_position_by_index(_index : int) -> Vector2:
	var x : int = _index % matriz_edge_size
	var y : int = int(_index / float(matriz_edge_size))
	return get_cell_position(x, y)

func _exit_tree() -> void:
	for sprite_instance : RID in cells_rid_list:
		RenderingServer.free_rid(sprite_instance)

func _on_update_world_timer_timeout() -> void:
	update_world()

func show_alive_cells_indexes_info() -> void:
	print("Size: " + str(alive_cells_indexes.size()))
	print(alive_cells_indexes)

func set_random_birth_amount_rule(_min : int = 2, _max : int = 8) -> void:
	birth_rule_amount = []
	var random_min : int = randi_range(_min, _max)
	var random_max : int = randi_range(random_min, _max)
	
	for c : int in range((random_max-random_min)+1):
		birth_rule_amount.append(random_min+c)
		if c == 2:
			break

func set_random_survive_amount_rule(_min : int = 2, _max : int = 8) -> void:
	survive_rule_amount = []
	var random_min : int = randi_range(_min, _max)
	var random_max : int = randi_range(random_min, _max)
	
	for c : int in range((random_max-random_min)+1):
		survive_rule_amount.append(random_min+c)
