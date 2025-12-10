extends Node

signal powerup_activated(powerup_name: String)
signal powerup_deactivated(powerup_name: String)

# Powerup selection and management
var available_powerups: Array[PowerUpBase] = []
var current_powerup: PowerUpBase = null
var powerup_ui: CanvasLayer = null
var lives_manager: Node = null
var is_activating: bool = false  # Track if we're currently activating a powerup

# Selection phase
var is_selecting: bool = false
var selection_timer: float = 0.0
const SELECTION_DURATION: float = 2.0  # 2 seconds of cycling
var current_selection_index: int = 0
var selection_cycle_interval: float = 0.15  # How fast to cycle (every 0.15 seconds)
var last_cycle_time: float = 0.0

# Display phase
var is_displaying: bool = false
var display_timer: float = 0.0
const DISPLAY_DURATION: float = 12.0  # 12 seconds to use powerup

# Blink phase
var is_blinking: bool = false
var blink_timer: float = 0.0
var blink_count: int = 0
const BLINK_DURATION: float = 0.3  # 0.3 seconds per blink
const BLINK_COUNT: int = 5  # 5 blinks

# Selected powerup name
var selected_powerup_name: String = ""

func initialize(powerups: Array[PowerUpBase], ui: CanvasLayer, lives_mgr: Node = null):
	available_powerups = powerups
	powerup_ui = ui
	lives_manager = lives_mgr

func reset():
	# Cancel any active powerup
	if current_powerup and current_powerup.is_active:
		current_powerup.deactivate(get_parent())
		current_powerup = null

	# Reset all states
	is_selecting = false
	is_displaying = false
	is_blinking = false
	selection_timer = 0.0
	display_timer = 0.0
	blink_timer = 0.0
	blink_count = 0
	selected_powerup_name = ""
	current_selection_index = 0
	last_cycle_time = 0.0

	# Hide UI
	if powerup_ui:
		powerup_ui.hide_all_buttons()

func get_available_powerups_for_selection() -> Array[PowerUpBase]:
	# Filter out heart_powerup if player has max lives
	var filtered: Array[PowerUpBase] = []
	for powerup in available_powerups:
		if powerup.name == "heart_powerup":
			if lives_manager and lives_manager.is_at_max():
				continue  # Skip heart_powerup if at max lives
		filtered.append(powerup)
	return filtered

func start_powerup_selection():
	# Start the selection process
	is_selecting = true
	is_displaying = false
	is_blinking = false
	selection_timer = 0.0
	display_timer = 0.0
	blink_timer = 0.0
	blink_count = 0
	current_selection_index = 0
	last_cycle_time = 0.0
	selected_powerup_name = ""

	# Show first powerup button
	if powerup_ui and available_powerups.size() > 0:
		powerup_ui.show_button(available_powerups[0].name)

func update(delta: float, main_node: Node):
	# Update active powerup
	if current_powerup and current_powerup.is_active:
		current_powerup.update(delta, main_node)
		# Check if powerup naturally ended
		if not current_powerup.is_active:
			current_powerup = null
			powerup_deactivated.emit(selected_powerup_name)
			# Clear activation flag when powerup deactivates
			is_activating = false

	# Handle selection phase
	if is_selecting:
		selection_timer += delta
		last_cycle_time += delta

		# Get filtered powerups (excluding heart if at max lives)
		var filtered_powerups = get_available_powerups_for_selection()
		
		# Cycle through powerups
		if last_cycle_time >= selection_cycle_interval and filtered_powerups.size() > 0:
			current_selection_index = (current_selection_index + 1) % filtered_powerups.size()
			if powerup_ui:
				powerup_ui.show_button(filtered_powerups[current_selection_index].name)
			last_cycle_time = 0.0

		# After 2 seconds, select random powerup
		if selection_timer >= SELECTION_DURATION:
			select_random_powerup()

	# Handle display phase
	if is_displaying:
		display_timer += delta

		# After 12 seconds, start blinking
		if display_timer >= DISPLAY_DURATION:
			start_blinking()

	# Handle blink phase
	if is_blinking:
		blink_timer += delta

		# Toggle visibility every BLINK_DURATION (1 second per blink cycle)
		if blink_timer >= BLINK_DURATION:
			blink_count += 1
			blink_timer = 0.0

			if powerup_ui:
				# Toggle button visibility (alternate between visible and invisible)
				var is_visible = (blink_count % 2 == 1)
				powerup_ui.set_button_visible(selected_powerup_name, is_visible)

			# After 5 complete blink cycles (10 toggles = 5 visible + 5 invisible), waste the powerup
			if blink_count >= BLINK_COUNT * 2:
				waste_powerup()

