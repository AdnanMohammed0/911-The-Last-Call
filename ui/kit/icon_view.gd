## Vector icon drawn with canvas primitives (24 × 24 design grid, stroked), so icons stay crisp at any size
## and tint with the theme. `IconView.paint()` lets custom controls draw the same icons inline.
## Authority: LOCAL
@tool
class_name IconView
extends Control

const NAMES: PackedStringArray = [
	"home", "play", "users", "gear", "power", "door", "back", "forward", "close", "minimize", "maximize",
	"check", "lock", "search", "cart", "bank", "shield", "heart", "bolt", "bullet", "gun", "mic", "mic_off",
	"radio", "speaker", "phone", "headset", "camera", "mail", "chart", "badge", "user", "pin", "clock", "wifi",
	"battery", "volume", "alert", "info", "star", "car", "medkit", "coffee", "monitor", "folder", "refresh",
	"copy", "target", "eye", "plus", "chevron_down", "chevron_right", "grid", "bell", "cpu", "sofa", "box",
	"trophy", "siren", "file", "keyboard", "globe", "logout", "link", "moon", "arrow_up", "arrow_down",
]

@export var icon: StringName = &"home":
	set(value):
		icon = value
		queue_redraw()
@export var color: Color = Color(0.94, 0.95, 0.96):
	set(value):
		color = value
		queue_redraw()
@export_range(0.5, 4.0, 0.1) var stroke: float = 1.8:
	set(value):
		stroke = value
		queue_redraw()


static func make(icon_name: StringName, icon_size: float = 20.0, tint: Color = Color(0.94, 0.95, 0.96)) -> IconView:
	var view: IconView = IconView.new()
	view.icon = icon_name
	view.color = tint
	view.custom_minimum_size = Vector2(icon_size, icon_size)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var rect: Rect2 = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	paint(self, icon, rect, color, stroke)


