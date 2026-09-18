## Trait System — manages persistent traits for all players (GAMEPLAY_MECHANICS §3.4).
## Authority: HOST (trait application/removal validated on host, replicated via RPC).
extends Node

signal trait_applied(peer_id: int, trait_id: StringName)
signal trait_removed(peer_id: int, trait_id: StringName)
signal trait_progress(peer_id: int, trait_id: StringName, shifts_remaining: int)

## Per-player active traits: peer_id -> {trait_id -> {shifts_remaining: int, source_event: String}}
var _player_traits: Dictionary = {}

## Trait catalog (loaded from data/traits/*.tres)
var _trait_catalog: Dictionary[StringName, TraitData] = {}

func _ready() -> void:
	_load_trait_catalog()
	
	# Listen for shift transitions to decrement durations
	EventBus.shift_clock_updated.connect(_on_shift_updated)
	
	# Listen for trait removal events (e.g., from medical leave)
	EventBus.trait_removed.connect(_on_trait_removed_external)


func _load_trait_catalog() -> void:
	var dir: DirAccess = DirAccess.open("res://data/traits/")
	if dir == null:
		push_error("TraitSystem: traits directory not found")
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path: String = "res://data/traits/" + file_name
			var t_data: TraitData = load(path) as TraitData
			if t_data != null and t_data.id != &"":
				_trait_catalog[t_data.id] = t_data
		file_name = dir.get_next()
	dir.list_dir_end()


## Applies a trait to a player (host only).
## Returns true if trait was applied (or refreshed).
func apply(peer_id: int, trait_id: StringName, source_event: StringName = &"", shifts_override: int = -1) -> bool:
	if not multiplayer.is_server():
		return false
	
	var t_data: TraitData = _trait_catalog.get(trait_id, null)
	if t_data == null:
		push_warning("TraitSystem: trait '%s' not found in catalog" % trait_id)
		return false
	
	var player_traits: Dictionary = _player_traits.get(peer_id, {})
	
	# Determine duration
	var duration: int = shifts_override
	if duration == -1:
		duration = t_data.duration_shifts
	
	# Apply or refresh trait
	var existing: Dictionary = player_traits.get(trait_id, {})
	if existing:
		# Refresh duration if new duration is longer
		if duration > existing.shifts_remaining:
			existing.shifts_remaining = duration
			existing.source_event = source_event
	else:
		player_traits[trait_id] = {
			"shifts_remaining": duration,
			"source_event": source_event
		}
	
	_player_traits[peer_id] = player_traits
	
	# Apply stat modifiers to player
	_apply_stat_modifiers(peer_id, t_data, true)
	
	# Notify
	trait_applied.emit(peer_id, trait_id)
	_sync_trait_applied.rpc(peer_id, trait_id, duration, source_event)
	
	return true


## Removes a trait from a player (host only).
## Returns true if trait was removed.
func remove(peer_id: int, trait_id: StringName) -> bool:
	if not multiplayer.is_server():
		return false
	
	var player_traits: Dictionary = _player_traits.get(peer_id, {})
	if not player_traits.has(trait_id):
		return false
	
	var t_data: TraitData = _trait_catalog.get(trait_id, null)
	if t_data != null:
		_apply_stat_modifiers(peer_id, t_data, false)
	
	player_traits.erase(trait_id)
	if player_traits.is_empty():
		_player_traits.erase(peer_id)
	else:
		_player_traits[peer_id] = player_traits
	
	trait_removed.emit(peer_id, trait_id)
	_sync_trait_removed.rpc(peer_id, trait_id)
	
	return true


## Checks if a player has a specific trait.
func has_trait(peer_id: int, trait_id: StringName) -> bool:
	if not _player_traits.has(peer_id):
		return false
	var p_traits: Dictionary = _player_traits[peer_id]
	return p_traits.has(trait_id)


## Gets all active traits for a player.
func get_player_traits(peer_id: int) -> Dictionary:
	var p_traits: Dictionary = _player_traits.get(peer_id, {})
	return p_traits.duplicate()


