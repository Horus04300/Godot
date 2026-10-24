extends RefCounted

static func polygon(canvas: CanvasItem, points: Array, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points), color)

static func ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in 24:
		points.append(center + Vector2(cos(i * TAU / 24), sin(i * TAU / 24)) * radius)
	canvas.draw_colored_polygon(points, color)

static func chest(canvas: CanvasItem, size: float) -> void:
	var points = [Vector2(-21, -23), Vector2(-3, -32), Vector2(22, -23), Vector2(22, -2), Vector2(3, 9), Vector2(-21, -1)]
	for i in points.size():
		points[i] *= size
	polygon(canvas, points, Color("#3b3026"))
	polygon(canvas, [Vector2(-19, -22) * size, Vector2(-3, -29) * size, Vector2(19, -21) * size, Vector2(2, -12) * size], Color("#b48b50"))
	polygon(canvas, [Vector2(-19, -18) * size, Vector2(1, -10) * size, Vector2(1, 6) * size, Vector2(-19, -2) * size], Color("#78553a"))
	polygon(canvas, [Vector2(4, -10) * size, Vector2(19, -18) * size, Vector2(19, -2) * size, Vector2(4, 6) * size], Color("#523b2e"))
	canvas.draw_polyline(PackedVector2Array([Vector2(-14, -24) * size, Vector2(8, -15) * size, Vector2(8, 3) * size]), Color("#e3b968"), 3 * size)
	canvas.draw_rect(Rect2(Vector2(-2, -13) * size, Vector2(7, 8) * size), Color("#f6d993"))

static func tree(canvas: CanvasItem, variant: int, alpha: float) -> void:
	var ink = Color("#122c28", alpha)
	var bark = Color("#513e30", alpha)
	var leaf = Color("#245544", alpha)
	var light = Color("#4a7950", alpha)
	ellipse(canvas, Vector2(12, 3), Vector2(47, 15), Color(0.04, 0.12, 0.09, alpha * 0.5))
	polygon(canvas, [Vector2(-21, 4), Vector2(-9, -10), Vector2(-8, -75), Vector2(8, -77), Vector2(13, -9), Vector2(26, 7), Vector2(5, 2), Vector2(0, -7), Vector2(-4, 4)], ink)
	polygon(canvas, [Vector2(-13, 0), Vector2(-4, -20), Vector2(-4, -77), Vector2(5, -73), Vector2(7, -12), Vector2(17, 3), Vector2(2, -4)], bark)
	canvas.draw_line(Vector2(-2, -15), Vector2(-1, -67), Color("#936d43", alpha), 3)
	canvas.draw_line(Vector2(0, -40), Vector2(-25, -65), bark, 7)
	canvas.draw_line(Vector2(5, -54), Vector2(24, -79), bark, 6)
	var shift = float(variant % 3) * 5
	polygon(canvas, [Vector2(-53, -67), Vector2(-44, -89), Vector2(-29, -94), Vector2(-34, -110 - shift), Vector2(-13, -131 - shift), Vector2(8, -138 - shift), Vector2(29, -125), Vector2(31, -111), Vector2(49, -103), Vector2(57, -79), Vector2(39, -60), Vector2(12, -57), Vector2(-8, -52), Vector2(-34, -59)], ink)
	polygon(canvas, [Vector2(-48, -77), Vector2(-34, -99), Vector2(-23, -100), Vector2(-25, -112 - shift), Vector2(-9, -129 - shift), Vector2(9, -132 - shift), Vector2(25, -118), Vector2(21, -106), Vector2(45, -99), Vector2(51, -80), Vector2(30, -68), Vector2(9, -71), Vector2(-9, -61), Vector2(-32, -67)], leaf)
	polygon(canvas, [Vector2(-41, -87), Vector2(-23, -106), Vector2(-20, -117), Vector2(-7, -127 - shift), Vector2(10, -126 - shift), Vector2(20, -116), Vector2(1, -111), Vector2(-2, -98), Vector2(-22, -94), Vector2(-27, -84)], light)
	polygon(canvas, [Vector2(14, -101), Vector2(34, -100), Vector2(43, -90), Vector2(25, -83), Vector2(8, -89)], Color("#3c6b47", alpha))
	for i in 7:
		var p = Vector2(-29 + (i * 17 + variant * 9) % 65, -81 - (i * 23) % 37)
		canvas.draw_line(p, p + Vector2(7, -3), Color("#6d9155", alpha * 0.7), 2)

