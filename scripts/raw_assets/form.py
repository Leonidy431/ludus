"""Alpha-channel form: masks, shape delta, silhouette loss and hitboxes.

The owner's rule for raw material is that alpha is the only truth of
form.  A pixel belongs to the object when its alpha exceeds ALPHA_FLOOR,
whatever its colour, so a black pixel weighs exactly as much as a white
one.  No function in this module ever looks at luminance.

All masks are 8-bit 'L' images holding only 0 and 255 on the common
CANVAS x CANVAS square, so every comparison is pixel-for-pixel.
"""

import math

from PIL import Image, ImageChops, ImageDraw

CANVAS = 256

# Sheets carry near-invisible pixels (alpha 1-16) as compression dust;
# they are not part of any drawn form.
ALPHA_FLOOR = 16

# A pixel that moves only inside the outer outline (a hole opened or a
# stroke shifted within the same silhouette) changes the look far less
# than a change of the outline itself, so it counts one tenth.
INTERIOR_WEIGHT = 0.1

# A pixel counts as recoloured when its RGB distance exceeds 15 % of the
# maximum possible distance; smaller shifts are invisible on a headset.
PIXEL_TOLERANCE = 0.15 * (3 * 255 ** 2) ** 0.5


def alpha_mask(img):
    """Return the binary form mask of an image from its alpha alone."""
    alpha = img.convert('RGBA').getchannel('A')
    return alpha.point(lambda v: 255 if v > ALPHA_FLOOR else 0)


def area(mask):
    """Count the opaque pixels of a binary mask."""
    return mask.histogram()[255]


def fill_holes(mask):
    """Return the mask with every enclosed hole filled.

    The background is flooded from outside the canvas; whatever the flood
    cannot reach is inside the outer outline.  A one-pixel border lets
    the flood pass around objects that touch the canvas edge.
    """
    w, h = mask.size
    pad = Image.new('L', (w + 2, h + 2), 0)
    pad.paste(mask, (1, 1))
    ImageDraw.floodfill(pad, (0, 0), 128, thresh=0)
    outside = pad.crop((1, 1, w + 1, h + 1))
    return outside.point(lambda v: 0 if v == 128 else 255)


def shape_delta(src, res, filled_src=None):
    """Return the weighted shape change between two alpha masks.

    Without interior pixels this is |A XOR B| / |A OR B|, i.e. 1 - IoU.
    XOR pixels that lie inside both filled outlines are interior moves
    and weigh INTERIOR_WEIGHT.  The filled source outline may be passed
    in, because one source is compared with many variants.
    """
    union = area(ImageChops.lighter(src, res))
    if not union:
        return 0.0
    xor = ImageChops.difference(src, res)
    filled_src = filled_src or fill_holes(src)
    inside = ImageChops.multiply(filled_src, fill_holes(res))
    interior = area(ImageChops.multiply(xor, inside))
    outer = area(xor) - interior
    return (outer + INTERIOR_WEIGHT * interior) / union


def iou_delta(src, res):
    """Plain 1 - IoU, kept in the meta so a reviewer can check the math."""
    union = area(ImageChops.lighter(src, res))
    if not union:
        return 0.0
    return area(ImageChops.difference(src, res)) / union


def silhouette_loss(src, res):
    """Share of source-opaque pixels that are transparent in the result."""
    total = area(src)
    if not total:
        return 0.0
    return area(ImageChops.subtract(src, res)) / total


def colour_change(src_img, res_img, src, res):
    """Share of shared-form pixels whose colour moved beyond tolerance.

    Colour is a separate metric from shape: it is measured only where
    both forms are present, so it answers "was this place repainted"
    and never double-counts a reshaping.
    """
    both = ImageChops.multiply(src, res).tobytes()
    diff = ImageChops.difference(src_img.convert('RGB'),
                                 res_img.convert('RGB')).tobytes()
    limit = PIXEL_TOLERANCE ** 2
    changed = total = 0
    for i, flag in enumerate(both):
        if not flag:
            continue
        total += 1
        r, g, b = diff[3 * i], diff[3 * i + 1], diff[3 * i + 2]
        if r * r + g * g + b * b > limit:
            changed += 1
    return changed / total if total else 1.0


def convex_hull(points):
    """Andrew's monotone chain; returns the hull counter-clockwise."""
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def hitbox(mask):
    """Describe the collision form derived from the alpha mask.

    The hull is built from the pixel corners of the leftmost and
    rightmost opaque pixel of every row, which is exact for a convex
    hull and costs one pass over the rows.
    """
    box = mask.getbbox()
    n = area(mask)
    if box is None:
        return {'bbox': None, 'area': 0, 'radius': 0.0, 'hull': []}
    w = mask.width
    data = mask.tobytes()
    points = []
    for y in range(box[1], box[3]):
        row = data[y * w:(y + 1) * w]
        x0 = row.find(b'\xff')
        if x0 < 0:
            continue
        x1 = row.rfind(b'\xff') + 1
        points += [(x0, y), (x0, y + 1), (x1, y), (x1, y + 1)]
    return {
        'bbox': list(box),
        'area': n,
        'radius': round(math.sqrt(n / math.pi), 2),
        'hull': [list(p) for p in convex_hull(points)],
    }


def hitbox_key(box):
    """Identity of a hitbox for the pairwise-distinct rule."""
    return (tuple(box['bbox'] or ()), box['area'])
