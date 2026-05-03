"""Remove faixa reflexo na base do logonova.png (já com alpha nos cantos)."""
from PIL import Image

def main():
    path = "logonova.png"
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    y_cut = int(h * 0.86)

    for y in range(y_cut, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # Reflexo alaranjado / escuro da foto (não é verde da marca)
            if r > 85 and g < r - 15 and b < r - 10:
                px[x, y] = (0, 0, 0, 0)
            elif r + g + b < 95:
                px[x, y] = (0, 0, 0, 0)

    im.save(path, "PNG")
    print("clean bottom OK")


if __name__ == "__main__":
    main()
