extends Node

signal coin_spawned(coin: Node)

var coin_scene: PackedScene
# Coin height offsets relative to ground top (negative = above ground)
# Ground top is at Y=1280, so coins should be above that
var coin_height_offsets: Array[int] = [-200, -250, -300, -350, -400, -500]  # Hovering above ground, all jump-reachable
var last_coin_time: float = 0.0
var next_coin_interval: float = 0.0
var screen_size: Vector2i
var ground_top_y: float = 1280.0  # Ground top Y position

func initialize(coin_scene: PackedScene, screen_size: Vector2i, ground_top_y: float = 1280.0):
	self.coin_scene = coin_scene
	self.screen_size = screen_size
	self.ground_top_y = ground_top_y

func reset():
	last_coin_time = 0.0
	next_coin_interval = randf_range(0.5, 2.0)  # Much more frequent than butterflies

func update(delta: float, current_distance: int) -> Node:
	last_coin_time += delta
	if last_coin_time >= next_coin_interval:
		var coin = spawn_coin(current_distance)
		last_coin_time = 0.0
		next_coin_interval = randf_range(0.5, 2.0)  # Spawn every 0.5-2 seconds
		return coin
	return null

func spawn_coin(current_distance: int) -> Node:
	var coin = coin_scene.instantiate()
	var obs_x: int = screen_size.x + current_distance + 100
	# Position coin above ground at various heights (all jump-reachable)
	# Ground top is at 1600.5, so coins hover above it
	var height_offset = coin_height_offsets[randi() % coin_height_offsets.size()]
	var obs_y: int = int(ground_top_y + height_offset)
	coin.position = Vector2i(obs_x, obs_y)
	coin_spawned.emit(coin)
	return coin
