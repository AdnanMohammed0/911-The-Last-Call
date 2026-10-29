## Host-timed scripted RPG strike on an unmanned decoy cruiser.
class_name HighwayRpgSetPiece
extends Node3D

const CRUISER_LOSS: int = 3000
const STRIKE_DELAY: float = 6.0

@export var trigger: Area3D
@export var cruiser: Node3D
@export var projectile: Node3D
@export var blast: Node3D
@export var launch_point: Marker3D

var _armed: bool = false
var _resolved: bool = false
var _diverted: bool = false


func _ready() -> void:
	if trigger != null:
		trigger.body_entered.connect(_on_body_entered)
	if projectile != null:
		projectile.visible = false
	if blast != null:
		blast.visible = false


func is_armed() -> bool:
	return _armed


func is_resolved() -> bool:
	return _resolved


func was_diverted() -> bool:
	return _diverted


func _on_body_entered(body: Node3D) -> void:
	if multiplayer.is_server() and body is Player:
		arm()


func arm() -> void:
	if not multiplayer.is_server() or _armed:
		return
	_sync_armed.rpc()
	get_tree().create_timer(STRIKE_DELAY).timeout.connect(_strike, CONNECT_ONE_SHOT)


func divert_cruiser() -> void:
	if not multiplayer.is_server() or not _armed or _resolved or _diverted:
		return
	_sync_divert.rpc()


func _strike() -> void:
	if not multiplayer.is_server() or _resolved:
		return
	var hit: bool = not _diverted
	if hit:
		GameState.modify_station_budget(-CRUISER_LOSS)
	FlagSystem.record_event(&"decoy_cruiser_destroyed" if hit else &"decoy_cruiser_saved",
		{"call": MissionDirector.mission_call_id})
	_sync_strike.rpc(hit)


@rpc("authority", "call_local", "reliable")
func _sync_armed() -> void:
	_armed = true
	MissionDirector.announcement.emit("RPG TEAM SPOTTED", "The empty cruiser is in their sights. Tech can divert it now.")


@rpc("authority", "call_local", "reliable")
func _sync_divert() -> void:
	_diverted = true
	if cruiser != null:
		create_tween().tween_property(cruiser, "position", cruiser.position + Vector3(9.0, 0.0, 0.0), 1.0)
	MissionDirector.announcement.emit("DECOY DIVERTED", "The empty cruiser is off the road.")


@rpc("authority", "call_local", "reliable")
func _sync_strike(hit: bool) -> void:
	_resolved = true
	if projectile != null and launch_point != null and blast != null:
		projectile.global_position = launch_point.global_position
		projectile.visible = true
		var flight: Tween = create_tween()
		flight.tween_property(projectile, "global_position", blast.global_position, 0.45)
		flight.tween_callback(func() -> void:
			projectile.visible = false
			blast.visible = true
			if hit and cruiser != null:
				cruiser.visible = false
				for body: Node in cruiser.find_children("*", "StaticBody3D", true, false):
					for shape: Node in body.find_children("*", "CollisionShape3D", true, false):
						(shape as CollisionShape3D).set_deferred("disabled", true)
			get_tree().create_timer(0.4).timeout.connect(func() -> void: blast.visible = false, CONNECT_ONE_SHOT))
	MissionDirector.announcement.emit("DECOY STRUCK" if hit else "RPG MISSED",
		"Empty cruiser lost — station budget -$3,000" if hit else "Cruiser saved. Flank the gunmen.")
