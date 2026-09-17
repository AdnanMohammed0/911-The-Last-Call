## Local player's health bar, plus the downed / critical overlay with the bleed-out countdown.
## Authority: LOCAL
class_name HealthHud
extends Control

@export var player: Player

@onready var _bar: ProgressBar = %HealthBar
@onready var _overlay: ColorRect = %DownedOverlay
@onready var _status: Label = %DownedLabel


func _process(_delta: float) -> void:
	if player == null:
		return
	var health: HealthComponent = player.get_health()
	_bar.max_value = health.max_hp
	_bar.value = health.hp
	match health.state:
		HealthComponent.State.ALIVE:
			_overlay.visible = false
		HealthComponent.State.DOWNED:
			_overlay.visible = true
			var reviving: String = "\nBeing revived by %s…" % NetManager.get_player_name(health.reviver_peer) if health.reviver_peer != 0 else "\nCall a Medic or a teammate with a Trauma Kit"
			_status.text = "DOWNED — bleeding out in %d s%s" % [ceili(health.bleed_out_remaining), reviving]
		HealthComponent.State.CRITICAL:
			_overlay.visible = true
			_status.text = "CRITICAL — out for the rest of the mission"
