import struct
import zlib

WIDTH, HEIGHT = 1365, 768


def hex_to_rgba(hex_value, alpha=255):
    hex_value = hex_value.lstrip('#')
    r = int(hex_value[0:2], 16)
    g = int(hex_value[2:4], 16)
    b = int(hex_value[4:6], 16)
    return r, g, b, alpha


def make_canvas(width, height, color):
    r, g, b, a = color
    data = bytearray([r, g, b, a] * width * height)
    return data


def set_pixel(canvas, x, y, color):
    if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
        return
    idx = (y * WIDTH + x) * 4
    r, g, b, a = color
    canvas[idx:idx + 4] = bytes((r, g, b, a))


def draw_rect(canvas, x, y, w, h, color):
    for yy in range(y, y + h):
        start = (yy * WIDTH + x) * 4
        end = (yy * WIDTH + x + w) * 4
        canvas[start:end] = bytes(color) * w


def draw_triangle(canvas, points, color):
    # Simple scanline fill for a triangle defined by three (x, y) tuples
    pts = sorted(points, key=lambda p: p[1])
    (x1, y1), (x2, y2), (x3, y3) = pts

    def edge_interpolate(y, y0, x0, y1, x1):
        if y1 == y0:
            return x0
        return x0 + (x1 - x0) * (y - y0) / (y1 - y0)

    y_min, y_max = max(0, int(y1)), min(HEIGHT - 1, int(y3))
    for y in range(y_min, y_max + 1):
        if y < y2:
            xa = edge_interpolate(y, y1, x1, y3, x3)
            xb = edge_interpolate(y, y1, x1, y2, x2)
        else:
            xa = edge_interpolate(y, y1, x1, y3, x3)
            xb = edge_interpolate(y, y2, x2, y3, x3)
        if xa > xb:
            xa, xb = xb, xa
        xa_i, xb_i = int(xa), int(xb)
        start = (y * WIDTH + xa_i) * 4
        length = max(0, xb_i - xa_i + 1)
        canvas[start:start + length * 4] = bytes(color) * length

FONT = {
    "A": ["010","101","111","101","101"],
    "B": ["110","101","110","101","110"],
    "C": ["011","100","100","100","011"],
    "D": ["110","101","101","101","110"],
    "E": ["111","100","110","100","111"],
    "F": ["111","100","110","100","100"],
    "G": ["011","100","101","101","011"],
    "H": ["101","101","111","101","101"],
    "I": ["111","010","010","010","111"],
    "J": ["001","001","001","101","010"],
    "K": ["101","101","110","101","101"],
    "L": ["100","100","100","100","111"],
    "M": ["101","111","111","101","101"],
    "N": ["101","111","111","111","101"],
    "O": ["010","101","101","101","010"],
    "P": ["110","101","110","100","100"],
    "Q": ["010","101","101","111","011"],
    "R": ["110","101","110","101","101"],
    "S": ["011","100","010","001","110"],
    "T": ["111","010","010","010","010"],
    "U": ["101","101","101","101","111"],
    "V": ["101","101","101","101","010"],
    "W": ["101","101","111","111","101"],
    "X": ["101","101","010","101","101"],
    "Y": ["101","101","010","010","010"],
    "Z": ["111","001","010","100","111"],
    "0": ["111","101","101","101","111"],
    "1": ["010","110","010","010","111"],
    "2": ["111","001","111","100","111"],
    "3": ["111","001","111","001","111"],
    "4": ["101","101","111","001","001"],
    "5": ["111","100","111","001","111"],
    "6": ["111","100","111","101","111"],
    "7": ["111","001","010","100","100"],
    "8": ["111","101","111","101","111"],
    "9": ["111","101","111","001","111"],
    " ": ["000","000","000","000","000"],
    "-": ["000","000","111","000","000"],
    ":": ["000","010","000","010","000"],
}


def draw_char(canvas, x, y, ch, color, scale=2):
    pattern = FONT.get(ch.upper())
    if not pattern:
        return 0
    for row, line in enumerate(pattern):
        for col, bit in enumerate(line):
            if bit == "1":
                for dy in range(scale):
                    for dx in range(scale):
                        set_pixel(canvas, x + col * scale + dx, y + row * scale + dy, color)
    return (len(pattern[0]) * scale) + scale  # width including spacing


