extends Area2D

var is_collected: bool = false
var coin_sound: AudioStreamPlayer = null

func _ready() -> void:
	# Ensure monitoring is enabled for collision detection
	monitoring = true
	monitorable = true
	# Connect collision signal directly
	body_entered.connect(_on_body_entered)
	
	# Load coin sound
	var coin_stream = load("res://assets/audio/effects/coin.mp3")
	if coin_stream:
		coin_sound = AudioStreamPlayer.new()
		add_child(coin_sound)
		coin_sound.stream = coin_stream
		coin_sound.volume_db = -10.5  # 70% volume reduction (30% of original volume)
		print("[Coin] Coin sound loaded")
	else:
		print("[Coin] WARNING: Could not load coin.mp3")

func _on_body_entered(body: Node):
	# Don't process if already collected
	if is_collected:
		return

	# Check if body is the player (CharacterBody2D)
	if not body is CharacterBody2D:
		return

	# Immediately mark as collected and disable collisions to prevent double collection
	is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	# Disconnect signal to prevent multiple triggers
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

	collect()

func collect():
	if is_collected and monitoring == false:
		return

	# Mark as collected immediately (already done in _on_body_entered, but ensure it)
	is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Get the main scene to access managers
	var main_scene = get_tree().current_scene
	if not main_scene:
		return

	# Add 10 points to score (10 * 100 = 1000 raw score for display)
	if "score_manager" in main_scene and main_scene.score_manager:
		main_scene.score_manager.add_score(10 * 100, true)  # Show delta for bonus event

	# Play coin collection sound
	if coin_sound and coin_sound.stream:
		coin_sound.play()
		print("[Coin] Playing coin collection sound")

	# Trigger the collected animation and wait for it to finish
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite:
		# Make sure coin is visible and sprite is visible
		visible = true
		animated_sprite.visible = true
		# Stop any current animation
		animated_sprite.stop()
		# Play the collected animation
		animated_sprite.play("collected")
		# Wait for animation to finish
		await animated_sprite.animation_finished

	# Remove from manager AFTER animation finishes
	# This ensures the coin stays visible during the animation
	if "coin_manager" in main_scene and main_scene.coin_manager:
		main_scene.coin_manager.remove_coin(self)

	# Free the coin after everything is done
	if is_instance_valid(self):
		queue_free()
