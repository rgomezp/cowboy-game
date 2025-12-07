extends Node

signal foe_spawned(foe: Node)

var foe_types: Array[PackedScene]
var last_foe_distance: int = 0
var screen_size: Vector2i
var ground_sprite: Sprite2D
var spawning_enabled: bool = true  # Can be disabled for special events

func initialize(foe_scenes: Array[PackedScene], screen_size: Vector2i, ground_sprite: Sprite2D):
	foe_types = foe_scenes
	self.screen_size = screen_size
	self.ground_sprite = ground_sprite

func reset():
	last_foe_distance = 0

func should_spawn_foe(current_distance: int) -> bool:
	var distance_since_last = current_distance - last_foe_distance
	# More sparse than obstacles - spawn every 15000-30000 distance units
	var min_spacing = randi_range(15000, 20000)
	var max_spacing = randi_range(25000, 30000)
	var required_spacing = randi_range(min_spacing, max_spacing)
	return distance_since_last >= required_spacing

func set_spawning_enabled(enabled: bool):
	spawning_enabled = enabled

func is_spawning_enabled() -> bool:
	return spawning_enabled

func update(current_distance: int) -> Node:
	if not spawning_enabled:
		return null
	if should_spawn_foe(current_distance):
		var foe = spawn_foe(current_distance)
		last_foe_distance = current_distance
		return foe
	return null

func spawn_foe(current_distance: int) -> Node:
	var foe_type = foe_types[randi() % foe_types.size()]
	var foe = foe_type.instantiate()
	
	var foe_sprite = foe.get_node("AnimatedSprite2D")
	var foe_sprite_frames = foe_sprite.sprite_frames
	var foe_texture = foe_sprite_frames.get_frame_texture("default", 0)
	var foe_height = foe_texture.get_height()
	var foe_scale = foe_sprite.scale
	var foe_sprite_offset = foe_sprite.position
	
	var ground_top_y = self.ground_sprite.offset.y
	
	# Add some randomness to the x position
	var base_x = screen_size.x + current_distance + 100
	var random_offset = randi_range(-50, 50)
	var foe_x: int = base_x + random_offset
	
	# Position foe on the ground (stationary)
	# Position so the bottom edge sits on top of the ground
	var foe_y: int = ground_top_y - foe_sprite_offset.y - (foe_height * foe_scale.y / 2) + 10
	
	foe.position = Vector2i(foe_x, foe_y)
	foe_spawned.emit(foe)
	return foe
