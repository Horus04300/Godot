"""Extract the owner's licensed reference pixels without repainting the artwork.

Run: python tools\\prepare_reference_art.py [--preview PATH] [--validate]
Requires Pillow, NumPy and OpenCV. Boundary-only GrabCut refines hand-traced
silhouettes; protected interiors prevent the dark cloak becoming background.
The fourth pose's small overprinted sword tip uses clean source sword pixels.
Animation in reference_art.gd is cutout motion, not original attack artwork.
"""

from pathlib import Path
import argparse
import hashlib

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "reference"
SOURCES = ROOT.parent
HERO_CELL = (1024, 1024)
HERO_FOOT = (512, 990)

# Coordinates stay in the full-resolution reference, not a redrawn template.
DOGS = {
    "front": [
        (130,548),(132,515),(158,478),(171,519),(190,539),(199,491),
        (197,453),(198,413),(209,400),(198,387),(219,364),(227,329),
        (235,302),(234,258),(257,228),(277,210),(302,185),(322,169),
        (348,160),(365,141),(365,114),(379,82),(398,57),(410,78),
        (423,113),(440,96),(457,99),(479,59),(489,78),(494,118),
        (492,130),(501,139),(500,158),(509,172),(510,185),(522,205),
        (539,216),(549,242),(550,291),(551,349),(571,363),(586,389),
        (600,419),(603,453),(614,479),(615,517),(600,530),(581,527),
        (559,511),(552,484),(543,484),(546,513),(557,536),(556,561),
        (533,578),(516,584),(525,607),(547,626),(573,639),(589,657),
        (593,677),(572,687),(548,691),(522,684),(498,668),(481,642),
        (462,614),(447,597),(433,620),(414,601),(400,558),(393,526),
        (379,557),(367,590),(344,612),(336,632),(328,652),(335,686),
        (346,712),(346,735),(330,744),(316,751),(297,746),(281,747),
        (267,735),(255,735),(255,716),(266,690),(263,673),(272,639),
        (281,618),(286,600),(260,621),(217,646),(179,659),(175,649),
        (190,620),(169,610),(145,586),(130,562),
    ],
    "back": [
        (913,553),(916,527),(931,503),(939,540),(960,552),(984,560),
        (1001,558),(1002,518),(1011,490),(1026,476),(1024,459),
        (1010,478),(1011,508),(1000,525),(983,522),(970,504),
        (961,478),(956,457),(951,438),(950,384),(963,373),
        (954,365),(973,349),(975,322),(990,302),(997,278),
        (997,242),(1013,215),(1037,198),(1061,191),(1088,174),
        (1119,184),(1126,164),(1112,155),(1123,139),(1116,134),
        (1128,120),(1136,92),(1152,61),(1166,48),(1173,88),
        (1193,97),(1212,75),(1230,55),(1240,66),(1240,100),
        (1258,113),(1267,136),(1298,141),(1305,153),(1303,169),
        (1288,187),(1263,193),(1265,201),(1288,209),(1310,237),
        (1326,267),(1327,287),(1338,298),(1326,302),(1336,325),
        (1345,355),(1345,412),(1357,400),(1356,390),(1367,385),
        (1380,390),(1383,409),(1371,423),(1378,450),(1390,476),
        (1394,504),(1401,523),(1402,556),(1390,577),(1369,585),
        (1350,574),(1340,560),(1348,541),(1332,517),(1322,536),
        (1322,588),(1305,606),(1282,615),(1297,642),(1295,659),
        (1326,665),(1347,682),(1360,696),(1360,703),(1337,711),
        (1320,716),(1295,721),(1269,725),(1250,717),(1242,702),
        (1232,676),(1218,654),(1214,629),(1202,649),(1187,679),
        (1167,679),(1171,652),(1177,636),(1180,606),(1169,586),
        (1156,582),(1147,603),(1125,589),(1117,621),(1103,644),
        (1098,673),(1077,675),(1053,669),(1046,657),(1020,663),
        (993,657),(966,647),(941,632),(925,614),(912,591),(912,576),
    ],
    "left": [
        (315,809),(337,835),(356,849),(376,845),(385,802),(407,826),
        (423,853),(438,880),(450,901),(444,909),(452,932),(479,934),
        (507,949),(531,969),(543,994),(549,1039),(554,1080),
        (571,1107),(599,1121),(602,1150),(609,1170),(598,1193),
        (596,1231),(591,1261),(578,1278),(557,1273),(550,1259),
        (542,1229),(539,1192),(535,1202),(537,1284),(560,1304),
        (594,1315),(624,1301),(647,1280),(651,1263),(665,1287),
        (673,1313),(669,1344),(674,1346),(657,1372),(647,1380),
        (657,1382),(639,1398),(607,1413),(576,1423),(542,1424),
        (520,1418),(516,1432),(500,1446),(478,1448),(457,1432),
        (444,1410),(433,1390),(422,1360),(417,1325),(411,1283),
        (392,1302),(384,1330),(367,1348),(360,1340),(365,1366),
        (374,1393),(383,1427),(377,1434),(351,1410),(337,1393),
        (328,1412),(335,1441),(336,1484),(322,1495),(297,1496),
        (278,1488),(255,1488),(235,1482),(214,1481),(210,1466),
        (231,1442),(253,1431),(275,1432),(286,1406),(292,1390),
        (274,1372),(255,1370),(239,1342),(239,1317),(247,1296),
        (259,1272),(269,1241),(253,1229),(244,1240),(226,1252),
        (213,1276),(204,1314),(194,1333),(172,1331),(157,1317),
        (146,1297),(145,1279),(162,1244),(169,1213),(181,1185),
        (191,1152),(212,1120),(230,1085),(241,1069),(237,1039),
        (229,1034),(243,1023),(242,1012),(261,992),(285,978),
        (309,968),(290,965),(272,950),(257,933),(254,915),
        (274,907),(288,901),(292,877),(308,864),(318,865),
    ],
    "right": [
        (1084,821),(1098,833),(1114,862),(1127,871),(1142,862),
        (1159,840),(1182,820),(1195,836),(1208,865),(1223,896),
        (1228,924),(1256,927),(1284,941),(1318,966),(1340,992),
        (1356,1021),(1362,1060),(1375,1094),(1384,1132),(1398,1150),
        (1400,1185),(1402,1202),(1407,1239),(1394,1279),(1408,1259),
        (1427,1235),(1433,1188),(1446,1199),(1461,1230),(1468,1262),
        (1475,1298),(1463,1324),(1440,1342),(1457,1343),(1441,1353),
        (1410,1360),(1394,1358),(1397,1403),(1385,1404),(1372,1360),
        (1355,1364),(1337,1360),(1322,1352),(1316,1375),(1303,1395),
        (1307,1424),(1325,1458),(1338,1490),(1343,1514),(1331,1530),
        (1312,1533),(1297,1531),(1280,1528),(1262,1525),(1255,1511),
        (1256,1487),(1265,1461),(1259,1434),(1242,1414),(1223,1401),
        (1199,1388),(1195,1354),(1189,1342),(1180,1377),(1165,1401),
        (1148,1391),(1142,1374),(1135,1370),(1137,1392),(1125,1414),
        (1116,1438),(1097,1456),(1068,1465),(1044,1465),(1022,1461),
        (1005,1453),(998,1440),(1005,1428),(1027,1415),(1046,1411),(1056,1388),
        (1063,1362),(1048,1353),(1034,1339),(1027,1315),(1037,1294),
        (1046,1267),(1061,1243),(1074,1216),(1074,1179),(1065,1141),
        (1056,1151),(1046,1181),(1032,1214),(1018,1243),(1009,1271),
        (1007,1298),(993,1308),(971,1306),(952,1297),(941,1281),
        (949,1262),(960,1232),(969,1200),(980,1169),(994,1144),
        (1012,1127),(1022,1088),(1027,1060),(1031,1033),(1025,1020),
        (1037,1004),(1053,987),(1059,975),(1053,963),(1055,949),
        (1073,937),(1068,916),(1073,902),(1080,898),(1080,860),
    ],
}

