## One effect of a ConsequenceRule (ARCHITECTURE §7.2), applied on the host by FlagSystem.
##   SET_FLAG        key = flag,     value = new value
##   ADD_METER       key = meter,    value = delta (public_trust, station_budget, cult_awareness, or any
##                                                  numeric flag)
##   APPLY_TRAIT     key = trait id, value = shifts (null / -1 = the trait's own duration), target picks
##                                                  the officers
##   QUEUE_CALL      key = call id,  value = delay in shift-clock minutes
##   UNLOCK_MISSION  key = mission,  sets flag mission_unlocked_<key> = true
##   SPAWN_EVENT     key = event id, recorded with the triggering payload (can chain other rules)
class_name FlagEffect
extends Resource

enum Kind { SET_FLAG, ADD_METER, APPLY_TRAIT, QUEUE_CALL, UNLOCK_MISSION, SPAWN_EVENT }

@export var kind: Kind = Kind.SET_FLAG
@export var key: StringName = &""
@export var value: Variant = null
## "" = global; "caller_peer" (payload peer_id), "all_officers", "random_officer".
@export var target: StringName = &""
