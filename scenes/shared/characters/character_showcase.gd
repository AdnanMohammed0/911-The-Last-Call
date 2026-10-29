## Run this scene to inspect the seven mission character looks in the same night lighting.
extends Node3D

const LOOKS: Array[StringName] = [&"tech", &"profiler", &"breacher", &"medic",
	&"thug", &"cultist_gunman", &"ambush_leader"]
const LABELS: Array[String] = ["TECH", "PROFILER", "BREACHER", "MEDIC", "THUG", "CULTIST", "LEADER"]


func _ready() -> void:
	for i: int in LOOKS.size():
		var pedestal: Node3D = Node3D.new()
		pedestal.name = "Look_%s" % LOOKS[i]
		pedestal.position = Vector3((3.0 - float(i)) * 1.7, 0.0, 0.0)
		add_child(pedestal)
		var rig: HumanoidRig = HumanoidRig.new()
		rig.name = "Rig"
		rig.dress(LOOKS[i], {"armband": ClassCatalog.get_data(LOOKS[i]).color} if i < 4 else {})
		pedestal.add_child(rig)
		var label: Label3D = Label3D.new()
		label.name = "Caption"
		label.text = LABELS[i]
		label.font_size = 64
		label.pixel_size = 0.004
		label.modulate = Color(0.85, 0.91, 0.92)
		label.position = Vector3(0, 2.05, 0)
		label.rotation_degrees.y = 180.0
		pedestal.add_child(label)