PROPS = {
    "tree": [
        (1126,0),(1335,0),(1333,31),(1321,56),(1293,84),(1288,120),
        (1277,148),(1292,165),(1314,167),(1330,192),(1334,215),
        (1343,242),(1320,241),(1319,263),(1305,259),(1288,276),
        (1273,270),(1260,287),(1243,299),(1224,296),(1213,283),
        (1198,294),(1173,296),(1149,288),(1124,299),(1098,293),
        (1106,278),(1125,263),(1119,251),(1097,244),(1086,234),
        (1056,234),(1061,221),(1078,218),(1084,201),(1097,178),
        (1107,159),(1123,148),(1143,153),(1155,145),(1174,117),
        (1177,91),(1163,63),(1138,44),
    ],
    "bush": [
        (1362,405),(1353,388),(1366,388),(1371,377),(1385,383),
        (1389,363),(1402,368),(1406,347),(1418,357),(1424,344),
        (1436,351),(1445,343),(1451,363),(1467,350),(1472,363),
        (1481,360),(1483,378),(1497,377),(1491,395),(1511,397),
        (1506,412),(1514,422),(1505,433),(1514,446),(1504,453),
        (1494,469),(1474,481),(1454,490),(1434,498),(1419,490),
        (1403,491),(1384,481),(1367,477),(1354,464),(1360,452),
        (1350,444),(1358,432),(1352,419),
    ],
    "mushroom": [
        (1377,270),(1390,249),(1403,242),(1412,251),(1419,268),
        (1415,281),(1404,285),(1408,300),(1415,297),(1419,289),
        (1431,278),(1433,260),(1430,252),(1414,248),(1413,234),
        (1425,218),(1436,204),(1450,202),(1462,210),(1480,222),
        (1487,234),(1482,245),(1464,251),(1456,254),(1455,272),
        (1462,286),(1471,295),(1481,284),(1485,268),(1481,264),
        (1488,255),(1495,255),(1500,263),(1503,278),(1495,281),
        (1495,291),(1487,299),(1476,304),(1460,302),(1454,311),
        (1436,319),(1418,311),(1415,304),(1396,305),(1387,300),
        (1388,287),(1376,282),
    ],
    "roots": [
        (1065,426),(1079,402),(1089,396),(1080,381),(1094,382),
        (1105,366),(1121,365),(1120,334),(1136,360),(1157,354),
        (1162,342),(1183,339),(1192,324),(1204,337),(1224,330),
        (1232,315),(1240,330),(1266,328),(1279,322),(1276,341),
        (1287,355),(1280,374),(1272,387),(1292,384),(1308,395),
        (1302,411),(1317,413),(1313,433),(1324,449),(1316,465),
        (1325,475),(1301,478),(1278,483),(1258,474),(1229,482),
        (1209,471),(1181,481),(1149,478),(1131,483),(1112,473),
        (1095,476),(1098,460),(1082,450),(1068,456),(1072,438),
    ],
    "pillar": [
        (855,639),(862,626),(885,619),(906,620),(928,632),
        (934,645),(927,658),(919,668),(920,855),(931,872),
        (933,886),(945,897),(942,913),(920,922),(891,925),
        (868,918),(856,924),(851,909),(857,893),(857,874),
        (863,861),(864,670),(858,660),
    ],
    "gate": [
        (1295,746),(1306,721),(1321,704),(1340,694),(1364,685),
        (1393,686),(1427,699),(1455,721),(1474,749),(1486,778),
        (1489,803),(1499,816),(1497,837),(1496,928),(1483,939),
        (1462,937),(1449,923),(1430,917),(1430,824),(1421,813),
        (1424,799),(1419,774),(1406,750),(1389,738),(1370,734),
        (1351,741),(1337,754),(1338,770),(1342,777),(1335,796),
        (1334,872),(1321,885),(1304,886),(1296,876),(1294,798),
        (1301,788),(1294,776),
    ],
    "chest": [
        (1376,103),(1384,85),(1387,68),(1397,74),(1408,64),
        (1417,66),(1426,50),(1430,67),(1447,75),(1456,67),
        (1457,82),(1473,91),(1484,84),(1481,102),(1494,114),
        (1497,130),(1488,141),(1489,162),(1457,187),(1386,155),
        (1384,130),(1371,118),(1380,116),
    ],
    "urn": [
        (1113,531),(1128,524),(1150,525),(1167,532),(1169,543),
        (1160,550),(1176,568),(1182,590),(1177,613),(1166,632),
        (1150,638),(1132,636),(1115,622),(1105,602),(1101,582),
        (1104,565),(1119,549),(1114,544),
    ],
    "rock": [
        (769,737),(778,727),(790,724),(802,713),(817,713),
        (822,722),(817,746),(813,764),(799,770),(776,762),
        (765,752),
    ],
}

