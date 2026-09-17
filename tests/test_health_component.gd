## P3-02: location damage, regeneration steps, downed / bleed-out / revive.
extends GutTest

var _player: Player
var _health: HealthComponent


func before_each() -> void:
	_player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	_player.apply_class(ClassCatalog.get_data(&"medic"))  # 100 HP, 5 % resistance
	add_child_autofree(_player)
	_health = _player.get_health()


func test_class_sets_max_health_and_resistance() -> void:
	var breacher: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	breacher.apply_class(ClassCatalog.get_data(&"breacher"))
	add_child_autofree(breacher)
	assert_eq(breacher.get_health().max_hp, 140.0)
	assert_almost_eq(breacher.get_health().damage_resistance, 0.25, 0.001)


func test_zone_multipliers() -> void:
	assert_almost_eq(_health.apply_damage(10.0, HealthComponent.HitZone.HEAD), 19.0, 0.01)
	assert_almost_eq(_health.apply_damage(10.0, HealthComponent.HitZone.TORSO), 9.5, 0.01)
	assert_almost_eq(_health.apply_damage(10.0, HealthComponent.HitZone.LEG), 7.125, 0.01)


func test_heavy_leg_hit_rolls_limping() -> void:
	var traits: Array[StringName] = []
	var on_trait: Callable = func(_peer: int, trait_id: StringName) -> void: traits.append(trait_id)
	EventBus.trait_applied.connect(on_trait)
	_health.apply_damage(50.0, HealthComponent.HitZone.LEG)
	EventBus.trait_applied.disconnect(on_trait)
	assert_true(&"limping" in traits)


func test_regen_only_to_next_quarter_step() -> void:
	_health.apply_damage(40.0 / 0.95)  # 100 -> 60
	assert_almost_eq(_health.hp, 60.0, 0.01)
	_health._process(HealthComponent.REGEN_DELAY_SEC)
	for i: int in 20:
		_health._process(1.0)
	assert_almost_eq(_health.hp, 75.0, 0.01, "stops at the 75 % step")


func test_zero_hp_goes_down_and_bleeds_out_to_critical() -> void:
	var downed: Array[int] = []
	var on_down: Callable = func(peer: int) -> void: downed.append(peer)
	EventBus.player_downed.connect(on_down)
	_health.apply_damage(500.0)
	EventBus.player_downed.disconnect(on_down)
	assert_eq(_health.state, HealthComponent.State.DOWNED)
	assert_eq(downed.size(), 1)
	_health._process(HealthComponent.BLEED_OUT_SEC + 1.0)
	assert_eq(_health.state, HealthComponent.State.CRITICAL)


func test_bleed_out_pauses_while_being_revived() -> void:
	_health.apply_damage(500.0)
	_health.reviver_peer = 42
	_health._process(30.0)
	assert_almost_eq(_health.bleed_out_remaining, HealthComponent.BLEED_OUT_SEC, 0.01)


func test_revive_restores_forty_percent() -> void:
	_health.apply_damage(500.0)
	_health.revive(7)
	assert_eq(_health.state, HealthComponent.State.ALIVE)
	assert_almost_eq(_health.hp, 40.0, 0.01)


func test_downed_player_crawls_and_cannot_interact() -> void:
	_health.apply_damage(500.0)
	assert_true(_player.get_max_move_speed() <= 4.75, "downed speed cap")
	var interactor: PlayerInteractor = _player.get_node("PlayerInteractor")
	assert_null(interactor._find_target())