## Draw icon `icon_name` into `rect` of canvas item `ci`.
static func paint(ci: CanvasItem, icon_name: StringName, rect: Rect2, tint: Color, stroke_width: float = 1.8) -> void:
	var s: float = rect.size.x / 24.0
	var o: Vector2 = rect.position
	var w: float = maxf(stroke_width * s, 1.0)
	var line: Callable = func(pts: Array) -> void:
		var packed: PackedVector2Array = PackedVector2Array()
		for i: int in range(0, pts.size(), 2):
			var x: float = pts[i]
			var y: float = pts[i + 1]
			packed.append(o + Vector2(x, y) * s)
		ci.draw_polyline(packed, tint, w, true)
	var ring: Callable = func(x: float, y: float, r: float, from: float = 0.0, to: float = TAU) -> void:
		ci.draw_arc(o + Vector2(x, y) * s, r * s, from, to, 32, tint, w, true)
	var dot: Callable = func(x: float, y: float, r: float) -> void:
		ci.draw_circle(o + Vector2(x, y) * s, r * s, tint)
	var fill: Callable = func(pts: Array) -> void:
		var packed: PackedVector2Array = PackedVector2Array()
		for i: int in range(0, pts.size(), 2):
			var x: float = pts[i]
			var y: float = pts[i + 1]
			packed.append(o + Vector2(x, y) * s)
		ci.draw_colored_polygon(packed, tint)
	var box: Callable = func(x: float, y: float, bw: float, bh: float, r: float = 2.0) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		var corners: Array[Vector2] = [Vector2(x + bw - r, y + r), Vector2(x + bw - r, y + bh - r), Vector2(x + r, y + bh - r), Vector2(x + r, y + r)]
		var starts: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
		for c: int in 4:
			for k: int in 5:
				var a: float = starts[c] + PI * 0.5 * k / 4.0
				pts.append(o + (corners[c] + Vector2(cos(a), sin(a)) * r) * s)
		pts.append(pts[0])
		ci.draw_polyline(pts, tint, w, true)
	match icon_name:
		&"home":
			line.call([3, 11, 12, 3.5, 21, 11])
			line.call([5.5, 9.5, 5.5, 20, 18.5, 20, 18.5, 9.5])
			line.call([10, 20, 10, 14, 14, 14, 14, 20])
		&"play":
			fill.call([7, 4.5, 19.5, 12, 7, 19.5])
		&"users":
			ring.call(9, 8, 3.5)
			line.call([2.5, 20, 2.8, 17, 5.5, 14.5, 9, 14.2, 12.5, 14.5, 15.2, 17, 15.5, 20])
			ring.call(16.5, 8.5, 3.0, -PI * 0.6, PI * 0.6)
			line.call([17.5, 14.5, 19.8, 15.5, 21.3, 17.5, 21.5, 20])
		&"gear":
			ring.call(12, 12, 3.2)
			for k: int in 8:
				var a: float = TAU * k / 8.0
				var inner: Vector2 = Vector2(12, 12) + Vector2(cos(a), sin(a)) * 6.2
				var outer: Vector2 = Vector2(12, 12) + Vector2(cos(a), sin(a)) * 9.0
				ci.draw_line(o + inner * s, o + outer * s, tint, w * 1.6, true)
			ring.call(12, 12, 6.6)
		&"power":
			ring.call(12, 13, 7.5, -PI * 0.3, PI * 1.3)
			line.call([12, 3, 12, 12])
		&"door":
			line.call([5, 21, 5, 3.5, 15, 3.5, 15, 21])
			line.call([3, 21, 21, 21])
			dot.call(12, 12.5, 1.1)
		&"back":
			line.call([20, 12, 4.5, 12])
			line.call([10.5, 6, 4.5, 12, 10.5, 18])
		&"forward":
			line.call([4, 12, 19.5, 12])
			line.call([13.5, 6, 19.5, 12, 13.5, 18])
		&"close":
			line.call([6, 6, 18, 18])
			line.call([18, 6, 6, 18])
		&"minimize":
			line.call([6, 12, 18, 12])
		&"maximize":
			box.call(6, 6, 12, 12, 2.0)
		&"check":
			line.call([4.5, 12.5, 9.5, 17.5, 19.5, 6.5])
		&"lock":
			box.call(5, 10.5, 14, 10, 2.0)
			ring.call(12, 9, 4.2, PI, TAU)
			line.call([7.8, 9, 7.8, 10.5])
			line.call([16.2, 9, 16.2, 10.5])
			dot.call(12, 15.5, 1.2)
		&"search":
			ring.call(10.5, 10.5, 6)
			line.call([15, 15, 20.5, 20.5])
		&"cart":
			line.call([2.5, 4, 5.5, 4, 8, 15.5, 18.5, 15.5, 20.5, 7.5, 6.5, 7.5])
			dot.call(9, 19.5, 1.5)
			dot.call(17.5, 19.5, 1.5)
		&"bank":
			line.call([3, 9, 12, 3.5, 21, 9, 3, 9])
			for x: float in [6.0, 10.0, 14.0, 18.0]:
				line.call([x, 11, x, 17.5])
			line.call([3, 20.5, 21, 20.5])
		&"shield":
			line.call([12, 3, 19.5, 6, 19.5, 11.5, 18.5, 15.5, 12, 21, 5.5, 15.5, 4.5, 11.5, 4.5, 6, 12, 3])
		&"heart":
			fill.call([12, 20.5, 4, 12.5, 3, 9, 4.2, 5.8, 7.5, 4.3, 10.3, 5, 12, 7, 13.7, 5, 16.5, 4.3, 19.8, 5.8, 21, 9, 20, 12.5])
		&"bolt":
			fill.call([13.5, 2.5, 5, 13.5, 11, 13.5, 10, 21.5, 19, 10, 13, 10])
		&"bullet":
			fill.call([9, 9, 9.5, 5, 12, 2.5, 14.5, 5, 15, 9])
			fill.call([9, 10, 15, 10, 15, 19, 9, 19])
			fill.call([8.2, 20, 15.8, 20, 15.8, 21.8, 8.2, 21.8])
		&"gun":
			fill.call([2, 9, 17, 9, 17, 8, 19, 8, 19, 9, 22, 9, 22, 12, 13, 12, 12, 14.5, 10.5, 14.5, 10.5, 12.5, 8.5, 12.5, 7, 19, 3.5, 19, 5.5, 12, 2, 12])
		&"mic", &"mic_off":
			box.call(9, 3, 6, 11, 3.0)
			ring.call(12, 10.5, 6.5, 0.15, PI - 0.15)
			line.call([12, 17, 12, 21])
			line.call([8.5, 21, 15.5, 21])
			if icon_name == &"mic_off":
				line.call([4, 3.5, 20, 20.5])
		&"radio":
			box.call(4, 9, 16, 12, 2.0)
			line.call([7, 9, 16.5, 3])
			ring.call(9.5, 15, 2.8)
			line.call([14.5, 13, 17.5, 13])
			line.call([14.5, 16.5, 17.5, 16.5])
		&"speaker", &"volume":
			fill.call([3.5, 9, 7.5, 9, 12.5, 4.5, 12.5, 19.5, 7.5, 15, 3.5, 15])
			ring.call(12.5, 12, 4, -PI * 0.3, PI * 0.3)
			ring.call(12.5, 12, 7.5, -PI * 0.3, PI * 0.3)
		&"phone":
			line.call([6.5, 3.5, 9.5, 3.5, 11, 8, 8.8, 9.6, 10.2, 12.5, 11.8, 14.2, 14.4, 15.2, 16, 13, 20.5, 14.5, 20.5, 17.5, 19, 20.2, 15, 20, 10.5, 17.5, 6.5, 13.5, 4, 9, 3.8, 5.5, 6.5, 3.5])
		&"headset":
			ring.call(12, 12, 8, PI, TAU)
			box.call(3, 12, 4, 7, 1.5)
			box.call(17, 12, 4, 7, 1.5)
			line.call([19, 19, 19, 20.5, 14, 21])
		&"camera":
			box.call(3, 7, 13, 10, 2.0)
			fill.call([16.5, 10, 21, 7.5, 21, 16.5, 16.5, 14])
			dot.call(7, 10, 1.2)
		&"mail":
			box.call(3, 5.5, 18, 13, 2.0)
			line.call([3.5, 6.5, 12, 13, 20.5, 6.5])
		&"chart":
			line.call([3.5, 3.5, 3.5, 20.5, 20.5, 20.5])
			line.call([7, 16, 11, 11, 14, 14, 20, 6.5])
		&"badge":
			var star: Array = []
			for k: int in 10:
				var a: float = -PI * 0.5 + TAU * k / 10.0
				var r: float = 9.5 if k % 2 == 0 else 4.5
				star.append(12.0 + cos(a) * r)
				star.append(12.5 + sin(a) * r)
			star.append(star[0])
			star.append(star[1])
			line.call(star)
		&"user":
			ring.call(12, 8, 4)
			line.call([4, 21, 4.5, 17, 7.5, 14, 12, 13.5, 16.5, 14, 19.5, 17, 20, 21])
		&"pin":
			ring.call(12, 9.5, 6.5, PI * 0.8, PI * 2.2)
			line.call([6.4, 12.5, 12, 21, 17.6, 12.5])
			dot.call(12, 9.5, 2.0)
		&"clock":
			ring.call(12, 12, 8.5)
			line.call([12, 7, 12, 12, 15.5, 14])
		&"wifi":
			ring.call(12, 19, 14, -PI * 0.75, -PI * 0.25)
			ring.call(12, 19, 9.5, -PI * 0.75, -PI * 0.25)
			ring.call(12, 19, 5, -PI * 0.75, -PI * 0.25)
			dot.call(12, 19, 1.4)
		&"battery":
			box.call(2.5, 7, 17, 10, 2.0)
			fill.call([20.5, 10, 21.8, 10, 21.8, 14, 20.5, 14])
			fill.call([5, 9.5, 14.5, 9.5, 14.5, 14.5, 5, 14.5])
		&"alert":
			line.call([12, 3.5, 21.5, 20, 2.5, 20, 12, 3.5])
			line.call([12, 9.5, 12, 14])
			dot.call(12, 17, 1.2)
		&"info":
			ring.call(12, 12, 9)
			line.call([12, 11, 12, 17])
			dot.call(12, 7.5, 1.2)
		&"star":
			var pts: Array = []
			for k: int in 10:
				var a: float = -PI * 0.5 + TAU * k / 10.0
				var r: float = 9.5 if k % 2 == 0 else 4.2
				pts.append(12.0 + cos(a) * r)
				pts.append(12.5 + sin(a) * r)
			fill.call(pts)
		&"car":
			line.call([3, 16, 3, 12, 5.5, 7, 18.5, 7, 21, 12, 21, 16, 3, 16])
			line.call([3, 12, 21, 12])
			dot.call(7, 17.5, 1.8)
			dot.call(17, 17.5, 1.8)
		&"medkit":
			box.call(3, 6.5, 18, 13.5, 2.0)
			line.call([9, 6.5, 9, 4, 15, 4, 15, 6.5])
			line.call([12, 10, 12, 17])
			line.call([8.5, 13.5, 15.5, 13.5])
		&"coffee":
			line.call([4.5, 9, 4.5, 17, 7, 20, 13, 20, 15.5, 17, 15.5, 9, 4.5, 9])
			ring.call(17, 12.5, 3, -PI * 0.5, PI * 0.5)
			line.call([8, 3, 8.8, 6])
			line.call([11.5, 3, 12.3, 6])
		&"monitor":
			box.call(2.5, 4, 19, 12.5, 2.0)
			line.call([12, 16.5, 12, 20])
			line.call([7.5, 20.5, 16.5, 20.5])
		&"folder":
			line.call([3, 6, 3, 19, 21, 19, 21, 8.5, 11.5, 8.5, 9.5, 5.5, 3, 5.5, 3, 6])
		&"refresh":
			ring.call(12, 12, 7.5, -PI * 0.2, PI * 1.5)
			line.call([19.5, 4.5, 19.5, 9.5, 14.5, 9.5])
		&"copy":
			box.call(8, 8, 12, 12, 2.0)
			line.call([16, 6, 16, 4, 4, 4, 4, 16, 6, 16])
		&"target":
			ring.call(12, 12, 7.5)
			line.call([12, 2, 12, 7])
			line.call([12, 17, 12, 22])
			line.call([2, 12, 7, 12])
			line.call([17, 12, 22, 12])
			dot.call(12, 12, 1.4)
		&"eye":
			line.call([2, 12, 6, 7, 12, 5, 18, 7, 22, 12, 18, 17, 12, 19, 6, 17, 2, 12])
			ring.call(12, 12, 3.5)
		&"plus":
			line.call([12, 5, 12, 19])
			line.call([5, 12, 19, 12])
		&"chevron_down":
			line.call([6, 9, 12, 15, 18, 9])
		&"chevron_right":
			line.call([9, 6, 15, 12, 9, 18])
		&"arrow_up":
			line.call([12, 20, 12, 4.5])
			line.call([6, 10.5, 12, 4.5, 18, 10.5])
		&"arrow_down":
			line.call([12, 4, 12, 19.5])
			line.call([6, 13.5, 12, 19.5, 18, 13.5])
		&"grid":
			for gx: float in [3.5, 13.5]:
				for gy: float in [3.5, 13.5]:
					box.call(gx, gy, 7, 7, 1.5)
		&"bell":
			line.call([5, 17, 6.5, 15, 6.5, 10, 8, 6.5, 12, 4.5, 16, 6.5, 17.5, 10, 17.5, 15, 19, 17, 5, 17])
			ring.call(12, 18.5, 2.2, 0.0, PI)
		&"cpu":
			box.call(6, 6, 12, 12, 1.5)
			box.call(9.5, 9.5, 5, 5, 1.0)
			for k: float in [9.0, 12.0, 15.0]:
				line.call([k, 3, k, 6])
				line.call([k, 18, k, 21])
				line.call([3, k, 6, k])
				line.call([18, k, 21, k])
		&"sofa":
			line.call([5, 11, 5, 7, 19, 7, 19, 11])
			line.call([3, 18, 3, 11, 6, 11, 6, 14, 18, 14, 18, 11, 21, 11, 21, 18, 3, 18])
			line.call([5, 18, 5, 20])
			line.call([19, 18, 19, 20])
		&"box":
			line.call([12, 3, 20.5, 7.5, 20.5, 16.5, 12, 21, 3.5, 16.5, 3.5, 7.5, 12, 3])
			line.call([3.5, 7.5, 12, 12, 20.5, 7.5])
			line.call([12, 12, 12, 21])
		&"trophy":
			line.call([7, 4, 17, 4, 17, 9, 15.5, 12.5, 12, 14, 8.5, 12.5, 7, 9, 7, 4])
			ring.call(6, 7.5, 2.5, PI * 0.5, PI * 1.5)
			ring.call(18, 7.5, 2.5, -PI * 0.5, PI * 0.5)
			line.call([12, 14, 12, 18])
			line.call([8, 20.5, 16, 20.5, 15, 18, 9, 18, 8, 20.5])
		&"siren":
			line.call([5.5, 18, 5.5, 12, 7.5, 8, 12, 6.5, 16.5, 8, 18.5, 12, 18.5, 18])
			line.call([3.5, 20.5, 20.5, 20.5, 20.5, 18, 3.5, 18, 3.5, 20.5])
			line.call([12, 2, 12, 3.5])
			line.call([4, 5, 5.2, 6.2])
			line.call([20, 5, 18.8, 6.2])
		&"file":
			line.call([6, 3, 14, 3, 19, 8, 19, 21, 6, 21, 6, 3])
			line.call([14, 3, 14, 8, 19, 8])
			line.call([9, 13, 16, 13])
			line.call([9, 16.5, 16, 16.5])
		&"keyboard":
			box.call(2.5, 6, 19, 12, 2.0)
			for kx: float in [6.0, 9.5, 13.0, 16.5]:
				dot.call(kx, 10, 0.9)
			line.call([7, 14.5, 17, 14.5])
		&"globe":
			ring.call(12, 12, 9)
			ring.call(12, 12, 4, -PI * 0.5, PI * 0.5)
			ring.call(12, 12, 4, PI * 0.5, PI * 1.5)
			line.call([3, 12, 21, 12])
		&"logout":
			line.call([10, 4, 4, 4, 4, 20, 10, 20])
			line.call([9, 12, 20.5, 12])
			line.call([16, 7.5, 20.5, 12, 16, 16.5])
		&"link":
			ring.call(8.5, 15.5, 4, PI * 0.25, PI * 1.25)
			ring.call(15.5, 8.5, 4, -PI * 0.75, PI * 0.25)
			line.call([9, 15, 15, 9])
		&"moon":
			ring.call(12, 12, 8.5, PI * 0.35, PI * 1.9)
			ring.call(16, 8, 6.5, PI * 0.6, PI * 1.35)
		_:
			ring.call(12, 12, 8)
