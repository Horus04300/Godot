extends RefCounted

const INK = Color("#10252a")
const GOLD = Color("#f4c675")
const MINT = Color("#82cbb2")

static func sprite(rows: Array, palette: Dictionary) -> ImageTexture:
	var width = 16
	for row in rows:
		width = maxi(width, row.length())
	var image = Image.create(width, maxi(16, rows.size()), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in rows.size():
		for x in rows[y].length():
			var key = rows[y][x]
			if palette.has(key):
				image.set_pixel(x, y, Color(palette[key]))
	return ImageTexture.create_from_image(image)

static func create_sprites() -> Dictionary:
	var p = {
		"x": "#10252a", "a": "#2e6365", "b": "#69b6a4", "c": "#c1e7cd",
		"g": "#f4c675", "h": "#b97549", "w": "#f7edd2", "r": "#d87261",
		"d": "#654557", "e": "#b98b9a"
	}
	var result = {
		"hero": sprite([
			"................", "......xxxx......", ".....xggggx.....",
			"....xggwgggx....", "....xggggggx....", ".....xhhhhx.....",
			"....xabhhax.....", "...xaabbbax.....", "...xabccbbax....",
			"...xabbabbax....", "....xaabaax.....", "....xaabaabx....",
			"...xaaxxaabx....", "...xxx..xxx.....", "....hx..hx......",
			"...xxx..xxx....."], p),
		"crawler": sprite([
			"................", "................", ".....xxxxxx.....",
			"...xxaaaaaaxx...", "..xabbbbbbbbax..", ".xabbbbbbbbbbax.",
			".xbbbwcbbwcb b x".replace(" ", ""), ".xbbbwcbbwcbbbx.",
			".xbbbbaabbbbbbx.", "..xbbbrrrbbbbx..", "..xaabbbbaaax...",
			"...xxaaaaxx.....", "..xaa.xx.aax....", "..xx......xx....",
			"................", "................"], p),
		"archer": sprite([
			"......xxxx......", ".....xddddx.....", "....xdeeedx.....",
			"....xddgddx.....", ".....xddddx.....", ".....xaaaax.....",
			"....xaaaadax....", "...xaabaadaxh...", "...xaabaaax.h...",
			"....xaabaax.hh..", "....xaabaax.h...", ".....xaaxx..h...",
			".....xx.xx......", ".....hx.hx......", "....xxx.xxx.....",
			"................"], p),
		"brute": sprite([
			".....xxxxxx.....", "....xaaaaaax....", "...xabbbbb bax...".replace(" ", ""),
			"...xbgwbbwg bx...".replace(" ", ""), "....xbbbbbbx....", "..xxxaaaaaaxxx..",
			".xaabbcccbbaaax.", ".xabbbcccbbb bax".replace(" ", ""), ".xabbbaaabbb bax".replace(" ", ""),
			"..xabbaaaabbax..", "...xabbbbbbax...", "...xaaabba aax...".replace(" ", ""),
			"...xaaxxxaax....", "...xxx...xxx....", "..xxxx...xxxx...",
			"................"], p),
		"boss": sprite([
			"..h...hhhh...h..", "..hh..hgg h..hh..".replace(" ", ""), "...hxxggggxxh...",
			"...xaaggggaax...", "..xabbgwgbbbax..", "..xabbgggbbbax..",
			"...xaa rr aaax...".replace(" ", ""), ".xxxaaaaaaaaxxx.",
			"xabbccbbbccbb bax".replace(" ", ""), "xabbccbbbccbb bax".replace(" ", ""),
			".xabbba aabbb bax".replace(" ", ""), "..xaabbbbbb aax..".replace(" ", ""),
			"...xaaabba aax...".replace(" ", ""), "...xaaxxxaax....", "..xxxx...xxxx...",
			"..xxxx...xxxx..."], p),
		"torch": sprite([
			".......g........", "......gwg.......", ".....ggwgg......",
			".....gwwwg......", "......gwg.......", "......hhh.......",
			".....xxxxx......", "......aaa.......", "......aaa.......",
			"......aaa.......", "......aaa.......", ".....xxxxx......",
			".....aaaaa......", "....xxxxxxx.....", "................",
			"................"], p),
		"chest": sprite([
			"................", "................", "................",
			"...xxxxxxxxxx...", "..xhhhhhhhhhhx..", "..xhgggggggghx..",
			"..xhgggggggghx..", "..xhhhhhhhhhhx..", "..xxxxggxxxxxx..",
			"..xh hhgghhhhx..".replace(" ", ""), "..xhhhhhhhhhhx..", "..xhgggggggghx..",
			"..xxxxxxxxxxxx..", "................", "................",
			"................"], p)
	}
	var hero_palette = {
		"x": "#20252d", "a": "#527570", "b": "#89b9ac", "c": "#e5e0c9",
		"g": "#d8c5a2", "h": "#ba7954", "w": "#fff4d8", "r": "#52656b"
	}
	var hero_rows = [
		"................", "......xxxx......", ".....xccccx.....",
		"....xccwwccx....", "...xccggggccx...", "...xcxgxxgcxx...",
		"....xghhhgx.....", ".....xhhhx......", "....xabbax......",
		"...xabbabax.....", "...xabbabax.....", "....xarrrax.....",
		"....xahhax......", "....xhxxhx......", "...xhh..hhx.....",
		"...xxx..xxx....."
	]
	result.hero = sprite(hero_rows, hero_palette)
	var enemy_colors = {
		"crawler": ["#6a4d48", "#ba8266", "#e4b78e"],
		"archer": ["#50445b", "#947c9c", "#c3abb9"],
		"brute": ["#5a5f56", "#9b9e83", "#d2c6a2"],
		"boss": ["#485f59", "#8a9e7d", "#d1d4ae"]
	}
	for kind in enemy_colors:
		var image: Image = result[kind].get_image()
		for y in image.get_height():
			for x in image.get_width():
				var color = image.get_pixel(x, y)
				for index in 3:
					if color == Color(["#2e6365", "#69b6a4", "#c1e7cd"][index]):
						image.set_pixel(x, y, Color(enemy_colors[kind][index]))
						break
		result[kind] = ImageTexture.create_from_image(image)
	for frame in 4:
		var image: Image = result.hero.get_image().duplicate()
		if frame % 2:
			image.fill_rect(Rect2i(3, 13, 3, 3), Color.TRANSPARENT)
			image.fill_rect(Rect2i(10, 13, 3, 3), Color.TRANSPARENT)
			var left = 1 if frame == 1 else -1
			for x in 3:
				image.set_pixel(3 + x, 14 + left, Color("#ba7954"))
				image.set_pixel(10 + x, 14 - left, Color("#ba7954"))
		result["hero_walk%d" % frame] = ImageTexture.create_from_image(image)
	for id in ["edge", "vital", "fire", "leech", "storm", "stride", "focus", "reach", "crit", "thorn", "flask", "swift"]:
		result[id] = relic_icon(id)
	return result

static func relic_icon(id: String) -> ImageTexture:
	var symbols = {
		"edge": ["................","................","....xxxxxxx.....","...xcccccccx....","..xccwwwwcccx...","..xcccccccccx...","...xcccccccx....","....xxxxxxx....."],
		"vital": ["......xx........","....xxggxx......","...xggbbggx.....","..xgbbbbbb gx....".replace(" ", ""),"..xgbbggbbgx....","...xgbbbb gx.....".replace(" ", ""),"....xgbbgx......",".....xggx.......","......xx........"],
		"fire": [".......g........","......gwg.......",".....gwwg.......","....gwwwgg......","...ggwwwwwg.....","...gwwwwwwg.....","....gwwwwg......",".....gggg.......","......hh........"],
		"leech": ["....xx..........","....xccx........",".....xccx.......",".....xwwcx......","......xwwcx.....","......xwwcx.....",".......xwcx.....","........xx......"],
		"storm": ["......hh........",".....hwwh.......","....hggggh......","....hggggh......","...hggggggh.....","..hggggggggh....","..hhhhhhhhhh....","......gg........"],
		"stride": ["....xxxx........","....xbbx........","....xbbx........","....xbbx........","....xbbxxx......","....xbbbggx.....","...xhbbbbbhx....","...xxxxxxxxx...."],
		"focus": [".....xxxxx......","....xgggggx.....","...xgbwwwbgx....","...xgbwwwbgx....","...xgbbbbggx....","....xgggggx.....",".....xxxxx......"],
		"reach": [".........wx.....","........wwx.....",".......wwx......","......wwx.......",".....wwx........","....wwx.........","...gwwx.........","....hh..........","...hh..........."],
		"crit": ["...g...g...g....","...gg.ggg.gg....","...ggggggggg....","...gggwwwggg....","...hhhhhhhhh....","....ggggggg....."],
		"thorn": ["......x.........",".....xgx........","...xxgggxx......","..xgggbgggx.....","..xggbbbggx.....","...xggbggx......","....xgggx.......",".....xxx........"],
		"flask": [".....hhhhh......","......ccc.......",".....xcccx......","....xcbbbcx.....","....xcbbbcx.....","....xcbbbcx.....",".....xxxxx......"],
		"swift": ["......w...w.....",".....wc..wc.....","....wcc.wcc.....","...wcc.wcc......","...cc..cc.......","....h...h.......","...h...h........"]
	}
	return sprite(symbols[id], {"x":"#232731","c":"#b9c5bc","w":"#fff1cf","g":"#e9ba69","h":"#926448","b":"#6cbeb8"})

static func floor_tiles() -> Array:
	var result = []
	var rng = RandomNumberGenerator.new()
	rng.seed = 28719
	for variant in 12:
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color("#30363d") if variant % 3 else Color("#333a40"))
		if variant < 5:
			for x in 16:
				image.set_pixel(x, 15, Color("#2e343b"))
			for y in 16:
				image.set_pixel(15 if variant % 2 else 7, y, Color("#2e343b"))
		for i in 5:
			var pos = Vector2i(rng.randi_range(1, 14), rng.randi_range(1, 14))
			image.set_pixelv(pos, Color("#3c4448") if i % 2 else Color("#2b3239"))
		if variant >= 8:
			for i in 8:
				var pos = Vector2i(rng.randi_range(3, 10), rng.randi_range(3, 10))
				image.set_pixelv(pos, Color("#4b5a49") if i % 2 else Color("#50614d"))
		result.append(ImageTexture.create_from_image(image))
	return result
