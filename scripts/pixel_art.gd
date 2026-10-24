extends RefCounted

const INK = Color("#10252a")
const GOLD = Color("#f4c675")
const MINT = Color("#82cbb2")

static func sprite(rows: Array, palette: Dictionary) -> ImageTexture:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in mini(rows.size(), 16):
		for x in mini(rows[y].length(), 16):
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
	return {
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

static func floor_tiles() -> Array:
	var result = []
	var rng = RandomNumberGenerator.new()
	rng.seed = 28719
	for variant in 8:
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color("#203b3d") if variant % 3 else Color("#243f40"))
		for x in 16:
			image.set_pixel(x, 15, Color("#142e32"))
			image.set_pixel(15, x, Color("#142e32"))
		for i in 14:
			var pos = Vector2i(rng.randi_range(1, 14), rng.randi_range(1, 14))
			image.set_pixelv(pos, Color("#2a4a49") if i % 2 else Color("#1b3438"))
		if variant < 3:
			for i in 5:
				image.set_pixel(2 + i, 2 + i / 2, Color("#396255"))
		result.append(ImageTexture.create_from_image(image))
	return result
