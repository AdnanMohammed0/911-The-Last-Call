## Pure hitscan maths used by the host: ray vs upright capsule, hit zone from hit height, spread cones.
## Authority: any (no state)
class_name Ballistics
extends RefCounted

const TARGET_RADIUS: float = 0.38
const TARGET_HEIGHT: float = 1.8


## Distance along the (normalized) ray to an upright capsule standing at `feet`, or INF on a miss.
static func ray_capsule(origin: Vector3, direction: Vector3, feet: Vector3, radius: float = TARGET_RADIUS, height: float = TARGET_HEIGHT) -> float:
	var a: Vector3 = feet + Vector3(0, radius, 0)
	var b: Vector3 = feet + Vector3(0, height - radius, 0)
	# Closest points between the ray and the capsule axis segment.
	var axis: Vector3 = b - a
	var w0: Vector3 = origin - a
	var aa: float = direction.dot(direction)
	var bb: float = direction.dot(axis)
	var cc: float = axis.dot(axis)
	var dd: float = direction.dot(w0)
	var ee: float = axis.dot(w0)
	var denom: float = aa * cc - bb * bb
	var s: float = 0.0
	var t: float = 0.0
	if denom > 0.00001:
		s = (bb * ee - cc * dd) / denom
		t = (aa * ee - bb * dd) / denom
	else:
		t = ee / cc
	t = clampf(t, 0.0, 1.0)
	s = maxf(direction.dot(a + axis * t - origin) / aa, 0.0)
	var closest_ray: Vector3 = origin + direction * s
	var closest_axis: Vector3 = a + axis * t
	var gap: float = closest_ray.distance_to(closest_axis)
	if gap > radius:
		return INF
	# Step back to the capsule surface along the ray.
	return maxf(s - sqrt(radius * radius - gap * gap), 0.0)


## Hit zone from where on the body the ray struck (height ratio and sideways offset).
static func zone_for_point(feet: Vector3, point: Vector3, facing_yaw: float) -> HealthComponent.HitZone:
	var ratio: float = clampf((point.y - feet.y) / TARGET_HEIGHT, 0.0, 1.0)
	if ratio >= 0.84:
		return HealthComponent.HitZone.HEAD
	if ratio < 0.47:
		return HealthComponent.HitZone.LEG
	var right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, facing_yaw)
	var side: float = absf((point - feet).dot(right))
	return HealthComponent.HitZone.ARM if side > 0.24 else HealthComponent.HitZone.TORSO


## Random direction inside a cone of `half_angle_deg` around `forward` (deterministic for a given rng state).
static func spread_direction(forward: Vector3, half_angle_deg: float, rng: RandomNumberGenerator) -> Vector3:
	if half_angle_deg <= 0.0:
		return forward.normalized()
	var angle: float = deg_to_rad(half_angle_deg) * sqrt(rng.randf())
	var roll: float = rng.randf() * TAU
	var axis: Vector3 = forward.cross(Vector3.UP)
	if axis.length() < 0.001:
		axis = forward.cross(Vector3.RIGHT)
	axis = axis.normalized().rotated(forward.normalized(), roll)
	return forward.normalized().rotated(axis, angle).normalized()
