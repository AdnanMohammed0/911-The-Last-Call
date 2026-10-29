extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/shared/player/player.tscn")
const SHOWCASE: PackedScene = preload("res://scenes/shared/characters/character_showcase.tscn")


func test_each_officer_class_uses_its_own_animated_look() -> void:
	var details: Dictionary[StringName, String] = {
		&"tech": "TechTablet", &"profiler": "ProfilerBadge",
		&"breacher": "ShoulderPlate1", &"medic": "MedicalCrossVertical",
	}
	for id: StringName in details:
		var player: Player = PLAYER_SCENE.instantiate() as Player
		player.apply_class(ClassCatalog.get_data(id))
		add_child_autofree(player)
		var rig: HumanoidRig = (player.get_node("Body") as PlayerBody).rig
		assert_eq(rig.look_id, id)
		assert_not_null(rig.find_child(details[id], true, false))
		var thigh: MeshInstance3D = rig._parts[&"thigh_-1"]
		assert_not_null(thigh)


func test_three_hostile_variants_have_distinct_attached_details() -> void:
	var details: Dictionary[StringName, String] = {
		&"thug": "JacketZip", &"cultist_gunman": "CultSigilCross",
		&"ambush_leader": "LeaderRank",
	}
	for id: StringName in details:
		var rig: HumanoidRig = HumanoidRig.new()
		rig.dress(id)
		add_child_autofree(rig)
		assert_eq(rig.look_id, id)
		assert_not_null(rig.find_child(details[id], true, false))
		var forearm: MeshInstance3D = rig._parts[&"forearm_1"]
		assert_not_null(forearm)


func test_rig_details_follow_crouch_pose() -> void:
	var rig: HumanoidRig = HumanoidRig.new()
	rig.dress(&"breacher")
	add_child_autofree(rig)
	rig._process(0.1)
	var before: float = rig._chest.position.y
	rig.crouch = 1.0
	rig._process(0.2)
	assert_lt(rig._chest.position.y, before - 0.2)
	assert_not_null(rig.find_child("KneePad1", true, false))


func test_showcase_contains_all_seven_rigs() -> void:
	var showcase: Node3D = SHOWCASE.instantiate() as Node3D
	add_child_autofree(showcase)
	assert_eq(showcase.get_child_count(), 12)
	for id: StringName in [&"tech", &"profiler", &"breacher", &"medic", &"thug", &"cultist_gunman", &"ambush_leader"]:
		assert_not_null(showcase.get_node_or_null("Look_%s/Rig" % id))
