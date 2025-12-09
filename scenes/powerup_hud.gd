extends CanvasLayer

var progress_bar: ProgressBar
var powerup_name_label: Label
var powerup_manager: Node = null

func _ready():
	# Get or create progress bar
	if has_node("PowerUpProgressBar"):
		progress_bar = $PowerUpProgressBar
	else:
		# Create progress bar if it doesn't exist
		progress_bar = ProgressBar.new()
		progress_bar.name = "PowerUpProgressBar"
		add_child(progress_bar)
		# Position it at the bottom center
		progress_bar.anchors_preset = Control.PRESET_BOTTOM_WIDE
		progress_bar.offset_bottom = -50
		progress_bar.offset_top = -100
		progress_bar.offset_left = 200
		progress_bar.offset_right = -200
	
	# Get or create powerup name label
	if has_node("PowerUpNameLabel"):
		powerup_name_label = $PowerUpNameLabel
	else:
		powerup_name_label = Label.new()
		powerup_name_label.name = "PowerUpNameLabel"
		add_child(powerup_name_label)
		# Position it above the progress bar
		powerup_name_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
		powerup_name_label.offset_bottom = -100
		powerup_name_label.offset_top = -150
		powerup_name_label.offset_left = 200
		powerup_name_label.offset_right = -200
		powerup_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Use retro font if available
		var font = load("res://assets/fonts/retro.ttf")
		if font:
			powerup_name_label.add_theme_font_override("font", font)
		powerup_name_label.add_theme_font_size_override("font_size", 40)
	
	# Hide initially
	hide_powerup_hud()

func initialize(powerup_mgr: Node):
	powerup_manager = powerup_mgr

func _process(_delta: float):
	if not powerup_manager:
		return
	
	var active_powerup = powerup_manager.get_active_powerup()
	if active_powerup and active_powerup.is_active:
		# Show HUD and update progress
		show_powerup_hud()
		update_progress(active_powerup)
	else:
		# Hide HUD when no powerup is active
		hide_powerup_hud()

func update_progress(powerup: PowerUpBase):
	if not powerup or not powerup.is_active:
		return
	
	# Calculate remaining time percentage
	var remaining_time = powerup.duration - powerup.elapsed_time
	var progress = remaining_time / powerup.duration
	
	# Update progress bar (0.0 to 1.0)
	progress_bar.value = progress
	
	# Update label with powerup name and remaining time
	var powerup_display_name = powerup.name.to_upper()
	var time_remaining = int(remaining_time)
	powerup_name_label.text = "%s - %ds" % [powerup_display_name, time_remaining]
	
	# Change color based on remaining time (green -> yellow -> red)
	if progress > 0.5:
		progress_bar.modulate = Color.GREEN
	elif progress > 0.25:
		progress_bar.modulate = Color.YELLOW
	else:
		progress_bar.modulate = Color.RED

func show_powerup_hud():
	progress_bar.visible = true
	powerup_name_label.visible = true

func hide_powerup_hud():
	progress_bar.visible = false
	powerup_name_label.visible = false