func select_random_powerup():
	# Get filtered powerups (excluding heart if at max lives)
	var filtered_powerups = get_available_powerups_for_selection()
	
	# Select a random powerup from available ones
	if filtered_powerups.size() == 0:
		return

	var random_index = randi() % filtered_powerups.size()
	selected_powerup_name = filtered_powerups[random_index].name

	# Switch to display phase
	is_selecting = false
	is_displaying = true
	display_timer = 0.0

	# Show selected powerup button
	if powerup_ui:
		powerup_ui.show_button(selected_powerup_name)

func start_blinking():
	is_displaying = false
	is_blinking = true
	blink_timer = 0.0
	blink_count = 0

	# Ensure button is visible to start blinking
	if powerup_ui:
		powerup_ui.set_button_visible(selected_powerup_name, true)

func waste_powerup():
	# Powerup was not used in time
	is_blinking = false
	selected_powerup_name = ""

	# Hide UI
	if powerup_ui:
		powerup_ui.hide_all_buttons()

func on_powerup_button_pressed(powerup_name: String):
	# Player pressed a powerup button
	# Allow pressing during display phase or blinking phase
	if powerup_name != selected_powerup_name:
		return  # Wrong powerup
	if not is_displaying and not is_blinking:
		return  # Not the right time
	
	# Prevent activating if we're already in the process of activating
	if is_activating:
		print("[PowerUpManager] Already activating a powerup, ignoring button press")
		return
	
	# Prevent activating if a powerup is already active
	if current_powerup and current_powerup.is_active:
		print("[PowerUpManager] Powerup already active, ignoring button press")
		return

	# Find and activate the powerup
	for powerup in available_powerups:
		if powerup.name == powerup_name:
			activate_powerup(powerup)
			break

func activate_powerup(powerup: PowerUpBase):
	# Prevent double activation
	if is_activating:
		print("[PowerUpManager] Already activating, ignoring duplicate call")
		return
	
	# Set activation flag
	is_activating = true
	
	# Activate the powerup
	current_powerup = powerup
	powerup.activate(get_parent())

	# Hide UI
	if powerup_ui:
		powerup_ui.hide_all_buttons()

	# Reset states
	is_selecting = false
	is_displaying = false
	is_blinking = false
	selected_powerup_name = ""

	powerup_activated.emit(powerup.name)
	
	# Clear activation flag after a short delay to allow instant powerups to complete
	# Use call_deferred to ensure this happens after the activation completes
	call_deferred("_clear_activation_flag")

func is_powerup_active() -> bool:
	return current_powerup != null and current_powerup.is_active

func get_active_powerup() -> PowerUpBase:
	return current_powerup

func get_speed_modifier() -> float:
	if current_powerup and current_powerup.is_active:
		if current_powerup.has_method("get_speed_modifier"):
			return current_powerup.get_speed_modifier()
	return 1.0

func has_unused_powerup() -> bool:
	# Check if there's a powerup that's been selected but not yet activated
	# This includes powerups in display phase or blinking phase
	return is_displaying or is_blinking

func _clear_activation_flag():
	# Clear the activation flag after activation completes
	# This allows instant powerups (like heart) to complete before allowing another activation
	is_activating = false
