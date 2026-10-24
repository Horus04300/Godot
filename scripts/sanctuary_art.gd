extends RefCounted
## Original nearest-filtered raster atlases baked by tools/bake_sanctuary_art.py.
##
## All positions are screen coordinates. No draw transform is changed.
## Terrain: 128x64 diamond in 128x96 cells, displayed at 55.04x27.52.
## Props: 256x320 cells, foot (128, 304), displayed at half native size.
## Actors: 8 columns (idle, walk x4, attack x3), rows down/left/right/up.
## Hero/crawler/archer 128x160 foot (64,152); brute 160x192 foot (80,184);
## boss 256x288 foot (128,276). Actors display at half native size except
## the low quadruped crawler, which uses 0.65 for a readable ~60px silhouette.
## phase is radians: zero selects idle, nonzero cycles four articulated poses.
## An explicit kind suffix ":attack" selects the three attack frames.
## Optional action_frame 0..2 overrides idle/walk with attack columns 5..7.

const BASE := "res://assets/sanctuary/"
const TILE_SIZE := Vector2(128, 64)
const TILE_DISPLAY := Vector2(55.04, 27.52)
const PROP_CELL := Vector2(256, 320)
const PROP_FOOT := Vector2(128, 304)
const ACTOR_CELLS := {
	"hero": Vector2(128, 160), "crawler": Vector2(128, 160),
	"archer": Vector2(128, 160), "brute": Vector2(160, 192),
	"boss": Vector2(256, 288),
}
const ACTOR_FEET := {
	"hero": Vector2(64, 152), "crawler": Vector2(64, 152),
	"archer": Vector2(64, 152), "brute": Vector2(80, 184),
	"boss": Vector2(128, 276),
}
const PROP_INDEX := {
	"tree": 0, "pillar": 3, "column": 3, "pillar_broken": 4,
	"ruin": 4, "gate": 5, "arch": 5, "chest": 6, "urn": 7,
	"rock": 8, "bush": 9, "mushrooms": 10, "mushroom": 10,
	"roots": 11, "thorn": 11, "torch": 12, "brazier": 12,
	"statue": 13, "crate": 14, "stairs": 15,
}
const ELEMENTS := ["무속성", "불", "얼음", "물", "땅", "풀", "바람", "번개", "양자", "허수"]
const ELEMENT_ALIASES := {
	"neutral": 0, "physical": 0, "fire": 1, "ice": 2, "water": 3,
	"earth": 4, "grass": 5, "nature": 5, "wind": 6,
	"lightning": 7, "quantum": 8, "imaginary": 9,
}

static func load_assets() -> Dictionary:
	var assets: Dictionary = {}
	for key: String in ["terrain", "props", "hero", "crawler", "archer", "brute", "boss", "icons"]:
		var texture := load(BASE + key + ".png") as Texture2D
		if texture != null:
			var pixel_texture := CanvasTexture.new()
			pixel_texture.diffuse_texture = texture
			pixel_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			assets[key] = pixel_texture
	return assets

