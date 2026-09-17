## Interactive tactical class card for the lobby.
## Displays role summary, stats, and selection state (Available / Selected by You / Occupied by Peer).
class_name ClassCard
extends PanelContainer

signal class_selected(class_id: StringName)

@export var class_id: StringName = &""

var _data: ClassData = null
var _is_selected: bool = false
var _is_occupied: bool = false
var _occupied_by_name: String = ""

@onready var _title_label: Label = %TitleLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _select_button: Button = %SelectButton
@onready var _status_badge: Label = %StatusBadge
@onready var _header_accent: ColorRect = %HeaderAccent


func _ready() -> void:
	_select_button.pressed.connect(_on_select_pressed)
	if class_id != &"":
		setup_class(class_id)


func setup_class(id: StringName) -> void:
	class_id = id
	_data = ClassCatalog.get_data(id)
	if _data == null:
		return

	if _title_label:
		_title_label.text = _data.display_name.to_upper()
	if _summary_label:
		_summary_label.text = _data.summary
	if _header_accent:
		_header_accent.color = _data.color

	if _stats_label:
		var weapons_text: String = ", ".join(_data.weapon_access)
		_stats_label.text = "HP: %d  |  SANITY: %d\nSPEED: %.2fx  |  SPRINT: %.1fs\nSLOTS: %d  |  WEAPONS: %s" % [
			int(_data.max_health),
			int(_data.max_sanity),
			_data.move_speed_multiplier,
			_data.sprint_duration,
			_data.carry_slots,
			weapons_text.to_upper(),
		]

	refresh_state()


func set_card_state(selected_by_me: bool, occupied: bool, occupant_name: String = "") -> void:
	_is_selected = selected_by_me
	_is_occupied = occupied
	_occupied_by_name = occupant_name
	refresh_state()


func refresh_state() -> void:
	if not is_inside_tree() or _select_button == null:
		return

	if _is_selected:
		_select_button.disabled = true
		_select_button.text = "CLAIMED (YOU)"
		_status_badge.text = "[ SELECTED ]"
		_status_badge.modulate = Color(0.06, 0.85, 0.95, 1)
		modulate = Color(1.1, 1.1, 1.15, 1.0)
	elif _is_occupied:
		_select_button.disabled = true
		_select_button.text = "TAKEN"
		_status_badge.text = "[ %s ]" % _occupied_by_name.to_upper()
		_status_badge.modulate = Color(0.9, 0.4, 0.4, 1)
		modulate = Color(0.7, 0.7, 0.75, 0.8)
	else:
		_select_button.disabled = false
		_select_button.text = "CHOOSE ROLE"
		_status_badge.text = "[ AVAILABLE ]"
		_status_badge.modulate = Color(0.96, 0.62, 0.04, 1)
		modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_select_pressed() -> void:
	class_selected.emit(class_id)
