"""Remove fundo escuro/claro dos cantos do logonova.png (transparência)."""
from PIL import Image

def main():
    path = "logonova.png"
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()

    # Cores de referência nos cantos (fundo da "caixa")
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    refs = [px[x, y][:3] for x, y in corners]

    def lum(rgb):
        return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]

    ref_lums = [lum(r) for r in refs]
    # Se cantos são escuros, apagamos pixels escuros similares aos cantos
    dark_corners = sum(1 for L in ref_lums if L < 90) >= 3
    light_corners = sum(1 for L in ref_lums if L > 200) >= 3

    if dark_corners:
        tol = 55  # distância euclidiana RGB para considerar "fundo"
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                dmin = min(
                    ((r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2) ** 0.5
                    for cr, cg, cb in refs
                )
                if dmin < tol and lum((r, g, b)) < 100:
                    px[x, y] = (r, g, b, 0)
    elif light_corners:
        tol = 40
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if r > 245 and g > 245 and b > 245:
                    px[x, y] = (r, g, b, 0)
                else:
                    dmin = min(
                        ((r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2) ** 0.5
                        for cr, cg, cb in refs
                    )
                    if dmin < tol:
                        px[x, y] = (r, g, b, 0)
    else:
        print("Cantos mistos; tentando só luminância baixa nas bordas")
        border = 8
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                on_edge = x < border or y < border or x >= w - border or y >= h - border
                if on_edge and lum((r, g, b)) < 80:
                    px[x, y] = (r, g, b, 0)

    im.save(path, "PNG")
    print("OK", path, im.size)


if __name__ == "__main__":
    main()
