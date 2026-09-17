## Global typed signal hub. Systems emit and listen here instead of holding direct references.
## Authority: LOCAL (signals never cross the network; replicated state emits them on each peer).
extends Node

@warning_ignore_start("unused_signal")

# --- Shift / phase ---
signal phase_changed(new_phase: StringName)

# --- Dispatch ---
signal call_received(call_id: StringName)
signal call_classified(call_id: StringName, verdict: StringName)

# --- Voting ---
signal vote_finished(topic: StringName, result: Variant)

# --- Consequences ---
signal flag_changed(key: StringName, old_value: Variant, new_value: Variant)
signal trait_applied(peer_id: int, trait_id: StringName)

# --- Players ---
signal player_downed(peer_id: int)
signal player_revived(peer_id: int, by_peer: int)
signal sanity_changed(peer_id: int, value: float)

# --- Interaction ---
## Emitted on every peer after the host confirmed `peer_id` used `interactable`.
signal interacted(interactable: Node, peer_id: int)

# --- Voice / AI hearing ---
## Host: a player spoke (proximity or radio). Loudness 0..1 (ARCHITECTURE §6.4).
signal voice_noise(peer_id: int, position: Vector3, loudness: float)

@warning_ignore_restore("unused_signal")