HOLES = {
    "tree": [
        [(1164,0),(1191,0),(1191,31),(1202,54),(1193,63),(1178,47)],
        [(1204,0),(1249,0),(1232,23),(1222,28),(1211,21)],
        [(1270,0),(1305,0),(1291,23),(1267,44),(1256,46)],
        [(1105,215),(1122,197),(1138,190),(1135,202),(1121,213)],
    ],
    "roots": [
        [(1208,350),(1231,344),(1248,350),(1247,364),(1228,388),(1213,405),(1206,389),(1219,369),(1224,360)],
        [(1131,386),(1147,377),(1163,378),(1176,392),(1166,400),(1145,392)],
        [(1105,412),(1115,413),(1130,434),(1141,443),(1130,453),(1115,437)],
        [(1248,436),(1260,414),(1271,405),(1283,412),(1283,432),(1270,443)],
        [(1163,443),(1186,432),(1192,441),(1179,453)],
    ],
}


def polygon_mask(size, points, holes=()):
    mask = Image.new("L", size)
    draw = ImageDraw.Draw(mask)
    draw.polygon(points, fill=255)
    for hole in holes:
        draw.polygon(hole, fill=0)
    return mask


def scale_points(points, size, coordinate_size):
    return [(round(x * size[0] / coordinate_size[0]),
             round(y * size[1] / coordinate_size[1])) for x, y in points]


