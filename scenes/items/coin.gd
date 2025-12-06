extends Area2D

var is_collected: bool = false

func _ready() -> void:
	# Ensure monitoring is enabled for collision detection
	monitoring = true
	monitorable = true
	# Connect collision signal directly
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	# Don't process if already collected
	if is_collected:
		return

	# Check if body is the player (CharacterBody2D)
	if not body is CharacterBody2D:
		return

	# Immediately mark as collected and disable collisions to prevent double collection
	is_collected = true
	monitoring = false
	monitorable = false
	# Disconnect signal to prevent multiple triggers
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

	collect()

func collect():
	if is_collected and monitoring == false:
		return

	# Mark as collected immediately (already done in _on_body_entered, but ensure it)
	is_collected = true
	monitoring = false
	monitorable = false

	# Get the main scene to access managers
	var main_scene = get_tree().current_scene
	if not main_scene:
		return

	# Add 10 points to score (10 * 100 = 1000 raw score for display)
	if "score_manager" in main_scene and main_scene.score_manager:
		main_scene.score_manager.add_score(10 * 100, true)  # Show delta for bonus event

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
