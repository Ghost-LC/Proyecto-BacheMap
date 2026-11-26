"""Genera el icono original de BacheMap y sus tamaños Android.

Requiere Pillow. Se dibuja a alta resolución y se reduce con antialiasing.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[1]
S = 1024
imagen = Image.new("RGB", (S, S), "#E8F1F7")
d = ImageDraw.Draw(imagen)

# Escudo de ubicación: silueta azul de alto contraste sobre el fondo claro.
d.ellipse((170, 88, 854, 772), fill="#102F4B")
d.polygon([(195, 532), (829, 532), (512, 944)], fill="#102F4B")
d.ellipse((222, 140, 802, 720), fill="#174B78")
d.polygon([(235, 523), (789, 523), (512, 885)], fill="#174B78")

# Interior del mapa, avenida y marcas viales.
d.ellipse((274, 192, 750, 668), fill="#F4F8FA")
d.polygon([(402, 220), (622, 220), (696, 632), (328, 632)], fill="#D7E5EC")
d.line([(512, 232), (512, 304)], fill="#E5A700", width=24)
d.line([(512, 339), (512, 380)], fill="#E5A700", width=24)

# Bache visible con grietas: comunica el propósito sin depender de texto.
d.ellipse((352, 405, 672, 561), fill="#102F4B")
d.ellipse((385, 422, 639, 505), fill="#314E60")
for puntos in [
    [(385, 463), (345, 443), (324, 412)],
    [(627, 458), (676, 434), (694, 410)],
    [(441, 546), (420, 579), (387, 591)],
    [(574, 545), (598, 579), (633, 593)],
]:
    d.line(puntos, fill="#102F4B", width=13, joint="curve")
d.ellipse((618, 158, 800, 340), fill="#FFC247", outline="#F4F8FA", width=16)
d.line([(708, 205), (708, 265)], fill="#102F4B", width=22)
d.ellipse((697, 281, 719, 303), fill="#102F4B")

asset = RAIZ / "assets" / "branding" / "bachemap_icon.png"
asset.parent.mkdir(parents=True, exist_ok=True)
imagen.save(asset, optimize=True)
for densidad, tamano in {
    "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
}.items():
    destino = RAIZ / "android" / "app" / "src" / "main" / "res" / f"mipmap-{densidad}" / "ic_launcher.png"
    destino.parent.mkdir(parents=True, exist_ok=True)
    imagen.resize((tamano, tamano), Image.Resampling.LANCZOS).save(destino, optimize=True)
ios = RAIZ / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
for entrada in json.loads((ios / "Contents.json").read_text(encoding="utf-8"))["images"]:
    if "filename" not in entrada:
        continue
    tamano = round(float(entrada["size"].split("x")[0]) * int(entrada["scale"][:-1]))
    imagen.resize((tamano, tamano), Image.Resampling.LANCZOS).save(
        ios / entrada["filename"], optimize=True
    )
print(f"Icono creado: {asset}")
