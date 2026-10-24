"""Bake original raster art. Run from any directory with Python and Pillow.

No reference images are opened: silhouettes and pixel clusters are authored here.
Ink contours separate silhouettes; teal ramps bind forest materials; cream and
brass reserve the strongest contrast for the dog, relics, and readable glyphs.
Atlas coordinates and foot anchors are shared with scripts/sanctuary_art.gd.
"""

from pathlib import Path
import hashlib
import math
import random

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sanctuary"
INK = "#09151d"
RAMPS = {
    "stone": ["#152c37", "#274550", "#3c6269", "#668a86"],
    "moss": ["#143a35", "#225345", "#39745a", "#7a9c64"],
    "leaf": ["#102e31", "#1a4940", "#2b6551", "#508565"],
    "bark": ["#142b30", "#294342", "#41625a", "#658574"],
    "cloth": ["#10151e", "#1b2630", "#2c3b43", "#46524f"],
    "fur": ["#191e24", "#303533", "#4c4b3b", "#72705a"],
    "tan": ["#674c37", "#9e7751", "#c6a476", "#e0c49a"],
    "cream": ["#8b8c7d", "#b9b8a0", "#e4d9b6", "#fff0ce"],
    "brass": ["#5c4835", "#937447", "#c3a567", "#f0d496"],
    "wood": ["#292c29", "#4d4a38", "#73704c", "#a29666"],
    "water": ["#102d3b", "#174653", "#276675", "#68a6a5"],
    "magic": ["#245651", "#3f8f76", "#80c69b", "#cfedb7"],
}


def rgba(color):
    from PIL import ImageColor
    return ImageColor.getcolor(color, "RGBA")


class Art:
    def __init__(self, size, seed=0):
        self.im = Image.new("RGBA", size)
        self.d = ImageDraw.Draw(self.im)
        self.rng = random.Random(seed)

    def poly(self, points, material, detail=0.12, width=2):
        ramp = RAMPS[material] if material in RAMPS else [material] * 4
        self.d.polygon(points, fill=ramp[1])
        mask = Image.new("L", self.im.size)
        ImageDraw.Draw(mask).polygon(points, fill=255)
        inner = mask.filter(ImageFilter.MinFilter(5))
        box = mask.getbbox()
        if box and detail:
            x0, y0, x1, y1 = box
            pixels = inner.load()
            # Small connected clusters, not smooth gradients or isolated noise.
            for _ in range(int((x1-x0)*(y1-y0)*detail/6)):
                x, y = self.rng.randrange(x0, x1), self.rng.randrange(y0, y1)
                if pixels[x, y]:
                    c = ramp[2] if self.rng.random() < 0.56 else ramp[0]
                    w, h = self.rng.choice([(3, 1), (2, 2), (4, 2), (2, 3)])
                    for dx in range(w):
                        for dy in range(h):
                            if x+dx < x1 and y+dy < y1 and pixels[x+dx, y+dy]:
                                self.im.putpixel((x+dx, y+dy), rgba(c))
        if width:
            self.d.line(points + [points[0]], fill=INK, width=width, joint="curve")

    def ellipse(self, box, material, width=2):
        ramp = RAMPS[material] if material in RAMPS else [material] * 4
        self.d.ellipse(box, fill=ramp[1], outline=INK, width=width)
        x0, y0, x1, y1 = box
        if x1-x0 > 8 and y1-y0 > 6:
            self.d.arc((x0+2, y0+2, x1-3, y1-3), 195, 290, ramp[2], 2)

    def line(self, points, color, width=1):
        self.d.line(points, fill=color, width=width, joint="curve")

    def rect(self, box, color):
        self.d.rectangle(box, fill=color)

    def sprig(self, x, y, scale=1, material="moss"):
        r = RAMPS[material]
        self.line([(x, y), (x-3*scale, y-7*scale)], r[1], 2)
        self.line([(x, y), (x+2*scale, y-10*scale)], r[2], 2)
        self.line([(x, y-2), (x+6*scale, y-6*scale)], r[3], 1)

    def rune(self, x, y, scale=1, color="#80b9ac"):
        self.line([(x-3*scale, y-5*scale), (x-3*scale, y+5*scale),
                   (x+3*scale, y+1*scale), (x-3*scale, y-2*scale),
                   (x+2*scale, y-5*scale)], color, 1 if scale == 1 else 2)


def diamond_mask():
    mask = Image.new("L", (128, 64))
    # Texel centers use an exact 2:1 diamond. Adjacent diamonds share boundaries.
    p = mask.load()
    for y in range(64):
        for x in range(128):
            if abs((x+0.5-64)/64) + abs((y+0.5-32)/32) <= 1:
                p[x, y] = 255
    return mask


DIAMOND = diamond_mask()