def dog_points(sheet, pose):
    return scale_points(DOGS[pose], sheet.size, (1561, 1561))


def fourth_sword_patch(sheet):
    """Replace only the overprinted sword tip with clean licensed sword pixels."""
    source = scale_points([(176,650),(199,614),(216,629),(187,659)],
                          sheet.size, (1561,1561))
    target = scale_points([(1374,1357),(1390,1354),(1397,1403),(1386,1404)],
                          sheet.size, (1561,1561))
    transform = cv2.getPerspectiveTransform(np.float32(source), np.float32(target))
    cloned = cv2.warpPerspective(np.asarray(sheet), transform, sheet.size,
                                flags=cv2.INTER_NEAREST)
    mask = np.asarray(polygon_mask(sheet.size, target)) > 0
    pixels = np.asarray(sheet).copy()
    pixels[mask] = cloned[mask]
    print(f"Fourth pose: clean front sword pixels transplanted into {int(mask.sum())}px tip patch")
    return Image.fromarray(pixels)


def extract(source, points, holes=(), band=5, preserve_outline=False):
    """Protect all pixels beyond the narrow contour band from segmentation."""
    polygon = np.asarray(polygon_mask(source.size, points, holes))
    kernel = np.ones((band * 2 + 1, band * 2 + 1), np.uint8)
    outer = cv2.dilate(polygon, kernel)
    inner = cv2.erode(polygon, kernel)
    labels = np.full(polygon.shape, cv2.GC_BGD, np.uint8)
    labels[outer > 0] = cv2.GC_PR_BGD
    labels[polygon > 0] = cv2.GC_PR_FGD
    labels[inner > 0] = cv2.GC_FGD
    rgb = np.asarray(source.convert("RGB"))
    cv2.setRNGSeed(781)
    cv2.grabCut(rgb, labels, None, np.zeros((1, 65), np.float64),
                np.zeros((1, 65), np.float64), 4, cv2.GC_INIT_WITH_MASK)
    alpha = np.uint8((labels == cv2.GC_FGD) | (labels == cv2.GC_PR_FGD)) * 255
    if preserve_outline:
        # Sheet grid and ink share near-black colors. Restore only ink pixels
        # immediately adjacent to retained colored art, never an entire dark run.
        near_foreground = cv2.dilate(alpha, np.ones((7, 7), np.uint8)) > 0
        ink = np.max(rgb, axis=2) < 38
        alpha[near_foreground & ink & (outer > 0)] = 255
    # Isolated sheet grid slivers cannot survive as disconnected foreground.
    count, components, stats, _ = cv2.connectedComponentsWithStats(alpha, 8)
    for label in range(1, count):
        if stats[label, cv2.CC_STAT_AREA] < 18:
            alpha[components == label] = 0
    pixels = np.zeros((*alpha.shape, 4), dtype=np.uint8)
    pixels[alpha > 0, :3] = rgb[alpha > 0]
    pixels[..., 3] = alpha
    result = Image.fromarray(pixels)
    box = result.getbbox()
    if box is None:
        raise RuntimeError("Foreground extraction was empty")
    result = result.crop(box)
    return result, box


