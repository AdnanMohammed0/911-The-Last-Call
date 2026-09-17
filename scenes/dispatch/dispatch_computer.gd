## A dispatch desk computer: press F to open the CAD terminal on your own screen.
## Authority: HOST validates the interaction; the terminal opens only on the interacting peer.
class_name DispatchComputer
extends Interactable


func _ready() -> void:
	super()
	prompt_text = "Use dispatch computer"
	max_distance = 2.2
	cooldown = 0.3


func _on_interacted(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	var terminal: DispatchTerminal = DispatchTerminal.find(get_tree())
	if terminal != null:
		terminal.open()