static func character(canvas: CanvasItem, kind: String, phase: float, direction: Vector2, flash: bool = false, alpha: float = 1.0) -> void:
	var ink = Color("#132a28", alpha)
	var pale = Color("#f0ddad", alpha)
	var scale_factor = 1.0
	if kind == "boss":
		scale_factor = 2.1
	elif kind == "brute":
		scale_factor = 1.35
	var side = -1.0 if direction.x < 0 else 1.0
	var step = sin(phase) * 3
	var cloak = Color("#a23e31", alpha) if kind == "hero" else Color("#60744a", alpha)
	var light = Color("#e27045", alpha) if kind == "hero" else Color("#9fa575", alpha)
	if kind == "archer":
		cloak = Color("#4c6558", alpha)
		light = Color("#8ba181", alpha)
	if kind == "crawler":
		cloak = Color("#80523d", alpha)
		light = Color("#b88a5a", alpha)
	if flash:
		cloak = pale
		light = Color.WHITE
	var body = PackedVector2Array([Vector2(-13, -40), Vector2(-9, -54), Vector2(1, -59), Vector2(11, -51), Vector2(12, -40), Vector2(18, -34), Vector2(21, -10), Vector2(6, -14), Vector2(3, -5), Vector2(-16, -7), Vector2(-21, -14), Vector2(-17, -34)])
	for i in body.size():
		body[i] *= scale_factor
	canvas.draw_colored_polygon(body, ink)
	polygon(canvas, [Vector2(-12, -37) * scale_factor, Vector2(0, -43) * scale_factor, Vector2(13, -35) * scale_factor, Vector2(16 + sin(phase * 0.4) * 3, -13) * scale_factor, Vector2(-15, -9) * scale_factor], cloak)
	polygon(canvas, [Vector2(-11, -36) * scale_factor, Vector2(-1, -41) * scale_factor, Vector2(1, -17) * scale_factor, Vector2(-12, -15) * scale_factor], light)
	polygon(canvas, [Vector2(-10, -43) * scale_factor, Vector2(-7, -52) * scale_factor, Vector2(1, -56) * scale_factor, Vector2(9, -50) * scale_factor, Vector2(8, -40) * scale_factor, Vector2(-3, -37) * scale_factor], pale if kind == "hero" else light)
	if direction.y < -0.3:
		canvas.draw_line(Vector2(-2, -53) * scale_factor, Vector2(-3, -41) * scale_factor, Color("#b7b28a", alpha), 2 * scale_factor)
	else:
		polygon(canvas, [Vector2(-5 + side * 2, -47) * scale_factor, Vector2(6 + side * 2, -46) * scale_factor, Vector2(4 + side * 2, -39) * scale_factor, Vector2(-4 + side * 2, -40) * scale_factor], ink)
		canvas.draw_line(Vector2(side * 3, -44) * scale_factor, Vector2(side * 6, -44) * scale_factor, Color("#f6c871", alpha), 2 * scale_factor)
	canvas.draw_line(Vector2(-7, -12) * scale_factor, Vector2(-9 + step, 0) * scale_factor, ink, 7 * scale_factor)
	canvas.draw_line(Vector2(6, -12) * scale_factor, Vector2(9 - step, 0) * scale_factor, ink, 7 * scale_factor)
	canvas.draw_line(Vector2(-8, -31) * scale_factor, Vector2(12 * side, -24) * scale_factor, pale, 5 * scale_factor)
	canvas.draw_line(Vector2(-13, -23) * scale_factor, Vector2(12, -26) * scale_factor, Color("#d5ac68", alpha), 3 * scale_factor)
	if kind == "hero":
		polygon(canvas, [Vector2(-5, -36), Vector2(-24 - sin(phase) * 4, -29), Vector2(-34, -35), Vector2(-17, -38)], Color("#d86b40", alpha))
	elif kind == "archer":
		canvas.draw_arc(Vector2(side * 18, -29), 19, -1.2, 1.2, 12, pale, 3)
		canvas.draw_line(Vector2(side * 18 + 7, -47), Vector2(side * 18 + 7, -11), ink, 1)
	elif kind == "brute":
		polygon(canvas, [Vector2(12, -45), Vector2(32, -50), Vector2(38, -19), Vector2(24, -7), Vector2(12, -19)], Color("#3b4f3d", alpha))
		canvas.draw_line(Vector2(25, -42), Vector2(28, -16), pale, 3)
	elif kind == "boss":
		for i in 5:
			var at = Vector2(-23 + i * 12, -100 - (2 - absi(2 - i)) * 3)
			canvas.draw_line(at, at + Vector2((i - 2) * 4, -25 - i % 2 * 12), Color("#cfad65", alpha), 6)
			canvas.draw_circle(at + Vector2((i - 2) * 4, -25 - i % 2 * 12), 3, pale)
	elif kind == "crawler":
		canvas.draw_line(Vector2(-12, -45), Vector2(-25, -53), pale, 4)
		canvas.draw_line(Vector2(9, -48), Vector2(18, -58), pale, 4)
