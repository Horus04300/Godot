extends RefCounted

const NAMES = ["교차하는 숲길", "쌍둥이 바위 협곡", "고목의 원환", "갈라진 정원", "굽이치는 숲"]

static func layout(index: int) -> Dictionary:
	var layouts = [
		{"rocks": [Rect2(290, 580, 160, 64), Rect2(1060, 300, 160, 64)],
			"trees": [Vector2(440, 470), Vector2(504, 470), Vector2(1030, 620), Vector2(1094, 620)],
			"paths": [[Vector2(752, 950), Vector2(700, 720), Vector2(752, 515), Vector2(820, 320), Vector2(752, 148)],
				[Vector2(88, 544), Vector2(420, 520), Vector2(752, 515), Vector2(1100, 570), Vector2(1416, 544)]]},
		{"rocks": [Rect2(420, 260, 128, 400), Rect2(960, 420, 128, 400)],
			"trees": [Vector2(280, 330), Vector2(310, 390), Vector2(1220, 710), Vector2(1250, 760)],
			"paths": [[Vector2(752, 950), Vector2(760, 720), Vector2(752, 515), Vector2(740, 300), Vector2(752, 148)],
				[Vector2(88, 544), Vector2(270, 760), Vector2(630, 760), Vector2(752, 515), Vector2(865, 300), Vector2(1200, 300), Vector2(1416, 544)]]},
		{"rocks": [Rect2(520, 320, 128, 64), Rect2(900, 320, 128, 64), Rect2(510, 660, 128, 64), Rect2(910, 660, 128, 64)],
			"trees": [Vector2(450, 490), Vector2(480, 550), Vector2(1090, 480), Vector2(1120, 540), Vector2(660, 280), Vector2(850, 780)],
			"paths": [[Vector2(752, 950), Vector2(750, 790), Vector2(380, 620), Vector2(380, 390), Vector2(752, 220), Vector2(1140, 390), Vector2(1140, 660), Vector2(750, 790)],
				[Vector2(88, 544), Vector2(380, 520), Vector2(752, 515), Vector2(1140, 520), Vector2(1416, 544)],
				[Vector2(752, 148), Vector2(752, 515)]]},
		{"rocks": [Rect2(240, 350, 290, 96), Rect2(980, 350, 260, 96), Rect2(300, 690, 250, 96), Rect2(1000, 690, 240, 96)],
			"trees": [Vector2(620, 380), Vector2(655, 420), Vector2(850, 650), Vector2(880, 690)],
			"paths": [[Vector2(752, 950), Vector2(760, 800), Vector2(600, 580), Vector2(752, 515), Vector2(910, 320), Vector2(752, 148)],
				[Vector2(88, 544), Vector2(400, 550), Vector2(752, 515), Vector2(1110, 550), Vector2(1416, 544)]]},
		{"rocks": [Rect2(280, 300, 320, 64), Rect2(900, 450, 300, 64), Rect2(320, 650, 320, 64)],
			"trees": [Vector2(380, 450), Vector2(420, 470), Vector2(1100, 700), Vector2(1140, 720), Vector2(880, 280)],
			"paths": [[Vector2(752, 950), Vector2(900, 800), Vector2(750, 590), Vector2(650, 480), Vector2(800, 300), Vector2(752, 148)],
				[Vector2(88, 544), Vector2(230, 530), Vector2(500, 550), Vector2(752, 515), Vector2(1240, 620), Vector2(1416, 544)]]}
	]
	var corners = [
		[Rect2(64, 128, 220, 220), Rect2(1220, 740, 220, 220)],
		[Rect2(64, 128, 230, 320), Rect2(1210, 640, 230, 320)],
		[Rect2(64, 128, 330, 200), Rect2(1110, 128, 330, 200), Rect2(64, 770, 330, 190), Rect2(1110, 770, 330, 190)],
		[Rect2(64, 128, 180, 350), Rect2(1260, 128, 180, 350), Rect2(64, 650, 180, 310), Rect2(1260, 650, 180, 310)],
		[Rect2(64, 128, 150, 300), Rect2(1180, 128, 260, 200), Rect2(64, 760, 400, 200), Rect2(1280, 700, 160, 260)]
	]
	var result: Dictionary = layouts[posmod(index, layouts.size())]
	result.rocks.append_array(corners[posmod(index, layouts.size())])
	return result
