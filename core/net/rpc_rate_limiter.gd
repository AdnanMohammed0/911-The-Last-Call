## Per-peer, per-key token bucket for RPC spam protection. Keep one instance per receiving node.
## Authority: HOST (instantiate and use on the host side of client → host RPCs)
class_name RpcRateLimiter
extends RefCounted

var _max_per_second: float
var _burst: float
## "peer:key" -> [tokens: float, last_msec: int]
var _buckets: Dictionary[String, Array] = {}


func _init(max_per_second: float = 10.0, burst: float = 5.0) -> void:
	_max_per_second = max_per_second
	_burst = burst


## Consumes one token; false means the call should be dropped.
func allow(peer_id: int, key: StringName = &"") -> bool:
	var id: String = "%d:%s" % [peer_id, key]
	var now: int = Time.get_ticks_msec()
	if not _buckets.has(id):
		_buckets[id] = [_burst, now]
	var bucket: Array = _buckets[id]
	var tokens: float = bucket[0]
	var last: int = bucket[1]
	tokens = minf(_burst, tokens + float(now - last) / 1000.0 * _max_per_second)
	var allowed: bool = tokens >= 1.0
	if allowed:
		tokens -= 1.0
	_buckets[id] = [tokens, now]
	return allowed


func forget_peer(peer_id: int) -> void:
	var prefix: String = "%d:" % peer_id
	for id: String in _buckets.keys():
		if id.begins_with(prefix):
			_buckets.erase(id)