def draw_text(canvas, x, y, text, color, scale=2):
    cursor_x = x
    for ch in text:
        advance = draw_char(canvas, cursor_x, y, ch, color, scale)
        cursor_x += advance


def write_png(path, width, height, pixels):
    raw_rows = []
    for y in range(height):
        start = y * width * 4
        end = (y + 1) * width * 4
        raw_rows.append(b"\x00" + pixels[start:end])
    raw_data = b"".join(raw_rows)
    compressor = zlib.compressobj()
    compressed = compressor.compress(raw_data) + compressor.flush()

    def chunk(chunk_type, data):
        return (struct.pack('!I', len(data)) + chunk_type + data +
                struct.pack('!I', zlib.crc32(chunk_type + data) & 0xffffffff))

    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('!IIBBBBB', width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b'IDAT', compressed))
        f.write(chunk(b'IEND', b''))


def main():
    canvas = make_canvas(WIDTH, HEIGHT, hex_to_rgba('#0b1020'))

    # Header
    draw_rect(canvas, 0, 0, WIDTH, 80, hex_to_rgba('#0f172a'))
    draw_text(canvas, 28, 26, 'GOPRO LIVE STREAM', hex_to_rgba('#e5e7eb'), scale=3)
    draw_rect(canvas, WIDTH - 190, 24, 150, 32, hex_to_rgba('#1f2937'))
    draw_text(canvas, WIDTH - 180, 30, 'PREVIEW MODE', hex_to_rgba('#c084fc'), scale=2)

    # Main video area
    draw_rect(canvas, 40, 110, 900, 500, hex_to_rgba('#111827'))
    draw_rect(canvas, 60, 130, 860, 460, hex_to_rgba('#111827'))
    draw_rect(canvas, 60, 130, 860, 460, hex_to_rgba('#1f2937', 180))
    draw_rect(canvas, 120, 190, 740, 340, hex_to_rgba('#0f172a', 200))

    # Play icon
    draw_triangle(
        canvas,
        [(430, 300), (430, 420), (540, 360)],
        hex_to_rgba('#22d3ee')
    )

    draw_text(canvas, 70, 520, 'LIVE PREVIEW', hex_to_rgba('#67e8f9'), scale=3)

    # Metrics panel
    draw_rect(canvas, 990, 110, 320, 240, hex_to_rgba('#111827'))
    draw_rect(canvas, 1010, 130, 280, 200, hex_to_rgba('#1f2937'))
    draw_text(canvas, 1030, 150, 'STREAM HEALTH', hex_to_rgba('#e5e7eb'), scale=2)
    draw_text(canvas, 1030, 190, 'STATE  READY', hex_to_rgba('#a5b4fc'), scale=2)
    draw_text(canvas, 1030, 220, 'BUFFER  1.8S', hex_to_rgba('#a5b4fc'), scale=2)
    draw_text(canvas, 1030, 250, 'BITRATE  5.2MB', hex_to_rgba('#a5b4fc'), scale=2)

    # Chat panel
    draw_rect(canvas, 990, 370, 320, 240, hex_to_rgba('#111827'))
    draw_rect(canvas, 1010, 390, 280, 200, hex_to_rgba('#1f2937'))
    draw_text(canvas, 1030, 410, 'LIVE CHAT', hex_to_rgba('#e5e7eb'), scale=2)
    draw_text(canvas, 1030, 450, 'VIEWERS CAN POST', hex_to_rgba('#c084fc'), scale=2)

    # Footer card
    draw_rect(canvas, 40, 640, WIDTH - 80, 100, hex_to_rgba('#0f172a'))
    draw_text(canvas, 60, 670, 'HOW TO GO LIVE: 1) START RTMP  2) OPEN PLAYER  3) SHARE LINK', hex_to_rgba('#e5e7eb'), scale=2)

    write_png('web/preview.png', WIDTH, HEIGHT, canvas)
    print('Preview image written to web/preview.png')


if __name__ == '__main__':
    main()
