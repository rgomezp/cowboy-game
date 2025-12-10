extends CanvasLayer

var lives_manager: Node = null
var lives_container: VBoxContainer = null
var life_sprites: Array[Sprite2D] = []

const HEART_IMAGE_PATH = "res://assets/img/miscellaneous/heart.png"
const HEART_SIZE = 50.0
const HEART_SPACING = 10.0

func _ready():
	# Create lives container
	lives_container = VBoxContainer.new()
	lives_container.name = "LivesContainer"
	lives_container.position = Vector2(54, 220)  # Below score value (which ends at ~205)
	add_child(lives_container)
	
	# Initially hide (will show when lives_manager is set)
	lives_container.visible = false

func initialize(lives_mgr: Node):
	lives_manager = lives_mgr
	if lives_manager:
		# Connect to lives changed signal
		if lives_manager.lives_changed.is_connected(_on_lives_changed):
			lives_manager.lives_changed.disconnect(_on_lives_changed)
		lives_manager.lives_changed.connect(_on_lives_changed)
		
		# Update display with current lives
		update_lives_display()
		lives_container.visible = true

func _on_lives_changed(_lives: int):
	update_lives_display()

func update_lives_display():
	if not lives_manager:
		return
	
	var current_lives = lives_manager.get_lives()
	
	# Remove excess sprites
	while life_sprites.size() > current_lives:
		var sprite = life_sprites.pop_back()
		if is_instance_valid(sprite):
			sprite.queue_free()
	
	# Add missing sprites
	while life_sprites.size() < current_lives:
		var sprite = Sprite2D.new()
		var texture = load(HEART_IMAGE_PATH)
		if texture:
			sprite.texture = texture
		sprite.position = Vector2(0, life_sprites.size() * (HEART_SIZE + HEART_SPACING))
		sprite.scale = Vector2(HEART_SIZE / 64.0, HEART_SIZE / 64.0)  # Assuming heart.png is 64x64
		lives_container.add_child(sprite)
		life_sprites.append(sprite)

func reset():
	# Clear all life sprites
	for sprite in life_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	life_sprites.clear()
	
	# Update display (will show 0 lives)
	if lives_manager:
		update_lives_display()