static func _region(canvas: CanvasItem, assets: Dictionary, key: String, source: Rect2, dest: Rect2, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = assets.get(key) as Texture2D
	if texture == null:
		return
	canvas.draw_texture_rect_region(texture, dest, source, tint, false, true)

static func floor(canvas: CanvasItem, assets: Dictionary, pos_screen: Vector2, variant: int, water: bool = false, bridge: bool = false, time: float = 0.0) -> void:
	var cell := Vector2(posmod(variant, 6), floorf(float(posmod(variant, 12)) / 6.0))
	if water:
		cell = Vector2(posmod(int(floorf(time * 5.0)), 4), 2)
	if bridge:
		cell = Vector2(4, 2)
	_region(canvas, assets, "terrain", Rect2(cell * Vector2(128, 96), TILE_SIZE),
		Rect2(pos_screen - TILE_DISPLAY * 0.5, TILE_DISPLAY))

static func cliff_edge(canvas: CanvasItem, assets: Dictionary, pos_screen: Vector2, variant: int = 0, alpha: float = 1.0) -> void:
	## Anchor is the top edge's middle notch; draw before its floor diamond.
	var size := Vector2(55.04, 41.28)
	_region(canvas, assets, "terrain", Rect2(Vector2(posmod(variant, 3) * 128, 288), Vector2(128, 96)),
		Rect2(pos_screen - Vector2(27.52, 0), size), Color(1, 1, 1, clampf(alpha, 0, 1)))

static func cliff(canvas: CanvasItem, assets: Dictionary, pos_screen: Vector2, variant: int = 0, right: bool = true, left: bool = true) -> void:
	## pos_screen is the floor diamond's center; draw cliffs before the floor.
	## right exposes the screen-right face (missing logical RIGHT neighbor).
	## left exposes the screen-left face (missing logical DOWN neighbor).
	## Atlas alpha clips each half above its sloping lip; no tile-top is drawn.
	var source_x := posmod(variant, 3) * 128
	if right:
		_region(canvas, assets, "terrain",
			Rect2(Vector2(source_x + 64, 288), Vector2(64, 96)),
			Rect2(pos_screen, Vector2(27.52, 41.28)))
	if left:
		_region(canvas, assets, "terrain",
			Rect2(Vector2(source_x, 288), Vector2(64, 96)),
			Rect2(pos_screen - Vector2(27.52, 0), Vector2(27.52, 41.28)))

static func prop(canvas: CanvasItem, assets: Dictionary, kind: String, screenpos: Vector2, variant: int = 0, alpha: float = 1.0) -> void:
	if not PROP_INDEX.has(kind):
		return
	var index: int = PROP_INDEX[kind]
	if kind == "tree":
		index = posmod(variant, 3)
	elif kind in ["pillar", "column"]:
		index = 3 + posmod(variant, 2)
	var cell := Vector2(index % 4, floorf(index / 4.0))
	_region(canvas, assets, "props", Rect2(cell * PROP_CELL, PROP_CELL),
		Rect2(screenpos - PROP_FOOT * 0.5, PROP_CELL * 0.5),
		Color(1, 1, 1, clampf(alpha, 0, 1)))

static func actor(canvas: CanvasItem, assets: Dictionary, kind: String, screenpos: Vector2, direction: Vector2, phase: float, flash: bool = false, alpha: float = 1.0, action_frame: int = -1) -> void:
	var parts := kind.split(":")
	var base_kind: String = parts[0]
	if not ACTOR_CELLS.has(base_kind):
		return
	var facing := 0
	if absf(direction.x) > absf(direction.y):
		facing = 1 if direction.x < 0 else 2
	elif direction.y < 0:
		facing = 3
	var frame := 0
	if parts.size() > 1 and parts[1] == "attack":
		frame = 5 + posmod(int(floorf(phase / TAU * 3.0)), 3)
	elif not is_zero_approx(phase):
		frame = 1 + posmod(int(floorf(phase / TAU * 4.0)), 4)
	if action_frame >= 0 and action_frame <= 2:
		frame = 5 + action_frame
	var cell: Vector2 = ACTOR_CELLS[base_kind]
	var foot: Vector2 = ACTOR_FEET[base_kind]
	var display_scale := 0.65 if base_kind == "crawler" else 0.5
	var tint := Color(1.75, 1.65, 1.4, clampf(alpha, 0, 1)) if flash else Color(1, 1, 1, clampf(alpha, 0, 1))
	_region(canvas, assets, base_kind, Rect2(Vector2(frame, facing) * cell, cell),
		Rect2(screenpos - foot * display_scale, cell * display_scale), tint)

static func icon(canvas: CanvasItem, assets: Dictionary, element: Variant, indexpos: Vector2, size: float = 32.0) -> void:
	## indexpos is the icon's top-left corner, unlike foot-anchored actors/props.
	var index := 0
	if element is int:
		index = posmod(element, 10)
	elif element is String:
		index = ELEMENTS.find(element)
		if index < 0:
			index = int(ELEMENT_ALIASES.get(element.to_lower(), 0))
	_region(canvas, assets, "icons", Rect2(Vector2(index * 64, 0), Vector2(64, 64)),
		Rect2(indexpos, Vector2.ONE * maxf(1.0, size)))
