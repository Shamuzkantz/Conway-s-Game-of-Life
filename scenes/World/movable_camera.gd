extends Camera2D
class_name MovableCamera

@export var camera_speed : float = 2.0
@export var zoom_force : float = 1.1
@export var max_zoom : float = 5.0
@export var min_zoom : float = 0.25

func _physics_process(_delta : float) -> void:
	if Input.is_action_pressed("up"):
		global_position.y -= camera_speed *_delta * 60.0
	if Input.is_action_pressed("down"):
		global_position.y += camera_speed *_delta * 60.0
	if Input.is_action_pressed("left"):
		global_position.x -= camera_speed *_delta * 60.0
	if Input.is_action_pressed("right"):
		global_position.x += camera_speed *_delta * 60.0
	if Input.is_action_just_pressed("zoom_in"):
		var actual_zoom : float = zoom.x
		actual_zoom = min(actual_zoom * zoom_force, max_zoom)
		zoom = Vector2(actual_zoom, actual_zoom)
	if Input.is_action_just_pressed("zoom_out"):
		var actual_zoom : float = zoom.x
		actual_zoom = max(actual_zoom * 1/zoom_force, min_zoom)
		zoom = Vector2(actual_zoom, actual_zoom)