def ground(index):
    a = Art((128, 64), 400+index)
    r = a.rng
    material = ("moss" if index < 3 else "leaf") if index < 6 else "stone"
    ramp = RAMPS[material]
    a.rect((0, 0, 127, 63), ramp[1])
    # Draw in a periodic world-space texture, then clip. No dark seam outlines.
    for _ in range(210):
        x, y = r.randrange(128), r.randrange(64)
        w, h = r.randrange(3, 14), r.randrange(1, 4)
        c = r.choice(ramp[:3])
        a.d.polygon([(x,y), (x+w//2,y-1), (x+w,y), (x+w-2,y+h),
                     (x+2,y+h+1)], fill=c)
    if index >= 6:
        # Broken paving courses cross the diamond instead of framing each tile.
        for yy in [-12, 12, 36, 60, 84]:
            a.line([(-30, yy), (160, yy+20)], "#142e38", 2)
            for xx in range(-20, 160, 28):
                x = xx + (12 if yy % 48 else 0)
                y = yy + int((x+30)*20/190)
                a.line([(x,y), (x-3,y+9), (x+7,y+24)], "#172e36", 2)
                a.line([(x+2,y+2), (x+18,y+4)], "#53766f", 1)
        for _ in range(10):
            x, y = r.randrange(128), r.randrange(64)
            for j in range(5):
                a.rect((x+j*2, y+j%2, x+j*2+3, y+j%2+1), "#3c6853")
    else:
        for _ in range(42):
            x, y = r.randrange(128), r.randrange(64)
            a.sprig(x, y, 0.45)
        if index in (2, 4, 5):
            for _ in range(8):
                x, y = r.randrange(128), r.randrange(64)
                a.ellipse((x,y,x+5,y+2), "stone", 1)
        if index == 5:
            for x,y in [(33,31),(82,42),(65,15)]:
                a.rect((x,y,x+1,y+1), "#bdc18b")
    a.im.putalpha(DIAMOND)
    return a.im


def water(frame):
    a = Art((128,64), 227)
    a.rect((0,0,127,63), "#123b49")
    for i in range(50):
        x = (i*37 + frame*5) % 150 - 12
        y = (i*19) % 64
        w = 6 + i % 17
        a.line([(x,y),(x+w//2,y-2),(x+w,y-1)], ["#1d525e","#276b74","#468c8e"][i%3], 1+i%2)
        if i%6 == 0:
            a.line([(x+2,y+1),(x+5,y+1)], "#8ac1b1",1)
    a.im.putalpha(DIAMOND)
    return a.im


def bridge():
    a = Art((128,64), 923)
    a.rect((0,0,127,63), "#263833")
    for i in range(-5,10):
        x = i*14
        a.poly([(x,0),(x+12,0),(x+76,64),(x+64,64)], "wood", .3, 1)
        a.line([(x+3,0),(x+65,62)], "#93926b",1)
        a.line([(x+7,0),(x+28,22),(x+24,27),(x+48,51)], "#383d30",1)
    for i in range(4):
        x,y=23+i*23,18+i*7
        a.rect((x,y,x+2,y+2), "#c3a567")
    a.im.putalpha(DIAMOND)
    return a.im


def cliff(index):
    a = Art((128,96),600+index)
    a.poly([(0,0),(64,32),(128,0),(128,58),(64,94),(0,58)], "stone",.25)
    a.poly([(0,0),(64,32),(64,94),(0,58)], "#1d353e",.0)
    for x in range(4,128,11):
        y = int((x if x < 64 else 128-x)*.5)
        a.line([(x,y+5),(x-2,y+20),(x+2,y+32),(x-1,min(88,y+58))], "#0e252e",2)
        a.line([(x+3,y+8),(x+2,y+22),(x+4,y+31)], "#496a66",1)
    for x in range(0,128,4):
        y = int((x if x<64 else 128-x)*.5)
        a.line([(x,y),(x+2,y+3),(x+1,y+7+((x*7)%9))], "#3e7256",3)
        a.rect((x,y,x+2,y+1), "#6c9467")
    for x,y in [(21,23),(80,38),(101,15)]:
        a.line([(x,y),(x+4,y+17),(x-1,y+27),(x+6,y+39)], "#102527",4)
        a.line([(x,y),(x+4,y+17),(x-1,y+27),(x+6,y+39)], "#527062",1)
    return a.im


def mushroom(a,x,y,s=1):
    a.poly([(x-2*s,y),(x-1*s,y-18*s),(x+3*s,y-19*s),(x+4*s,y)], "cream",.1,1)
    a.poly([(x-13*s,y-17*s),(x-10*s,y-25*s),(x-2*s,y-31*s),
            (x+5*s,y-30*s),(x+13*s,y-21*s),(x+11*s,y-16*s)], "magic",.2,2)
    a.line([(x-10*s,y-17*s),(x,y-14*s),(x+11*s,y-16*s)], "#112f32",2)
    for dx,dy in [(-5,-23),(3,-26),(6,-20)]:
        a.rect((x+dx*s,y+dy*s,x+(dx+2)*s,y+(dy+1)*s), "#b8e2aa")


def root(a, points, width=10):
    curve = []
    padded = [points[0]] + points + [points[-1]]
    for i in range(1, len(padded)-2):
        p0,p1,p2,p3 = padded[i-1:i+3]
        for j in range(12):
            t=j/12
            curve.append(tuple(.5*((2*p1[k])+(-p0[k]+p2[k])*t+
                               (2*p0[k]-5*p1[k]+4*p2[k]-p3[k])*t*t+
                               (-p0[k]+3*p1[k]-3*p2[k]+p3[k])*t*t*t)
                               for k in [0,1]))
    curve.append(points[-1])
    for extra,color in [(4,INK),(0,"#294c44")]:
        for i,p in enumerate(curve):
            taper = 1 - .82*(i/(len(curve)-1))**2
            radius=(width*taper+extra)/2
            a.d.ellipse((p[0]-radius,p[1]-radius,p[0]+radius,p[1]+radius),
                        fill=color)
    a.line([(x-width*.2,y-width*.2) for x,y in curve[:-3]], "#658575",
           max(1,width//7))


def tree(a,variant):
    shift=variant*5
    # Root buttresses and the forked, hollow trunk remain visible below foliage.
    for points,w in [
        ([(120,226),(95,268),(56,291),(29,295)],13),
        ([(132,235),(155,265),(189,280),(219,278)],17),
        ([(121,247),(121,284),(96,303),(71,303)],14),
        ([(137,247),(143,293),(166,307),(187,303)],10),
    ]:
        root(a,points,w)
    a.poly([(91,281),(107,235),(108,181),(97,145),(100,108),(124,98),
            (148,119),(147,181),(153,232),(175,286),(148,277),(132,256),
            (122,278)],"bark",.28,3)
    a.poly([(117,249),(119,180),(111,147),(122,125),(136,146),(132,202),
            (138,258),(128,243)],"#122e30",0,1)
    for points in [
        [(106,259),(117,226),(116,190),(110,172)],
        [(145,255),(136,223),(144,180),(137,150)],
        [(102,155),(114,163),(123,151),(120,123)],
        [(143,185),(140,162),(147,143)],
    ]:
        a.line(points,"#52786a",2)
    # Contour-following bark plates model a twisted trunk around its hollow.
    for i in range(8):
        x=105+i*5
        y=146+(i*29)%65
        a.line([(x,y),(x-2,y+9),(x+1,y+17),(x-2,y+27)],"#132f32",2)
        a.line([(x+2,y+2),(x+1,y+9),(x+3,y+15)],"#6b8974",1)
    root(a,[(119,186),(93,162),(65,154),(46,129)],13)
    root(a,[(141,162),(161,141),(176,116),(198,103)],12)
    a.ellipse((113,198,130,225),"cloth")
    a.line([(120,205),(117,213),(120,220)],"#36564d",1)
    # Overlapping leaf fans: individual serrated clusters, lit only on the crown.
    rng=a.rng
    fans=[(46,112,31),(76,82,36),(114,64,40),(154,73,39),
          (194,102,35),(209,136,29),(174,151,33),(132,129,41),
          (84,138,35),(47,151,25)]
    for cx,cy,rad in fans:
        cy += shift if cx<100 else -shift
        pts=[]
        for i in range(28):
            ang=i*math.tau/28
            rr=rad*(1 if i%2 else .86) + rng.randrange(-3,3)
            pts.append((int(cx+math.cos(ang)*rr),int(cy+math.sin(ang)*rr*.65)))
        a.poly(pts,"leaf",.2,3)
        for j in range(24):
            x=cx+rng.randrange(-rad+5,rad-5)
            y=cy+rng.randrange(-rad//3,rad//3)
            a.poly([(x,y),(x+5,y-3),(x+11,y-2),(x+6,y+2)],
                   rng.choice(["#316e56","#3d7b5e","#255849","#548866"]),0,0)
        a.line([(cx-rad//2,cy-rad//3),(cx-3,cy-rad//2),
                (cx+9,cy-rad//2+2)],"#729368",1)
    for x,y in [(52,294),(156,286),(183,282)]:
        a.sprig(x,y,.9)
    mushroom(a,91,295,.55)


def pillar(a,broken=False):
    a.poly([(79,286),(122,265),(169,284),(128,308)],"stone",.15,3)
    a.poly([(79,274),(126,251),(172,272),(172,286),(128,308),(79,286)],"stone",.2)
    a.poly([(87,263),(127,246),(164,261),(128,280)],"stone",.13)
    a.poly([(99,264),(99,91 if not broken else 165),(119,80 if not broken else 145),
            (151,94 if not broken else 160),(151,263),(127,276)],"stone",.28,3)
    a.poly([(101,104 if not broken else 170),(117,108 if not broken else 163),
            (117,264),(103,257)],"#537972",.0,0)
    for x in [122,137,147]:
        a.line([(x,112 if not broken else 175),(x,263)],"#1c3841",2)
    if not broken:
        a.poly([(86,85),(126,68),(165,86),(165,107),(126,122),(86,103)],"stone",.2)
        a.poly([(88,83),(126,65),(166,83),(126,101)],"stone",.2)
        a.line([(94,83),(127,70),(156,82)],"#93a894",2)
    else:
        a.poly([(99,166),(105,148),(121,153),(130,145),(151,160),(127,174)],
               "stone",.2)
    for yy in range(133 if not broken else 197,240,27):
        a.rune(130,yy,1,"#86a28b")
    a.line([(147,198),(136,211),(141,223),(130,234)],INK,2)
    root(a,[(144,278),(149,245),(134,231),(141,210),(151,202)],5)
    for x,y in [(88,282),(96,270),(146,273),(136,295)]:
        a.sprig(x,y,.85)


def gate(a):
    for dx in [-65,65]:
        a.poly([(111+dx,287),(111+dx,157),(145+dx,157),(145+dx,287),
                (128+dx,296)],"stone",.2,3)
        a.poly([(105+dx,157),(105+dx,142),(128+dx,133),(151+dx,142),
                (151+dx,157),(128+dx,166)],"stone",.16)
        for yy in [179,219,260]:
            a.line([(112+dx,yy),(129+dx,yy+7),(145+dx,yy)],INK,2)
    # Voussoirs make a real hollow arch, not an opaque rectangle.
    for i in range(9):
        t0=math.pi+i*math.pi/9
        t1=t0+math.pi/9
        pts=[(int(128+math.cos(t0)*96),int(151+math.sin(t0)*88)),
             (int(128+math.cos(t1)*96),int(151+math.sin(t1)*88)),
             (int(128+math.cos(t1)*66),int(151+math.sin(t1)*56)),
             (int(128+math.cos(t0)*66),int(151+math.sin(t0)*56))]
        a.poly(pts,"stone",.2,3)
    a.rune(129,82,2,"#d3c18b")
    for x in range(67,198,16):
        a.line([(x,159),(x,281)],"#122b31",5)
        a.line([(x-1,160),(x-1,278)],"#47625d",1)
        a.poly([(x-5,164),(x,151),(x+5,164)],"brass",.1,1)
    for y in [193,253]:
        a.line([(65,y),(191,y)],INK,7)
        a.line([(65,y-1),(191,y-1)],"#3b5957",3)
    root(a,[(43,280),(54,250),(41,221),(49,191)],7)
    for x,y in [(47,146),(57,132),(67,112),(189,140),(198,155)]:
        a.sprig(x,y,.8)


def chest(a):
    a.poly([(69,253),(119,228),(182,251),(182,287),(130,311),(69,284)],
           "wood",.3,3)
    a.poly([(72,254),(129,277),(129,306),(72,282)],"wood",.25)
    a.poly([(131,276),(180,253),(180,284),(131,307)],"#343e36",0)
    a.poly([(68,251),(74,233),(91,217),(119,214),(176,236),(184,252),
            (130,278)],"stone",.28,3)
    for offset in [0,43]:
        a.poly([(84+offset,226),(91+offset,222),(148+offset,245),
                (143+offset,253),(143+offset,294),(136+offset,297),
                (136+offset,257),(80+offset,235)],"brass",.15,1)
    a.line([(73,253),(130,276),(179,254)],"#d0b778",2)
    a.poly([(120,274),(134,278),(134,293),(121,288)],"brass",.12)
    a.rect((125,280,128,286),INK)
    for x,y in [(77,260),(78,277),(171,263),(171,280)]:
        a.rect((x,y,x+2,y+2),"#e2cb8c")


def urn(a):
    a.poly([(107,227),(105,218),(112,211),(143,211),(151,218),(147,228),
            (157,241),(162,264),(156,288),(142,303),(116,303),
            (101,287),(95,262),(100,243)],"stone",.3,3)
    a.ellipse((104,210,151,226),"stone")
    a.ellipse((111,213,144,221),"cloth",1)
    a.line([(102,252),(113,260),(124,251),(136,263),(155,254)],"#89a092",2)
    a.line([(108,285),(119,294),(141,294),(151,283)],"#527b72",2)
    a.line([(150,233),(142,245),(147,256),(140,269),(147,280)],INK,2)
    a.rune(126,276,1)


def rock(a):
    a.poly([(62,280),(74,246),(101,233),(134,238),(151,230),
            (181,256),(193,283),(164,305),(104,308)],"stone",.35,3)
    a.poly([(66,280),(96,263),(132,268),(156,250),(181,259),
            (151,288),(112,297)],"#3d5d60",0,1)
    a.line([(77,250),(101,240),(129,246)],"#7a9383",2)
    a.line([(130,241),(125,261),(138,275),(129,298)],"#142f39",2)
    for x,y in [(88,267),(104,254),(149,243),(170,277)]:
        for j in range(5):
            a.sprig(x+j*3,y+j%3,.65)


def bush(a):
    for i in range(24):
        x=70+(i*31)%113
        y=259+(i*13)%40
        a.poly([(x-12,y+9),(x-19,y-6),(x-12,y-14),(x-2,y-7),
                (x+1,y-29),(x+8,y-30),(x+11,y-13),(x+22,y-19),
                (x+25,y-11),(x+13,y+8)],"leaf",.25)
        a.line([(x,y+6),(x+3,y-13)],"#5a8f67",1)


def roots(a):
    for i in range(6):
        yy=278+i*4
        root(a,[(50,yy),(78,yy-17),(116,yy-9),(151,yy-27),
                (188,yy-21),(213,yy-34)],8-i%3)
    for i in range(12):
        x=60+i*12
        a.poly([(x,278-i%4*3),(x-5,260-i%4*3),(x+8,272-i%4*3)],
               "bark",.15,1)


def torch(a):
    a.poly([(100,287),(125,273),(152,286),(128,301)],"stone",.2)
    a.poly([(111,281),(111,230),(143,230),(143,281),(127,291)],"stone",.2)
    a.poly([(98,218),(126,205),(155,218),(146,238),(125,247),(105,235)],
           "brass",.15)
    a.poly([(113,221),(104,206),(115,189),(113,172),(124,184),
            (138,155),(136,189),(149,181),(144,211),(131,228)],"magic",.1)
    a.poly([(122,221),(117,207),(128,189),(128,209),(137,202),(132,220)],
           "#d9eec3",0,0)
    a.rune(127,261,1)


def statue(a):
    a.poly([(78,291),(126,267),(179,288),(131,314)],"stone",.3)
    a.poly([(95,279),(100,223),(106,166),(98,151),(108,139),
            (145,140),(158,158),(146,173),(155,224),(161,282),
            (127,298)],"stone",.25,3)
    a.poly([(113,143),(103,122),(106,95),(118,80),(139,85),(149,102),
            (144,129),(133,145)],"stone",.2)
    a.poly([(112,103),(121,100),(125,104),(120,109)],"#0d2930",0,0)
    a.poly([(133,102),(143,103),(138,109),(131,107)],"#0d2930",0,0)
    a.line([(123,118),(132,121),(137,116)],"#91a694",1)
    a.line([(109,156),(120,191),(110,255),(119,278)],"#6b8f7d",3)
    a.line([(147,155),(135,193),(144,261)],"#133039",3)
    root(a,[(112,279),(120,250),(115,228),(127,208),(133,176),(139,146)],5)
    for x,y in [(111,98),(144,149),(158,280)]:
        a.sprig(x,y,.8)


def crate(a):
    a.poly([(77,244),(124,223),(179,247),(179,286),(130,309),(77,284)],
           "wood",.3,3)
    for i in range(4):
        a.line([(79+i*13,247+i*5),(79+i*13,283+i*5)],"#242d29",2)
        a.line([(132+i*12,268-i*5),(132+i*12,306-i*5)],"#242d29",2)
    a.line([(81,251),(126,302)],INK,9)
    a.line([(81,251),(126,302)],"#9d9364",5)
    a.line([(176,254),(134,301)],INK,8)
    a.line([(176,254),(134,301)],"#777c57",4)
    a.line([(79,244),(129,266),(177,246)],"#aca16d",3)


def stairs(a):
    for i in range(7):
        y=286-i*16
        hw=79-i*3
        a.poly([(128-hw,y),(128,y-hw//2),(128+hw,y),(128+hw,y+12),
                (128,y+hw//2+12),(128-hw,y+12)],"stone",.18)
        a.line([(128-hw,y),(128,y+hw//2),(128+hw,y)],"#789484",2)
    for x,y in [(51,281),(187,262),(73,236)]:
        a.sprig(x,y,.8)


def props():
    sheet=Image.new("RGBA",(1024,1280))
    names=["tree","tree_1","tree_2","pillar","pillar_broken","gate","chest","urn",
           "rock","bush","mushrooms","roots","torch","statue","crate","stairs"]
    for i,name in enumerate(names):
        a=Art((256,320),1000+i)
        if name.startswith("tree"):
            tree(a,i)
        elif name == "pillar":
            pillar(a)
        elif name == "pillar_broken":
            pillar(a,True)
        elif name == "mushrooms":
            for x,y,s in [(97,292,.75),(143,299,1.3),(174,306,.62),(119,310,.45)]:
                mushroom(a,x,y,s)
            for x in [84,120,158,184]:
                a.sprig(x,309,.7)
        else:
            globals()[name](a)
        sheet.alpha_composite(a.im,((i%4)*256,(i//4)*320))
    return sheet


def boot(a,x,y,lean=0):
    a.poly([(x-8,y-19),(x+7,y-19),(x+7+lean,y-4),(x+11+lean,y+1),
            (x+10+lean,y+5),(x-10+lean,y+5),(x-11,y-2)],"cloth",.2)
    a.poly([(x-8+lean,y-1),(x-4+lean,y-5),(x+3+lean,y-5),(x+9+lean,y),
            (x+8+lean,y+3),(x-9+lean,y+3)],"cream",.1,1)
    for yy in [y-15,y-10]:
        a.line([(x-7,yy),(x+6,yy+2)],"#866b48",2)
    for dx in [-4,1,6]:
        a.line([(x+dx+lean,y),(x+dx+lean,y+3)],"#686e63",1)


def hero(frame,direction):
    a=Art((128,160),2000+direction*30)
    # Columns: idle, four articulated walk poses, three sword attack poses.
    walk=frame in range(1,5)
    gait=[0,-5,0,5,0,0,-3,0][frame]
    bob=[0,-1,-3,-1,0,-2,-3,1][frame]
    attack=frame>=5
    back=direction==3
    side=direction in [1,2]
    # Tail curls independently and never changes the foot anchor.
    a.poly([(79,111+bob),(96,112+bob),(105,103+bob),(111,88+bob),
            (115,101+bob),(111,120+bob),(100,129+bob),(82,127+bob)],
           "fur",.2)
    a.poly([(90,124+bob),(104,118+bob),(111,107+bob),(109,120+bob),
            (100,130+bob),(90,130+bob)],"cream",.1,1)
    for x,step in [(49,gait),(77,-gait)]:
        a.poly([(x-9,109+bob),(x+8,109+bob),(x+9,129+step),
                (x-6,135+step)],"fur",.2)
        boot(a,x,146+step//2,step//2)
    cloakhem=123 if back else 115
    a.poly([(33,64+bob),(49,56+bob),(76,56+bob),(91,69+bob),
            (95,101+bob),(103+gait,cloakhem+bob),(86,121+bob),
            (73,116+bob),(62,125+bob),(47,117+bob),(26-gait,122+bob),
            (31,99+bob)],"cloth",.23,3)
    a.line([(37,73+bob),(41,94+bob),(34-gait,113+bob)],"#42514e",2)
    a.line([(83,75+bob),(80,96+bob),(87,113+bob)],"#111a23",3)
    if back:
        a.line([(45,73+bob),(64,85+bob),(81,73+bob)],"#4c5952",2)
        a.line([(47,84+bob),(62,95+bob),(77,85+bob)],"#2f3e43",2)
        a.line([(62,95+bob),(57,115+bob)],"#526053",1)
        a.poly([(51,63+bob),(63,69+bob),(77,63+bob),(72,77+bob),
                (61,81+bob),(50,75+bob)],"cloth",.15)
    else:
        a.poly([(47,72+bob),(76,71+bob),(82,99+bob),(70,117+bob),
                (48,111+bob),(41,90+bob)],"fur",.15)
        a.poly([(49,76+bob),(61,81+bob),(75,74+bob),(74,95+bob),
                (64,105+bob),(50,98+bob)],"cream",.12)
        a.poly([(49,79+bob),(55,83+bob),(55,94+bob),(64,101+bob),
                (53,97+bob),(48,89+bob)],"#999f8c",0,0)
        a.line([(58,85+bob),(66,87+bob),(72,83+bob)],"#f4e6c5",2)
        a.line([(47,80+bob),(62,86+bob),(76,78+bob)],"#929886",2)
        a.line([(51,96+bob),(61,91+bob),(71,97+bob)],"#7d8978",1)
        a.line([(47,72+bob),(77,103+bob)],INK,7)
        a.line([(47,72+bob),(77,103+bob)],"#80674b",4)
        a.line([(45,105+bob),(80,109+bob)],INK,7)
        a.line([(45,105+bob),(80,109+bob)],"#745d42",4)
        a.rect((61,103+bob,68,111+bob),"#c2a570")
        a.rect((63,105+bob,66,109+bob),INK)
        a.poly([(54,113+bob),(72,114+bob),(68,131+bob),(61,126+bob),
                (54,133+bob)],"wood",.18)
    # Actual arm positions and sword arcs vary in attack frames.
    ax=29-(gait//2)
    ay=92+bob
    a.poly([(35,72+bob),(43,78+bob),(40,96+bob),(ax+5,111+bob),
            (ax-6,109+bob),(ax-7,99+bob)],"fur",.2)
    a.poly([(ax-7,97+bob),(ax+8,100+bob),(ax+4,113+bob),
            (ax-8,110+bob)],"wood",.2)
    a.ellipse((ax-8,108+bob,ax+5,121+bob),"cream")
    for yy in range(100,111,4):
        a.line([(ax-5,yy+bob),(ax+5,yy+2+bob)],"#ab8857",1)
    rx=92+gait//2
    ry=113+bob
    if attack:
        rx,ry=[(96,64),(105,92),(91,121)][frame-5]
    a.poly([(83,72+bob),(91,78+bob),(rx+5,ry-12),(rx+3,ry),
            (rx-7,ry),(rx-8,ry-13),(78,88+bob)],"fur",.2)
    a.poly([(rx-9,ry-15),(rx+6,ry-15),(rx+6,ry-2),(rx-7,ry)],
           "wood",.2)
    a.ellipse((rx-8,ry-2,rx+5,ry+9),"cream")
    # Blade has a stepped bevel and a brass crossguard, not a flat triangle.
    if frame==5:
        tip=(111,26)
    elif frame==6:
        tip=(126,69)
    elif frame==7:
        tip=(119,150)
    else:
        tip=(107,143+bob)
    tx,ty=tip
    vx,vy=tx-rx,ty-ry
    length=max(1,math.hypot(vx,vy))
    nx,ny=-vy/length*4,vx/length*4
    a.poly([(rx+nx,ry+ny),(rx+vx*.77+nx,ry+vy*.77+ny),(tx,ty),
            (rx+vx*.77-nx,ry+vy*.77-ny),(rx-nx,ry-ny)],"stone",.08,2)
    a.line([(rx,ry),(tx-1,ty-2)],"#d2dfcd",2)
    a.line([(rx+nx*1.8,ry+ny*1.8),(rx-nx*1.8,ry-ny*1.8)],INK,5)
    a.line([(rx+nx*1.7,ry+ny*1.7),(rx-nx*1.7,ry-ny*1.7)],"#cfaf6b",3)
    # Layered mantle and a leaf-shaped clasp.
    a.poly([(35,65+bob),(46,58+bob),(78,57+bob),(89,66+bob),
            (81,78+bob),(60,83+bob),(40,76+bob)],"cloth",.16)
    a.line([(39,67+bob),(60,75+bob),(80,67+bob)],"#4a5956",2)
    if not back:
        a.ellipse((76,67+bob,85,77+bob),"brass")
        a.rect((79,70+bob,81,73+bob),"#a5d0ac")
    # Upright canine ears, broken cheek fur and cream muzzle are hand-authored.
    if side:
        a.poly([(43,46+bob),(38,21+bob),(42,8+bob),(53,22+bob),
                (67,22+bob),(77,9+bob),(84,34+bob),(85,49+bob),
                (99,49+bob),(101,58+bob),(89,65+bob),(73,67+bob),
                (64,72+bob),(48,65+bob),(38,55+bob)],"fur",.2,3)
        a.poly([(44,18+bob),(49,31+bob),(43,36+bob)],"tan",.1,1)
        a.poly([(76,18+bob),(80,33+bob),(72,30+bob)],"tan",.1,1)
        a.poly([(47,38+bob),(54,30+bob),(66,29+bob),(70,34+bob),
                (57,36+bob),(51,43+bob)],"#555746",0,0)
        a.line([(44,40+bob),(41,44+bob),(46,43+bob),(43,49+bob)],
               "#6b6a53",1)
        a.poly([(75,49+bob),(84,46+bob),(89,50+bob),(99,51+bob),
                (98,58+bob),(86,64+bob),(72,64+bob),(68,59+bob)],
               "cream",.1,1)
        a.poly([(71,38+bob),(79,36+bob),(85,40+bob),(77,41+bob)],"tan",0,0)
        a.line([(74,45+bob),(82,45+bob)],INK,3)
        a.rect((77,43+bob,80,45+bob),"#e8e8ce")
        a.rect((80,43+bob,81,46+bob),INK)
        a.poly([(93,49+bob),(101,50+bob),(100,55+bob),(95,55+bob)],
               "#0b151d",0,0)
        a.line([(86,59+bob),(94,59+bob),(98,56+bob)],"#3c413c",1)
        a.line([(76,61+bob),(84,62+bob),(93,58+bob)],"#fff0ce",1)
        a.line([(44,46+bob),(52,42+bob),(58,45+bob)],"#646453",1)
    else:
        a.poly([(40,44+bob),(38,24+bob),(43,9+bob),(55,26+bob),
                (69,26+bob),(82,9+bob),(88,29+bob),(84,47+bob),
                (90,52+bob),(82,57+bob),(84,62+bob),(72,68+bob),
                (63,73+bob),(50,67+bob),(41,63+bob),(44,58+bob),
                (35,54+bob)],"fur",.2,3)
        if back:
            a.line([(44,20+bob),(47,33+bob)],"#6d7058",2)
            a.line([(79,19+bob),(80,32+bob)],"#5a634e",2)
            a.line([(49,48+bob),(60,43+bob),(73,49+bob)],"#525949",2)
            a.line([(51,61+bob),(61,64+bob),(73,59+bob)],"#1b292e",3)
        else:
            a.poly([(43,18+bob),(50,31+bob),(42,36+bob)],"tan",.1,1)
            a.poly([(80,18+bob),(83,34+bob),(74,30+bob)],"tan",.1,1)
            a.poly([(44,34+bob),(51,30+bob),(58,31+bob),(55,36+bob),
                    (49,36+bob)],"#535643",0,0)
            a.poly([(66,31+bob),(73,30+bob),(81,34+bob),(77,37+bob),
                    (69,35+bob)],"#535643",0,0)
            for x in [46,71]:
                a.poly([(x,39+bob),(x+7,36+bob),(x+11,40+bob),(x+1,42+bob)],
                       "tan",0,0)
                a.line([(x+1,46+bob),(x+9,46+bob)],INK,4)
                a.rect((x+3,44+bob,x+7,46+bob),"#f5e4bf")
                a.rect((x+6,44+bob,x+7,47+bob),INK)
            a.poly([(44,51+bob),(52,48+bob),(61,52+bob),(69,50+bob),
                    (79,50+bob),(83,56+bob),(76,65+bob),(62,68+bob),
                    (49,63+bob)],"cream",.1,1)
            a.poly([(57,51+bob),(68,51+bob),(69,55+bob),(63,59+bob),
                    (57,55+bob)],"#121b22",0,1)
            a.line([(52,59+bob),(59,62+bob),(69,62+bob),(75,59+bob)],
                   "#50574d",1)
            a.line([(48,55+bob),(53,57+bob),(54,60+bob)],"#fff0ce",2)
            a.line([(73,54+bob),(78,55+bob),(75,59+bob)],"#fff0ce",2)
            a.line([(61,29+bob),(63,35+bob)],"#cfbe90",2)
    if direction==1:
        a.im=a.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return a.im


def crawler(frame,direction):
    a=Art((128,160),3100)
    gait=[0,-6,0,6,0,-3,4,1][frame]
    bob=[0,0,-2,0,0,-2,-4,0][frame]
    # Low quadruped, hunched thorn mane and a hooked tail.
    root(a,[(28,105+bob),(15,92+bob),(14,79+bob),(25,74+bob)],5)
    for x,step in [(39,gait),(76,-gait),(53,-gait),(92,gait)]:
        a.poly([(x-5,109+bob),(x+5,110+bob),(x+7+step,136),
                (x+14+step,141),(x+13+step,146),(x+step-6,145),
                (x+step-7,135)],"bark",.23)
        for dx in [0,5,10]:
            a.line([(x+step+dx,141),(x+step+dx+2,146)],"#c3c39a",2)
    a.poly([(25,111+bob),(25,95+bob),(38,79+bob),(59,77+bob),
            (79,85+bob),(90,95+bob),(91,119+bob),(75,129+bob),
            (47,125+bob)],"bark",.3,3)
    for i in range(8):
        x=32+i*6
        a.poly([(x,92+bob),(x-3,68-i%3*7+bob),(x+13,86+bob),
                (x+10,102+bob)],"leaf",.13)
        a.line([(x+1,87+bob),(x-1,75-i%3*7+bob)],"#6d9477",1)
    front=direction==0
    hx=78 if direction in [1,2] else 61
    hy=91+bob
    a.poly([(hx-17,hy+11),(hx-21,hy-12),(hx-15,hy-33),
            (hx-5,hy-22),(hx+9,hy-23),(hx+20,hy-37),
            (hx+24,hy-13),(hx+20,hy+1),(hx+31,hy+8),
            (hx+29,hy+19),(hx+13,hy+27),(hx-4,hy+21)],"bark",.25,3)
    if direction!=3:
        a.poly([(hx+6,hy+5),(hx+17,hy+3),(hx+29,hy+9),
                (hx+26,hy+17),(hx+12,hy+21),(hx+2,hy+16)],"stone",.1)
        a.line([(hx+20,hy+20),(hx+12,hy+25),(hx+6,hy+19)],"#cfcea4",2)
        for x in [hx-6,hx+12] if front else [hx+9]:
            a.line([(x,hy-6),(x+7,hy-8)],INK,5)
            a.line([(x,hy-6),(x+6,hy-8)],"#bddc9d",2)
        a.rect((hx+24,hy+7,hx+30,hy+12),INK)
    else:
        for i in range(4):
            a.poly([(hx-16+i*9,hy),(hx-19+i*9,hy-16),
                    (hx-8+i*9,hy-4)],"leaf",.13)
    if direction==1:
        a.im=a.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return a.im


def archer(frame,direction):
    a=Art((128,160),4100)
    step=[0,-4,0,4,0,0,-4,2][frame]
    bob=[0,0,-2,0,0,-1,-3,0][frame]
    back=direction==3
    a.poly([(36,69+bob),(49,56+bob),(76,57+bob),(91,72+bob),
            (84,101+bob),(92,140),(82+step,135),(73,150),
            (64,141),(55-step,151),(48,139),(32,145),(39,112+bob)],
           "leaf",.28,3)
    for x in [42,55,69,80]:
        a.line([(x,81+bob),(x-3+step//2,112),(x+step,136)],
               "#122b31",3)
        a.line([(x+3,86+bob),(x+1,112),(x+3+step,133)],"#497762",1)
    a.poly([(42,62+bob),(38,45+bob),(43,22+bob),(58,11+bob),
            (76,18+bob),(87,43+bob),(82,64+bob),(65,77+bob)],
           "leaf",.18,3)
    if not back:
        a.poly([(47,43+bob),(57,30+bob),(72,33+bob),(79,47+bob),
                (72,66+bob),(62,71+bob),(51,61+bob)],"wood",.2)
        a.poly([(48,43+bob),(60,47+bob),(56,52+bob),(49,50+bob)],
               INK,0,0)
        a.poly([(64,47+bob),(77,43+bob),(75,51+bob),(65,52+bob)],
               INK,0,0)
        a.rect((52,47+bob,56,48+bob),"#b8d6a1")
        a.rect((66,47+bob,71,48+bob),"#b8d6a1")
        a.line([(61,38+bob),(60,60+bob),(65,63+bob)],"#c1bd8b",1)
        a.line([(54,28+bob),(61,21+bob),(70,28+bob)],"#799576",2)
    else:
        a.line([(56,25+bob),(50,45+bob),(61,62+bob)],"#4c7c64",2)
        a.poly([(79,73+bob),(88,76+bob),(81,113+bob),(73,114+bob)],
               "wood",.1)
        for x in range(78,90,4):
            a.line([(x,83),(x+4,55)],"#a0ab83",1)
            a.line([(x+4,55),(x+1,58)],"#d2ceb0",2)
    # Bow is asymmetrical living wood; drawn string and arrow visibly articulate.
    draw=9 if frame==6 else 3 if frame==5 else 0
    a.poly([(36,78+bob),(41,87+bob),(32,100+bob),(23,95+bob)],
           "bark",.15)
    a.poly([(81,79+bob),(89,84+bob),(83-draw,102+bob),(73-draw,100+bob)],
           "bark",.15)
    a.line([(24,60+bob),(15,74+bob),(13,93+bob),(18,112+bob),(26,125+bob)],
           INK,6)
    a.line([(24,60+bob),(15,74+bob),(13,93+bob),(18,112+bob),(26,125+bob)],
           "#a99b65",3)
    a.line([(24,61+bob),(45+draw,96+bob),(26,124+bob)],"#e1d4a8",1)
    a.line([(12,97+bob),(77-draw,97+bob)],"#b6c3a5",2)
    a.poly([(10,97+bob),(19,92+bob),(18,101+bob)],"stone",.1,1)
    for x,y in [(36,62),(77,65),(42,125)]:
        a.sprig(x,y+bob,.6)
    if direction==1:
        a.im=a.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return a.im


def brute(frame,direction):
    a=Art((160,192),5100)
    step=[0,-5,0,5,0,0,-4,2][frame]
    bob=[0,0,-2,0,0,-3,-4,1][frame]
    for x,s in [(58,step),(101,-step)]:
        a.poly([(x-13,139+bob),(x+12,137+bob),(x+15,166+s),
                (x+20,174+s//2),(x+16,183+s//2),(x-17,182+s//2),
                (x-18,170+s)],"stone",.28,3)
        a.line([(x-13,171+s),(x+10,174+s)],"#67887c",2)
    a.poly([(41,73+bob),(67,61+bob),(100,64+bob),(122,85+bob),
            (113,137+bob),(99,155+bob),(56,151+bob),(42,130+bob)],
           "stone",.32,3)
    a.poly([(51,90+bob),(75,81+bob),(103,91+bob),(103,121+bob),
            (77,138+bob),(50,121+bob)],"stone",.2)
    a.line([(55,95+bob),(74,90+bob),(95,97+bob)],"#92a38b",2)
    a.line([(77,93+bob),(78,123+bob)],"#1a3740",3)
    a.rune(78,109+bob,2,"#a5c49a")
    for x in [34,112]:
        a.poly([(x-15,78+bob),(x-9,63+bob),(x+13,60+bob),(x+24,78+bob),
                (x+18,98+bob),(x,103+bob),(x-14,94+bob)],"stone",.32,3)
        a.line([(x-8,70+bob),(x+11,66+bob),(x+18,77+bob)],"#849982",2)
        a.poly([(x-3,62+bob),(x,47+bob),(x+7,61+bob)],"brass",.08)
    a.poly([(62,65+bob),(57,47+bob),(63,28+bob),(80,22+bob),
            (101,34+bob),(104,56+bob),(93,72+bob),(74,78+bob)],
           "stone",.24,3)
    if direction !=3:
        a.poly([(62,45+bob),(76,49+bob),(100,43+bob),(98,53+bob),
                (77,59+bob),(63,53+bob)],"cloth",.0)
        a.line([(66,49+bob),(76,53+bob),(95,48+bob)],"#abc7a0",2)
        a.line([(81,58+bob),(80,70+bob)],"#9da98e",2)
    else:
        a.line([(68,35+bob),(83,42+bob),(98,36+bob)],"#8a9d86",2)
    # Root lashings wrap angular armor, linking the guardian to the ruins.
    root(a,[(49,136+bob),(57,126+bob),(52,110+bob),(63,100+bob)],4)
    root(a,[(106,145+bob),(96,126+bob),(112,110+bob)],4)
    a.poly([(24,102+bob),(40,104+bob),(42,139+bob),(32,150+bob),
            (19,138+bob)],"stone",.25)
    a.poly([(116,99+bob),(133,102+bob),(139,130+bob),(130,144+bob),
            (114,132+bob)],"stone",.25)
    # Heavy hewn maul changes angle in the attack columns.
    xx=139 if frame<5 else 147 if frame==5 else 115
    yy=149 if frame<5 else 73 if frame==5 else 163
    a.line([(127,119+bob),(xx,yy)],INK,9)
    a.line([(127,119+bob),(xx,yy)],"#998356",5)
    a.poly([(xx-17,yy-9),(xx,yy-18),(xx+17,yy-9),(xx+17,yy+9),
            (xx,yy+18),(xx-17,yy+8)],"stone",.3,3)
    a.rune(xx,yy,1,"#b2be93")
    for x,y in [(37,76),(116,82),(62,143)]:
        a.sprig(x,y+bob,.8)
    if direction==1:
        a.im=a.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return a.im


def boss(frame,direction):
    a=Art((256,288),6100)
    step=[0,-7,0,7,0,0,-5,3][frame]
    bob=[0,0,-3,0,0,-4,-6,1][frame]
    for x,s in [(96,step),(159,-step)]:
        root(a,[(x,224+bob),(x-3,246+s),(x-15,267+s//2),
                (x-27,274)],15)
        root(a,[(x,240+s),(x+8,264+s//2),(x+22,275)],11)
    a.poly([(79,112+bob),(111,95+bob),(147,95+bob),(181,116+bob),
            (175,166+bob),(185,229+bob),(169,250+bob),(145,237+bob),
            (129,254+bob),(110,237+bob),(84,247+bob),(69,230+bob),
            (82,172+bob)],"bark",.32,3)
    for i in range(9):
        x=82+i*11
        a.line([(x,137+bob),(x-6,176+bob),(x+3,207+bob),
                (x-5+step//2,235+bob)],"#102b31",3)
        a.line([(x+3,145+bob),(x,171+bob),(x+5,190+bob)],
               "#72917a",2)
    a.poly([(92,126+bob),(126,113+bob),(161,128+bob),(157,168+bob),
            (127,190+bob),(96,170+bob)],"stone",.28,3)
    a.poly([(126,127+bob),(142,147+bob),(128,172+bob),(113,150+bob)],
           "brass",.1)
    a.poly([(127,136+bob),(134,149+bob),(127,161+bob),(120,149+bob)],
           "magic",.1,1)
    a.line([(123,142+bob),(127,138+bob),(130,147+bob)],"#e5eabd",2)
    for x in [66,180]:
        a.poly([(x-17,123+bob),(x-21,103+bob),(x-9,82+bob),
                (x+8,92+bob),(x+18,86+bob),(x+24,112+bob),
                (x+13,132+bob)],"bark",.3,3)
        for j in range(5):
            a.poly([(x-14+j*7,106+bob),(x-22+j*7,82-j%2*8+bob),
                    (x-7+j*7,97+bob)],"leaf",.15)
    root(a,[(65,124+bob),(54,158+bob),(43,181+bob),(48,212+bob)],18)
    root(a,[(188,122+bob),(201,151+bob),(213,177+bob),(208,207+bob)],19)
    for x in [45,208]:
        for j in range(3):
            root(a,[(x-8+j*7,203+bob),(x-13+j*8,220+bob),
                    (x-10+j*9,231+bob)],4)
    # Crown of branching antlers, with asymmetric broken tips.
    for side in [-1,1]:
        x=128+side*20
        pts=[(x,96+bob),(x+side*17,68+bob),(x+side*25,41+bob),
             (x+side*48,25+bob),(x+side*53,8+bob)]
        a.line(pts,INK,10)
        a.line(pts,"#70836b",6)
        a.line([(x-1,91+bob),(x+side*16-1,68+bob),
                (x+side*24-1,41+bob)],"#bbbc8f",2)
        for branch in [
            [(x+side*18,65+bob),(x+side*43,59+bob),(x+side*61,41+bob)],
            [(x+side*24,43+bob),(x+side*19,20+bob),(x+side*27,8+bob)],
            [(x+side*46,27+bob),(x+side*71,25+bob),(x+side*78,15+bob)],
        ]:
            a.line(branch,INK,6)
            a.line(branch,"#b2ae80",3)
    a.poly([(102,107+bob),(95,83+bob),(103,61+bob),(127,53+bob),
            (150,63+bob),(158,85+bob),(151,111+bob),(137,129+bob),
            (118,130+bob)],"wood",.26,3)
    if direction!=3:
        a.poly([(101,80+bob),(121,88+bob),(116,97+bob),(103,93+bob)],
               INK,0,0)
        a.poly([(132,88+bob),(152,79+bob),(150,94+bob),(137,97+bob)],
               INK,0,0)
        a.line([(105,87+bob),(117,92+bob)],"#c1dd9c",3)
        a.line([(136,92+bob),(148,86+bob)],"#c1dd9c",3)
        a.poly([(124,91+bob),(129,91+bob),(132,114+bob),(127,122+bob),
                (121,114+bob)],"brass",.1,1)
        a.line([(111,110+bob),(117,119+bob),(121,117+bob)],"#586a52",2)
        a.line([(136,116+bob),(140,119+bob),(146,108+bob)],"#586a52",2)
    else:
        a.line([(111,68+bob),(127,83+bob),(143,67+bob)],"#bab989",2)
        a.line([(127,83+bob),(126,116+bob)],"#314a3e",3)
    for x,y in [(72,126),(177,126),(90,223),(158,226)]:
        for j in range(4):
            a.sprig(x+j*3,y+j%2*4+bob,.9)
    if direction==1:
        a.im=a.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return a.im


def actor_sheet(painter,size):
    sheet=Image.new("RGBA",(size[0]*8,size[1]*4))
    for direction in range(4):
        for frame in range(8):
            im=painter(frame,direction)
            sheet.alpha_composite(im,(frame*size[0],direction*size[1]))
    return sheet


def glyph(index):
    a=Art((64,64),7700+index)
    a.poly([(15,6),(48,6),(58,17),(58,47),(47,58),(16,58),(6,47),(6,17)],
           "stone",.1,2)
    a.line([(16,9),(47,9),(54,17)],"#81957e",1)
    a.line([(10,19),(10,45),(17,52)],"#456760",1)
    color="#cfbd85"
    if index==0:  # A shield stands for neutral/physical.
        a.poly([(20,18),(32,14),(45,19),(43,36),(32,48),(21,37)],
               "brass",.12)
        a.line([(32,20),(32,40)],"#fff0c6",3)
        a.line([(26,28),(38,28)],"#fff0c6",2)
    elif index==1:  # Flame, not a generic magic sparkle.
        a.poly([(20,43),(16,33),(22,21),(28,27),(34,13),(43,27),
                (47,36),(42,47),(30,50)],"brass",.1)
        a.poly([(27,44),(25,36),(33,26),(34,35),(40,40),(35,46)],
               "#f5dfab",0,0)
    elif index==2:
        for angle in range(0,360,60):
            rad=math.radians(angle)
            x,y=32+math.cos(rad)*20,32+math.sin(rad)*20
            a.line([(32,32),(x,y)],"#c1ddd0",3)
            for offset in [-.65,.65]:
                xx,yy=32+math.cos(rad)*12,32+math.sin(rad)*12
                a.line([(xx,yy),(xx-math.cos(rad+offset)*7,
                                yy-math.sin(rad+offset)*7)],"#83b8aa",2)
    elif index==3:
        a.poly([(32,13),(44,30),(46,39),(39,48),(26,48),(18,40),(20,30)],
               "water",.15)
        a.line([(26,31),(23,39),(27,43)],"#d3e4c4",3)
        a.line([(28,51),(42,51)],"#8bbca7",1)
    elif index==4:
        a.poly([(13,43),(23,26),(31,33),(40,17),(52,43)],"stone",.1)
        a.line([(32,32),(40,22),(45,35)],"#c4c69b",3)
        a.line([(15,48),(49,48)],"#c0b180",2)
    elif index==5:
        a.poly([(18,43),(19,29),(28,20),(47,16),(46,34),(37,45),(26,47)],
               "leaf",.1)
        a.line([(17,49),(39,27)],"#d3d8a5",3)
        a.line([(28,38),(28,28)],"#a8c58f",2)
        a.line([(33,33),(42,34)],"#a8c58f",2)
    elif index==6:
        for yy,xx in [(22,39),(33,47),(44,34)]:
            a.line([(15,yy),(xx,yy),(xx+4,yy-4),(xx+2,yy-8),
                    (xx-4,yy-7)],"#b4d1b2",3)
    elif index==7:
        a.poly([(34,12),(19,34),(30,34),(25,51),(47,27),(35,27),(41,12)],
               "brass",.1)
        a.line([(33,19),(25,30),(35,30),(30,42)],"#fff1c2",2)
    elif index==8:  # Split orbital loop makes quantum distinct from imaginary.
        for off in [-1,1]:
            pts=[]
            for j in range(30):
                t=j*math.tau/29
                x,y=math.cos(t)*21,math.sin(t)*8
                pts.append((32+x*.7-y*off*.7,32+x*off*.7+y*.7))
            a.line(pts,"#a7c7ab" if off==1 else "#718f89",2)
        a.rect((29,29,35,35),"#f0d9a1")
    else:  # Impossible stair, a deliberately spatial imaginary glyph.
        a.poly([(20,43),(20,20),(33,13),(45,20),(45,43),(33,50)],
               "brass",.08)
        a.poly([(26,39),(26,24),(33,20),(39,24),(39,39),(33,43)],
               "#172d35",0,1)
        a.line([(21,28),(44,40),(33,46)],"#e8daa7",2)
        a.line([(26,33),(38,27)],"#91b7a1",2)
    return a.im


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    tiles=Image.new("RGBA",(128*6,96*4))
    for i in range(12):
        tiles.alpha_composite(ground(i),((i%6)*128,(i//6)*96))
    for i in range(4):
        tiles.alpha_composite(water(i),(i*128,192))
    tiles.alpha_composite(bridge(),(4*128,192))
    for i in range(3):
        tiles.alpha_composite(cliff(i),(i*128,288))
    images={"terrain":tiles,"props":props(),
            "hero":actor_sheet(hero,(128,160)),
            "crawler":actor_sheet(crawler,(128,160)),
            "archer":actor_sheet(archer,(128,160)),
            "brute":actor_sheet(brute,(160,192)),
            "boss":actor_sheet(boss,(256,288))}
    icons=Image.new("RGBA",(640,64))
    for i in range(10):
        icons.alpha_composite(glyph(i),(i*64,0))
    images["icons"]=icons
    for name,image in images.items():
        path=OUT/(name+".png")
        image.save(path,optimize=True)
        digest=hashlib.sha256(path.read_bytes()).hexdigest()[:16]
        print(f"{path.relative_to(ROOT)} {image.width}x{image.height} sha256={digest}")


if __name__=="__main__":
    main()
