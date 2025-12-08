extends CanvasLayer

var event_label: Label
var timing_label: Label
var label_settings: LabelSettings
var timer: float = 0.0
var showing_event: bool = false
var showing_outcome: bool = false
const EVENT_DISPLAY_DURATION: float = 2.0

func _ready():
	event_label = $EventLabel
	event_label.visible = false
	
	# Get TimingLabel if it exists
	if has_node("TimingLabel"):
		timing_label = $TimingLabel
		timing_label.visible = false
	else:
		# TimingLabel doesn't exist, create it
		timing_label = Label.new()
		timing_label.name = "TimingLabel"
		add_child(timing_label)
		# Position it below EventLabel
		timing_label.anchors_preset = Control.PRESET_CENTER
		timing_label.offset_top = -200.0
		timing_label.offset_left = -150.0
		timing_label.offset_right = 150.0
		timing_label.offset_bottom = -150.0
		timing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Use same font settings as EventLabel
		var timing_font = event_label.get_theme_font("font")
		var timing_font_size = event_label.get_theme_font_size("font_size")
		timing_label.add_theme_font_override("font", timing_font)
		timing_label.add_theme_font_size_override("font_size", timing_font_size)
		timing_label.visible = false

	# Create LabelSettings for text outline
	# Get the font and font size from the theme overrides
	var font = event_label.get_theme_font("font")
	var font_size = event_label.get_theme_font_size("font_size")

	label_settings = LabelSettings.new()
	label_settings.font = font
	label_settings.font_size = font_size
	label_settings.outline_size = 8
	label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
	event_label.label_settings = label_settings

func _process(delta: float):
	if showing_event:
		timer -= delta
		if timer <= 0.0:
			hide_event()
			showing_event = false

	if showing_outcome:
		timer -= delta
		if timer <= 0.0:
			hide_outcome()
			showing_outcome = false

func show_special_event():
	# Show "Special Event!" for 2 seconds
	event_label.text = "SPECIAL EVENT"
	event_label.modulate = Color.WHITE
	label_settings.outline_size = 8
	label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
	event_label.visible = true
	showing_event = true
	timer = EVENT_DISPLAY_DURATION

func hide_event():
	event_label.visible = false
	showing_event = false

func show_outcome(outcome_type: String, time_seconds: float = -1.0):
	# Stop showing event message if it's still active
	if showing_event:
		showing_event = false

	# Hide timing label by default
	if timing_label:
		timing_label.visible = false

	# Show outcome message
	match outcome_type:
		"miss":
			event_label.text = "Too Slow"
			event_label.modulate = Color(0.3, 0.3, 0.3)  # Dark grey
			label_settings.outline_size = 8
			label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
		"nice":
			event_label.text = "Nice!"
			event_label.modulate = Color.GREEN
			label_settings.outline_size = 8
			label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
			# Show timing only for correct answers
			# Subtract 1.0 second because the sprite actually entered view 1 second earlier
			# than when on_sprite_entered_view() is called
			if timing_label and time_seconds >= 0.0:
				var adjusted_time = max(0.0, time_seconds - 1.0)
				var time_text = "%.2f sec" % adjusted_time
				timing_label.text = time_text
				timing_label.visible = true
				# Apply same label settings for consistency
				var timing_label_settings = LabelSettings.new()
				var font = timing_label.get_theme_font("font")
				var font_size = timing_label.get_theme_font_size("font_size")
				timing_label_settings.font = font
				timing_label_settings.font_size = font_size
				timing_label_settings.outline_size = 8
				timing_label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
				timing_label.label_settings = timing_label_settings
		"oops":
			event_label.text = "Oops!"
			event_label.modulate = Color.RED
			label_settings.outline_size = 8
			label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
		"too_early":
			event_label.text = "Too Early!"
			event_label.modulate = Color.ORANGE
			label_settings.outline_size = 8
			label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline

	event_label.visible = true
	showing_outcome = true
	timer = EVENT_DISPLAY_DURATION  # Show for 2 seconds

func hide_outcome():
	event_label.visible = false
	if timing_label:
		timing_label.visible = false
	showing_outcome = false