## Gets remaining shifts for a trait on a player.
func get_shifts_remaining(peer_id: int, trait_id: StringName) -> int:
	if not _player_traits.has(peer_id):
		return 0
	var p_traits: Dictionary = _player_traits[peer_id]
	var t_info: Dictionary = p_traits.get(trait_id, {})
	var rem: int = t_info.get("shifts_remaining", 0)
	return rem


## Gets the trait data for a trait ID.
func get_trait(trait_id: StringName) -> TraitData:
	return _trait_catalog.get(trait_id, null)


## Applies or removes stat modifiers from a player.
func _apply_stat_modifiers(peer_id: int, t_data: TraitData, apply: bool) -> void:
	if t_data.stat_modifiers.is_empty():
		return
	
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		return
	
	var sign_val: float = 1.0 if apply else -1.0
	for key: StringName in t_data.stat_modifiers.keys():
		var val_mod: float = t_data.stat_modifiers[key]
		var modifier: float = val_mod * sign_val
		_apply_modifier(player, key, modifier)


## Applies a single modifier to a player.
func _apply_modifier(player: Player, key: StringName, delta: float) -> void:
	match key:
		&"move_speed":
			player.move_speed_multiplier += delta
		&"noise":
			player.noise_multiplier += delta
		&"sanity_drain":
			# Handled by SanitySystem
			pass
		&"max_health":
			var health: HealthComponent = player.get_health()
			if health != null:
				health.max_hp = maxf(1.0, health.max_hp + delta)
				health.hp = minf(health.hp, health.max_hp)
		&"sanity_drain_mult":
			# Handled by SanitySystem
			pass
		_:
			push_warning("TraitSystem: unknown modifier key '%s'" % key)


## Called when shift clock updates.
func _on_shift_updated(minutes: int) -> void:
	# Only process at shift boundaries (every 360 minutes = 6 hours)
	if minutes % 360 != 0:
		return
	
	for peer_id: int in _player_traits.keys():
		var player_traits: Dictionary = _player_traits[peer_id]
		var to_remove: Array[StringName] = []
		
		for trait_id: StringName in player_traits.keys():
			var data: Dictionary = player_traits[trait_id]
			var shifts: int = data.get("shifts_remaining", 0)
			if shifts > 0:
				shifts -= 1
				data["shifts_remaining"] = shifts
				trait_progress.emit(peer_id, trait_id, shifts)
				
				if shifts <= 0:
					to_remove.append(trait_id)
			# shifts == -1 means permanent/conditional, don't decrement
		
		for trait_id: StringName in to_remove:
			remove(peer_id, trait_id)


## Called when a trait is removed externally (e.g., via medical leave event).
func _on_trait_removed_external(peer_id: int, trait_id: StringName) -> void:
	remove(peer_id, trait_id)


## Resets all traits for a player (e.g., on new campaign).
func reset_player(peer_id: int) -> void:
	if _player_traits.has(peer_id):
		var player_traits: Dictionary = _player_traits[peer_id]
		for trait_id: StringName in player_traits.keys():
			remove(peer_id, trait_id)


## Applies stat modifiers for all active traits on a player (e.g., after respawn).
func reapply_all_modifiers(peer_id: int) -> void:
	if not _player_traits.has(peer_id):
		return
	
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		return
	
	# Reset base multipliers
	player.move_speed_multiplier = 1.0
	player.noise_multiplier = 1.0
	
	# Reapply all traits
	var p_traits: Dictionary = _player_traits[peer_id]
	for trait_id: StringName in p_traits.keys():
		var t_data: TraitData = _trait_catalog.get(trait_id, null)
		if t_data != null:
			_apply_stat_modifiers(peer_id, t_data, true)


@rpc("authority", "call_local", "reliable")
func _sync_trait_applied(peer_id: int, trait_id: StringName, shifts_remaining: int, source_event: StringName) -> void:
	# Clients receive notification
	pass


@rpc("authority", "call_local", "reliable")
func _sync_trait_removed(peer_id: int, trait_id: StringName) -> void:
	# Clients receive notification
	pass


## Returns the full catalog for debugging.
func get_catalog() -> Dictionary:
	return _trait_catalog.duplicate()