extends Area2D

signal explosion_finished

var is_exploding: bool = false
var main_scene: Node = null
var explosion_sound: AudioStreamPlayer = null

func _ready() -> void:
	# Get main scene reference
	var tree = get_tree()
	if tree:
		main_scene = tree.current_scene
	
	# Load explosion sound
	var explosion_stream = load("res://assets/audio/effects/explosion.mp3")
	if explosion_stream:
		explosion_sound = AudioStreamPlayer.new()
		add_child(explosion_sound)
		explosion_sound.stream = explosion_stream
		explosion_sound.volume_db = -6.0  # Half volume (-6dB is approximately half the perceived volume)
		print("[TNT] Explosion sound loaded")
	else:
		print("[TNT] WARNING: Could not load explosion.mp3")

func trigger_explosion(from_collision: bool = false, apply_bounce: bool = true) -> void:
	# Prevent multiple explosions
	if is_exploding:
		return
	
	is_exploding = true
	
	# Disable collisions immediately
	_disable_collisions()
	
	# Play explosion sound
	if explosion_sound and explosion_sound.stream:
		explosion_sound.play()
		print("[TNT] Playing explosion sound")
	
	# If triggered from player collision, handle player bounce and stop movement
	# Only apply bounce if explicitly requested (for game over scenarios)
	if from_collision and apply_bounce and main_scene:
		_handle_collision_explosion()
	
	# Play explosion animation
	if has_node("AnimatedSprite2D"):
		var animated_sprite = get_node("AnimatedSprite2D")
		if animated_sprite and animated_sprite.sprite_frames:
			if animated_sprite.sprite_frames.has_animation("explosion"):
				# Disable looping for explosion animation
				animated_sprite.sprite_frames.set_animation_loop("explosion", false)
				# Play explosion animation
				animated_sprite.play("explosion")
				
				# Calculate animation duration
				var frame_count = animated_sprite.sprite_frames.get_frame_count("explosion")
				var frame_duration = 0.0
				for i in range(frame_count):
					frame_duration += animated_sprite.sprite_frames.get_frame_duration("explosion", i)
				var animation_speed = animated_sprite.sprite_frames.get_animation_speed("explosion")
				var total_duration = frame_duration / animation_speed if animation_speed > 0 else frame_duration
				
				# Create timer to clean up after animation
				var timer = get_tree().create_timer(total_duration)
				timer.timeout.connect(_on_explosion_animation_finished)
				return
	
	# Fallback: if no animation, clean up immediately
	_on_explosion_animation_finished()

func _handle_collision_explosion() -> void:
	# Stop all movement in main scene
	if main_scene.has_method("set_explosion_in_progress"):
		main_scene.set_explosion_in_progress(true)
	
	# Make player bounce to top left as if exploding out
	if main_scene.has_node("Player"):
		var player = main_scene.get_node("Player")
		var explosion_velocity_up = -2000  # Strong upward force
		var explosion_velocity_left = -800  # Leftward force
		player.velocity.y = explosion_velocity_up
		player.velocity.x = explosion_velocity_left

func _disable_collisions() -> void:
	# Disable all collision detection
	if self is Area2D:
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
	if has_node("CollisionPolygon2D"):
		get_node("CollisionPolygon2D").set_deferred("disabled", true)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)

func _on_explosion_animation_finished() -> void:
	# Emit signal for cleanup
	explosion_finished.emit()
	# Clean up TNT
	queue_free()
