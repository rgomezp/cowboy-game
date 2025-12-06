extends Node

signal butterfly_spawned(butterfly: Node)

var butterfly_scene: PackedScene
var butterfly_heights: Array[int] = [150, -300]
var last_butterfly_time: float = 0.0
var next_butterfly_interval: float = 0.0
var screen_size: Vector2i

func initialize(butterfly_scene: PackedScene, screen_size: Vector2i):
	self.butterfly_scene = butterfly_scene
	self.screen_size = screen_size

func reset():
	last_butterfly_time = 0.0
	next_butterfly_interval = randf_range(1.0, 5.0)

func update(delta: float, current_distance: int) -> Node:
	last_butterfly_time += delta
	if last_butterfly_time >= next_butterfly_interval:
		var butterfly = spawn_butterfly(current_distance)
		last_butterfly_time = 0.0
		next_butterfly_interval = randf_range(5.0, 15.0)
		return butterfly
	return null

func spawn_butterfly(current_distance: int) -> Node:
	var butterfly = butterfly_scene.instantiate()
	var obs_x: int = screen_size.x + current_distance + 100
	var obs_y: int = butterfly_heights[randi() % butterfly_heights.size()]
	butterfly.position = Vector2i(obs_x, obs_y)
	butterfly_spawned.emit(butterfly)
	return butterfly
