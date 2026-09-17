## Global typed signal hub. Systems emit and listen here instead of holding direct references.
## Authority: LOCAL (signals never cross the network; replicated state emits them on each peer).
extends Node

@warning_ignore_start("unused_signal")

# --- Shift / phase ---
signal phase_changed(new_phase: StringName)
signal shift_clock_updated(minutes: int)

# --- Dispatch & Calls ---
signal call_received(call_id: StringName)
signal call_ring(call_id: StringName, call_data: CallData)
signal call_connected(call_id: StringName, call_data: CallData)
signal call_missed(call_id: StringName)
signal call_ended(call_id: StringName, reason: StringName)
signal call_assessment_started(call_id: StringName)
signal call_classified(call_id: StringName, verdict: StringName)
signal caller_patience_updated(current: float, max_patience: float)
signal evidence_unlocked(evidence_key: StringName)

# --- Handset & Dialogue ---
signal handset_owner_changed(peer_id: int)
signal dialogue_node_changed(node_id: StringName, speaker: StringName, line: String, choices: Array)
signal dialogue_choice_pinged(peer_id: int, choice_index: int)

# --- Voting ---
signal vote_finished(topic: StringName, result: Variant)

# --- Consequences ---
signal flag_changed(key: StringName, old_value: Variant, new_value: Variant)
signal trait_applied(peer_id: int, trait_id: StringName)

# --- Players ---
signal player_downed(peer_id: int)
signal player_revived(peer_id: int, by_peer: int)
## Bled out while downed: out for the rest of the mission.
signal player_critical(peer_id: int)
signal sanity_changed(peer_id: int, value: float)

# --- Interaction ---
## Emitted on every peer after the host confirmed `peer_id` used `interactable`.
signal interacted(interactable: Node, peer_id: int)

# --- Noise / AI hearing ---
## Host: something made noise audible within `radius` metres (GAMEPLAY §7: walk 4, sprint 10, kick 25, gunshot 60).
signal noise_event(position: Vector3, radius: float, source_peer: int)

# --- Hostiles ---
signal hostile_killed(hostile: Node, by_peer: int)
## A suspect put their hands up and can be arrested (P3-05).
signal suspect_surrendered(hostile: Node)
signal hostage_executed(hostile: Node)

# --- Horror ---
## Host: a player lost sanity (P3-03 SanitySystem applies bands / effects).
signal sanity_damaged(peer_id: int, amount: float, source: StringName)
## Local only: a per-peer hallucination / scare to play (radio_whisper, phantom_steps, phantom_ring, shadow_figure).
signal hallucination(kind: StringName, position: Vector3)
## Host: a player spoke (proximity or radio). Loudness 0..1 (ARCHITECTURE §6.4).
signal voice_noise(peer_id: int, position: Vector3, loudness: float)

@warning_ignore_restore("unused_signal")
