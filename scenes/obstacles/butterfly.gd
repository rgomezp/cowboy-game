extends AnimatedSprite2D

var is_destroyed: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect to animation finished signal to remove after destroy animation
	animation_finished.connect(_on_animation_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var main_scene = get_tree().current_scene
	if main_scene and "speed" in main_scene:
		# Move the parent Area2D instead of just the sprite
		get_parent().position.x -= main_scene.speed / 10

func _disable_collisions():
	# Helper function to disable collisions after signal completes
	var parent = get_parent()
	if parent is Area2D:
		parent.monitoring = false
		parent.monitorable = false
		# Disable main collision shape
		if parent.has_node("CollisionShape2D"):
			parent.get_node("CollisionShape2D").disabled = true
		# Disable top collision
		if parent.has_node("TopCollision"):
			var top_collision = parent.get_node("TopCollision")
			if top_collision is Area2D:
				top_collision.monitoring = false
				top_collision.monitorable = false

func destroy():
	if is_destroyed:
		return

	is_destroyed = true
	# Defer disabling collisions to avoid flushing queries error
	call_deferred("_disable_collisions")

	# Play the destroy animation
	play("destroy")

func _on_animation_finished():
	# When destroy animation finishes, remove the butterfly
	if is_destroyed and animation == "destroy":
		# Remove the parent Area2D (which contains this sprite)
		var parent = get_parent()
		if parent:
			parent.queue_free()
