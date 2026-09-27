## A Station OS computer (the main dispatch computer, or a workstation bought in StationMart): press F to
## open the desktop (911 CAD, StationMart, Bank, CCTV…) on your own screen.
## Authority: HOST validates the interaction; the desktop opens only on the interacting peer.
class_name DispatchComputer
extends Interactable


func _ready() -> void:
	super()
	prompt_text = "Use computer (Station OS)"
	max_distance = 2.4
	cooldown = 0.3


func _on_interacted(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	var desktop: StationOS = StationOS.find(get_tree())
	if desktop != null:
		desktop.open()
		return
	var terminal: DispatchTerminal = DispatchTerminal.find(get_tree())
	if terminal != null:
		terminal.open()