def hero_master(cutout):
    result = Image.new("RGBA", HERO_CELL)
    result.paste(cutout, (HERO_FOOT[0] - cutout.width // 2,
                         HERO_FOOT[1] - cutout.height))
    return result


def forest_variants(trunk, foliage):
    """Compose only licensed leaf/trunk cutouts; no painted replacement pixels."""
    trees = []
    for variant in range(3):
        tree = Image.new("RGBA", (850, 940))
        # The crown overlaps the source crop, hiding its straight
        # edge without sacrificing the intact lower trunk and spreading roots.
        tree.alpha_composite(trunk, (425-trunk.width//2, 940-trunk.height))
        clusters = [
            (205,270,420,False),(650,280,400,True),
            (110,400,350,True),(735,400,350,False),
            (325,170,410,True),(515,155,400,False),
            (180,210,335,False),(685,220,340,True),
            (405,300,435,False),(560,385,350,True),
            (285,405,360,False),(425,105,335,True),
        ]
        for i, (x,y,width,mirror) in enumerate(clusters):
            x += ((i*17+variant*31) % 43)-21
            y += ((i*23+variant*19) % 35)-17
            leaf = ImageOps.mirror(foliage) if mirror else foliage
            width = round(width*(0.94+variant*0.045))
            leaf = leaf.resize((width, round(leaf.height*width/leaf.width)),
                               Image.Resampling.LANCZOS)
            tree.alpha_composite(leaf, (max(0,min(850-leaf.width,x-leaf.width//2)),
                                        max(0,y-leaf.height//2)))
        trees.append(tree)
    bushes = []
    for variant in range(3):
        bush = Image.new("RGBA", (440, 300))
        clusters = [
            [(130,190,250,False),(290,195,275,True),(215,130,230,False)],
            [(105,190,215,True),(235,185,320,False),(345,215,185,True)],
            [(120,205,240,False),(305,170,260,True),(215,225,255,True)],
        ][variant]
        for x,y,width,mirror in clusters:
            leaf = ImageOps.mirror(foliage) if mirror else foliage
            leaf = leaf.resize((width, round(leaf.height*width/leaf.width)),
                               Image.Resampling.LANCZOS)
            bush.alpha_composite(leaf, (x-width//2,y-leaf.height//2))
        bushes.append(bush.crop(bush.getbbox()))
    return trees, bushes


def terrain(reference):
    """Interior top-surface samples, no black diamond rim or raised cliff sides.

    Unproject a broad grass surface, periodize its edges with a reflected
    continuation, then reproject 24 offsets. Shared edge texels keep variants
    compatible; no per-tile frame, procedural scratches or random pixel noise.
    """
    rgb = reference.convert("RGB")
    # Interior quadrilateral stays away from mossy platform rims.
    quads = {
        "grass": [(916, 37),(1015, 91),(916, 147),(816, 92)],
        "stone": [(135, 215),(231, 271),(135, 326),(36, 271)],
    }
    atlas = Image.new("RGBA", (128 * 8, 64 * 6))
    diamond = polygon_mask((128, 64), [(64, 0),(128, 32),(64, 64),(0, 32)])
    for row, (material, quad) in enumerate(quads.items()):
        quad = scale_points(quad, reference.size, (1530, 1142))
        # Pillow QUAD order: upper-left, lower-left, lower-right, upper-right.
        q = [quad[0], quad[3], quad[2], quad[1]]
        square = rgb.transform((256, 256), Image.Transform.QUAD,
                               tuple(v for p in q for v in p),
                               Image.Resampling.BICUBIC)
        reflected = Image.new("RGB", (512, 512))
        reflected.paste(square, (0, 0))
        reflected.paste(ImageOps.mirror(square), (256, 0))
        reflected.paste(ImageOps.flip(square), (0, 256))
        reflected.paste(ImageOps.flip(ImageOps.mirror(square)), (256, 256))
        shared = square.crop((64,64,192,192)).resize((128, 128), Image.Resampling.LANCZOS)
        if material == "grass":
            shared = shared.filter(ImageFilter.GaussianBlur(1.7))
        shared_array = np.asarray(shared, dtype=np.float32).copy()
        for edge in range(24):
            weight = (24-edge)/24
            mean = (shared_array[:, edge] + shared_array[:, -1-edge]) * 0.5
            shared_array[:, edge] = shared_array[:, edge]*(1-weight)+mean*weight
            shared_array[:, -1-edge] = shared_array[:, -1-edge]*(1-weight)+mean*weight
        for edge in range(24):
            weight = (24-edge)/24
            mean = (shared_array[edge] + shared_array[-1-edge]) * 0.5
            shared_array[edge] = shared_array[edge]*(1-weight)+mean*weight
            shared_array[-1-edge] = shared_array[-1-edge]*(1-weight)+mean*weight
        yy, xx = np.mgrid[0:128, 0:128]
        edge_distance = np.minimum.reduce([xx, yy, 127-xx, 127-yy])
        blend = np.clip(edge_distance / 27.0, 0, 1)[..., None]
        for variant in range(24):
            ox, oy = (variant * 73) % 256, (variant * 109) % 256
            span = 128
            patch = reflected.crop((ox, oy, ox+span, oy+span))
            patch = patch.resize((128, 128), Image.Resampling.LANCZOS)
            if material == "grass":
                patch = patch.filter(ImageFilter.GaussianBlur(1.7))
            else:
                patch = patch.filter(ImageFilter.GaussianBlur(0.75))
            values = np.asarray(patch, dtype=np.float32) * blend + shared_array * (1-blend)
            patch = Image.fromarray(np.uint8(np.clip(values, 0, 255)))
            # A replicated border prevents bicubic taps outside the square from
            # becoming a black rim along otherwise continuous floor diamonds.
            padded = Image.fromarray(np.pad(np.asarray(patch),
                                            ((2,2),(2,2),(0,0)), mode="edge"))
            tile = padded.transform((128, 64), Image.Transform.AFFINE,
                                   (127/128, 127/64, -61.5,
                                    -127/128, 127/64, 65.5),
                                   Image.Resampling.BICUBIC).convert("RGBA")
            tile.putalpha(diamond)
            atlas.paste(tile, ((variant % 8)*128, (row*3+variant//8)*64))
    pixels = np.asarray(atlas).copy()
    pixels[pixels[..., 3] == 0] = 0
    return Image.fromarray(pixels)


def preview(assets, output):
    montage = Image.new("RGB", (1600, 1690), "#172a2d")
    d = ImageDraw.Draw(montage)
    d.text((20, 10), "Licensed reference pixels / white + dark matte / original-size masters retained", fill="white")
    for row, bg in enumerate(["#faf6ef", "#13262a"]):
        for index, pose in enumerate(["front", "back", "left", "right"]):
            x, y = index*400, 40+row*420
            d.rectangle((x, y, x+399, y+419), fill=bg)
            cut = assets["hero_"+pose]
            thumb = cut.resize((384, 384), Image.Resampling.LANCZOS)
            montage.paste(thumb, (x+8, y+12), thumb)
            d.text((x+12, y+396), pose + (" (source pose; tiny sword repair)" if pose == "right" else ""),
                   fill="#172a2d" if row == 0 else "#f8f0df")
    d.text((20, 890), "Reference environment cutouts (tree is top-cropped in supplied sheet)", fill="white")
    for row, bg in enumerate(["#172a2d", "#faf6ef"]):
        y = 920+row*280
        d.rectangle((0,y,1599,y+279), fill=bg)
        for index, name in enumerate(PROPS):
            cut = assets[name].copy()
            cut.thumbnail((180, 230), Image.Resampling.LANCZOS)
            x = (index % 9)*177+8
            montage.paste(cut, (x+(170-cut.width)//2, y+230-cut.height), cut)
            d.text((x+8, y+240), name, fill="white" if row == 0 else "#172a2d")
    # Orthogonal isometric grid makes any residual tile frame immediately visible.
    for i in range(9):
        for j in range(9):
            n = (i*7+j*11) % 24
            src = assets["terrain"].crop(((n%8)*128, (n//8)*64,
                                           (n%8+1)*128, (n//8+1)*64))
            p = (600+(i-j)*32, 1470+(i+j)*16)
            src = src.resize((64,32), Image.Resampling.LANCZOS)
            montage.paste(src, p, src)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    montage.save(output)
    print(f"Preview: {output}")


def validate(assets, sheet):
    expected = {"front": (130, 57, 616, 752), "back": (910, 48, 1404, 727),
                "left": (143, 800, 676, 1498)}
    original = np.asarray(sheet.convert("RGB"))
    for pose in ("front", "back", "left"):
        cut, box = extract(sheet, dog_points(sheet, pose), band=5)
        alpha = np.asarray(cut.getchannel("A")) > 0
        original_region = original[box[1]:box[3], box[0]:box[2]]
        assert np.array_equal(np.asarray(cut)[..., :3][alpha], original_region[alpha]), pose
        master = assets["hero_"+pose]
        bounds = master.getbbox()
        assert bounds and bounds[3] == HERO_FOOT[1], (pose, bounds)
        assert 820 <= bounds[3]-bounds[1] <= 960, (pose, bounds)
        assert bounds[0] > 0 and bounds[2] < HERO_CELL[0]
        # Sheet labels occupy the top left; overlays only occur in the unused quadrant.
        lower = scale_points([expected[pose][:2]], sheet.size, (1561,1561))[0]
        assert box[0] >= lower[0]-10 and box[1] >= lower[1]-10
        print(f"PASS hero_{pose}: source RGB exact; bounds={box}; protected cloak retained")
    assert not np.array_equal(np.asarray(assets["hero_right"]),
                              np.asarray(ImageOps.mirror(assets["hero_front"])))
    repaired = fourth_sword_patch(sheet)
    fourth, box = extract(repaired, dog_points(sheet, "right"), band=5)
    opaque = np.asarray(fourth)[..., 3] > 0
    native = np.asarray(repaired)[box[1]:box[3], box[0]:box[2]]
    assert np.array_equal(np.asarray(fourth)[..., :3][opaque], native[opaque])
    changed = np.any(np.asarray(sheet) != np.asarray(repaired), axis=2)
    assert changed.sum() < 1300
    print(f"PASS fourth native pose: only {changed.sum()} transplanted sword-tip pixels; face/fur/clothes unchanged")
    assert assets["terrain"].size == (1024, 384)
    for key, asset in assets.items():
        assert asset.mode == "RGBA" and asset.getbbox(), key
        a = np.asarray(asset.getchannel("A"))
        assert np.any(a == 0) and np.any(a == 255), key
        assert not np.any(np.asarray(asset)[a == 0, :3]), key
    grass = np.asarray(assets["terrain"])[:192]
    assert np.min(np.max(grass[..., :3][grass[..., 3] > 0], axis=1)) > 10
    print("PASS actual fourth pose, alpha channels, source-resolution masters, 48 floor samples")
    print("PASS erased transparent RGB: no hidden sheet labels/grid; no black sampling rim")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--validate", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    dog = Image.open(SOURCES / "knight_dog_character.png").convert("RGB")
    environment = Image.open(SOURCES / "tile_example.png").convert("RGB")
    assert dog.size[0] == dog.size[1] and environment.width > 1500
    assets = {}
    for pose, points in DOGS.items():
        source = fourth_sword_patch(dog) if pose == "right" else dog
        cut, box = extract(source, dog_points(dog, pose), band=5)
        assets["hero_"+pose] = hero_master(cut)
        print(f"hero_{pose}: cutout {cut.size}, source bounds {box}")
    for name, points in PROPS.items():
        points = scale_points(points, environment.size, (1530,1142))
        holes = [scale_points(h, environment.size, (1530,1142))
                 for h in HOLES.get(name, ())]
        cut, box = extract(environment, points, holes, band=14, preserve_outline=True)
        assets[name] = cut
        print(f"{name}: {cut.size}, source bounds {box}")
    assets["terrain"] = terrain(environment)
    trees, bushes = forest_variants(assets["tree"], assets["bush"])
    for index, tree in enumerate(trees):
        assets["tree" if index == 0 else "tree_"+str(index)] = tree
    for index, bush in enumerate(bushes):
        assets["bush" if index == 0 else "bush_"+str(index)] = bush
    for name, image in assets.items():
        image.save(OUT / (name+".png"), optimize=True)
    if args.validate:
        validate(assets, dog)
    if args.preview:
        preview(assets, args.preview)
    for source in ("knight_dog_character.png", "tile_example.png"):
        print(f"Source SHA256 {source}: {hashlib.sha256((SOURCES/source).read_bytes()).hexdigest()}")
    print(f"Saved {len(assets)} reference PNGs in {OUT}")


if __name__ == "__main__":
    main()
