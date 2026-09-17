extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

var _state: GameStateScript


func before_each() -> void:
	_state = GameStateScript.new()
	add_child_autofree(_state)


func test_phase_name_maps_enum_keys_to_lowercase() -> void:
	assert_eq(_state.phase_name(GameStateScript.Phase.LOBBY), &"lobby")
	assert_eq(_state.phase_name(GameStateScript.Phase.DISPATCH), &"dispatch")
	assert_eq(_state.phase_name(GameStateScript.Phase.AFTERMATH), &"aftermath")


func test_initial_state_is_lobby_with_defaults() -> void:
	assert_eq(_state.phase, GameStateScript.Phase.LOBBY)
	assert_eq(_state.shift_clock_minutes, GameStateScript.SHIFT_START_MINUTES)
	assert_eq(_state.public_trust, 75)
	assert_eq(_state.station_budget, 10000)


func test_is_phase_matches_string_name() -> void:
	assert_true(_state.is_phase(&"lobby"))


func test_reset_restores_defaults() -> void:
	_state.phase = GameStateScript.Phase.FIELD
	_state.public_trust = 20
	_state.station_budget = 0
	_state.reset()
	assert_eq(_state.phase, GameStateScript.Phase.LOBBY)
	assert_eq(_state.public_trust, 75)
	assert_eq(_state.station_budget, 10000)