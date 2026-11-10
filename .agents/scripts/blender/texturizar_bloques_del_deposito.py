"""Texturizar los bloques del depósito: más variación, bordes gastados y juntas hundidas.

Por qué: la textura de ambientCG (`Bricks066`) repite cada 1,8 m el mismo tile de 3×9 bloques, y
en un depósito de 12 m de pared el ojo ve el patrón. Los bloques tampoco se distinguen entre sí:
mismo tono, juntas finas, bordes sin desgaste. La luz del local está horneada, así que un mapa de
relieve casi no se ve. El detalle tiene que viajar en el color.

Qué cambia: genera tres PNG en `assets/source/textures/warehouse/final/`:
`deposito_bloques_color.png`, `deposito_bloques_normal.png` y `deposito_bloques_rough.png`.
Cada uno cubre 2,4 m de ancho (4 bloques) y 3,6 m de alto (12 hiladas): la altura entera del
revestimiento, sin repetición vertical. Por eso la humedad que sube del piso vive en el tile.
Cada bloque toma su cara de una de las 27 del tile original (la misma piedra, con sus poros y
sus chorreaduras), con otro tono, bordes redondeados con luz arriba y sombra abajo, desportillados
en esquinas y cantos, y juntas de mortero oscuras que se leen hundidas. La traba es la del tile
original: cada hilada corre un tercio de bloque.

Lo que cuesta: nada de geometría ni de dibujos. El color sigue a 1024 px, igual que antes. La
normal y la rugosidad viajan a 512 (`lib/blender.py`).

Es determinista: la misma entrada da los mismos bytes. Se corre sin `--aplicar` para ver los PNG;
con `--aplicar` escribe en `assets/source/`. Lo que reapunta el material a estos PNG es
`ladrillos_del_deposito.py`, que va después.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_bloques_del_deposito.py -- [--aplicar]
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parents[3]
ORIGEN = RAIZ / "assets/source/textures/warehouse/ambientcg/bricks-066/Bricks066_1K-JPG_Color.jpg"
DESTINO = RAIZ / "assets/source/textures/warehouse/final"
NOMBRES = {
    "color": "deposito_bloques_color.png",
    "normal": "deposito_bloques_normal.png",
    "rough": "deposito_bloques_rough.png",
}

N = 1024
COLUMNAS, HILADAS = 4, 12
ANCHO, ALTO = N / COLUMNAS, N / HILADAS
BLOQUE_METROS = (0.6, 0.3)
PX_POR_METRO = ANCHO / BLOQUE_METROS[0]
JUNTA = 4.4
REDONDEO = 3.4
ORIGEN_COLUMNAS, ORIGEN_HILADAS = 3, 9
SEMILLA = 20261110


def ruido(rng, celdas_x, celdas_y):
    """Ruido de valor periódico en [0, 1], con interpolación coseno."""
    grilla = rng.random((celdas_y, celdas_x))
    ys = np.arange(N) * celdas_y / N
    xs = np.arange(N) * celdas_x / N
    y0, x0 = np.floor(ys).astype(int), np.floor(xs).astype(int)
    fy = (1 - np.cos(np.pi * (ys - y0))) / 2
    fx = (1 - np.cos(np.pi * (xs - x0))) / 2
    y1, x1 = (y0 + 1) % celdas_y, (x0 + 1) % celdas_x
    a, b = grilla[np.ix_(y0, x0)], grilla[np.ix_(y0, x1)]
    c, d = grilla[np.ix_(y1, x0)], grilla[np.ix_(y1, x1)]
    arriba = a + (b - a) * fx[None, :]
    abajo = c + (d - c) * fx[None, :]
    return arriba + (abajo - arriba) * fy[:, None]


def fractal(rng, base_x, base_y, octavas=4):
    total, peso, suma = np.zeros((N, N)), 1.0, 0.0
    for o in range(octavas):
        total += peso * ruido(rng, base_x * 2**o, base_y * 2**o)
        suma += peso
        peso *= 0.5
    return total / suma


def desenfocar(a, sigma):
    """Gauss periódico por FFT."""
    fx = np.fft.rfftfreq(a.shape[1])
    fy = np.fft.fftfreq(a.shape[0])
    nucleo = np.exp(-2 * (np.pi * sigma) ** 2 * (fy[:, None] ** 2 + fx[None, :] ** 2))
    return np.fft.irfft2(np.fft.rfft2(a) * nucleo, s=a.shape)


def suave(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def caras_del_origen(origen):
    """Las 27 caras de bloque del tile original, sin su junta ni su bisel.

    `origen` es (N, N, 3) en [0, 1], con la fila 0 abajo. La traba del original corre un tercio
    de bloque por hilada: se mide dónde cae la junta vertical de cada una.
    """
    ancho, alto = N / ORIGEN_COLUMNAS, N / ORIGEN_HILADAS
    luz = origen.mean(axis=2)
    margen = 10
    caras = []
    for fila in range(ORIGEN_HILADAS):
        y0 = int(round(fila * alto))
        y1 = int(round((fila + 1) * alto))
        franja = luz[y0 + margen : y1 - margen].mean(axis=0)
        franja = np.convolve(np.r_[franja[-4:], franja, franja[:4]], np.ones(5) / 5, "valid")
        junta = int(np.argmin(franja[2 : 2 + N] + 0 * franja[2 : 2 + N]))
        desplazada = np.roll(origen[y0:y1], -junta, axis=1)
        for columna in range(ORIGEN_COLUMNAS):
            x0 = int(round(columna * ancho)) + margen
            x1 = int(round((columna + 1) * ancho)) - margen
            caras.append(desplazada[margen : y1 - y0 - margen, x0:x1])
    return caras


def muestrear(cara, u, v):
    """Interpolación bilineal de una cara con coordenadas normalizadas u, v en [0, 1]."""
    alto, ancho = cara.shape[:2]
    x = np.clip(u, 0, 1) * (ancho - 1)
    y = np.clip(v, 0, 1) * (alto - 1)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    x1, y1 = np.minimum(x0 + 1, ancho - 1), np.minimum(y0 + 1, alto - 1)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    arriba = cara[y0, x0] * (1 - fx) + cara[y0, x1] * fx
    abajo = cara[y1, x0] * (1 - fx) + cara[y1, x1] * fx
    return arriba * (1 - fy) + abajo * fy


def generar(origen):
    """(color, normal, rugosidad) a partir del color original. Todo en [0, 1], fila 0 abajo."""
    rng = np.random.default_rng(SEMILLA)
    caras = caras_del_origen(origen)
    media_original = origen.mean()

    y, x = np.mgrid[0:N, 0:N] + 0.5
    fila = np.floor(y / ALTO).astype(int)
    xs = (x - (fila % 3) * ANCHO / 3) % N
    columna = np.floor(xs / ANCHO).astype(int)
    lx, ly = xs - columna * ANCHO, y - fila * ALTO
    d_izq, d_der, d_aba, d_arr = lx, ANCHO - lx, ly, ALTO - ly
    borde = np.minimum(np.minimum(d_izq, d_der), np.minimum(d_aba, d_arr))
    cara_d = borde - JUNTA / 2
    junta = suave(JUNTA / 2 - borde, -0.7, 0.7)

    # Cada bloque toma una cara, un tono y un desgaste propios.
    orden = rng.permutation(len(caras) * 2) % len(caras)
    cara_color = np.zeros((N, N, 3))
    tono = np.ones((N, N))
    matiz = np.zeros((N, N))
    desgaste = np.zeros((N, N))
    u_total = (lx - JUNTA / 2) / (ANCHO - JUNTA)
    v_total = (ly - JUNTA / 2) / (ALTO - JUNTA)
    for f in range(HILADAS):
        for c in range(COLUMNAS):
            m = (fila == f) & (columna == c)
            k = orden[f * COLUMNAS + c]
            u = u_total[m]
            if rng.random() < 0.5:
                u = 1 - u
            cara_color[m] = muestrear(caras[k], u, v_total[m])
            t = np.exp(rng.normal(0, 0.085))
            if rng.random() < 0.12:
                t *= 1 + rng.choice([-1, 1]) * rng.uniform(0.12, 0.2)
            tono[m] = t
            matiz[m] = rng.normal(0, 0.011)
            desgaste[m] = rng.random() ** 1.6

    cara_color *= tono[..., None]
    cara_color[..., 0] *= 1 + matiz
    cara_color[..., 2] *= 1 - matiz
    # Una variación suave dentro de cada bloque, para que ninguna cara sea plana.
    nube = fractal(rng, 24, 36, 3)
    cara_color *= (1 + 0.20 * (nube - 0.5))[..., None]

    # Bordes: redondeados, con luz arriba y a la izquierda y sombra abajo y a la derecha.
    irregular = 0.65 + 0.7 * fractal(rng, 96, 96, 3)
    def banda(d):
        return (1 - np.clip(d / REDONDEO, 0, 1)) ** 2 * irregular
    sombreado = (
        1
        + 0.20 * banda(d_arr - JUNTA / 2)
        + 0.09 * banda(d_izq - JUNTA / 2)
        - 0.17 * banda(d_aba - JUNTA / 2)
        - 0.09 * banda(d_der - JUNTA / 2)
    )
    oclusion = 1 - 0.16 * (1 - np.clip(cara_d / 7, 0, 1)) ** 1.6
    cara_color *= (sombreado * oclusion)[..., None]

    # Desportillados: en los cantos y, más, en las esquinas. Dejan ver el concreto claro.
    ancho_chip = suave(fractal(rng, 150, 150, 3), 0.50, 0.78) * 7.5 * desgaste
    en_x = np.minimum(d_izq, d_der) - JUNTA / 2
    en_y = np.minimum(d_aba, d_arr) - JUNTA / 2
    rincon = np.clip(1 - np.hypot(en_x, en_y) / 16, 0, 1)
    ancho_chip = ancho_chip + suave(fractal(rng, 110, 110, 2), 0.45, 0.8) * 9.0 * rincon * desgaste
    chip = suave(ancho_chip - cara_d, -0.5, 0.8) * (cara_d >= -0.5)
    arista = suave(1 - np.abs(cara_d - ancho_chip) / 1.2, 0.0, 1.0) * (ancho_chip > 1.0)
    grano = rng.random((N, N))
    claro = 1.0 + 0.26 * chip + 0.1 * (grano - 0.5) * chip
    cara_color = cara_color * claro[..., None] * (1 - 0.30 * arista)[..., None]

    # Poros y vetas claras.
    poros = desenfocar((rng.random((N, N)) > 0.9978).astype(float), 0.8)
    poros = np.clip(poros / (poros.max() + 1e-9) * 1.6, 0, 1)
    cara_color *= (1 - 0.24 * poros * (cara_d > 1))[..., None]
    veta = np.abs(fractal(rng, 5, 70, 3) - 0.5)
    cara_color *= (1 + 0.07 * suave(0.018 - veta, 0, 0.018))[..., None]

    # Mortar: oscuro, con grano, más oscuro al centro de la junta.
    centro = np.clip(borde / (JUNTA / 2), 0, 1)
    grano_junta = desenfocar(rng.random((N, N)), 0.6)
    grano_junta = 0.85 + 0.3 * (grano_junta - grano_junta.min()) / np.ptp(grano_junta)
    mortero = np.array([0.205, 0.21, 0.185])[None, None, :] * (grano_junta * (0.68 + 0.32 * centro))[
        ..., None
    ]
    color = cara_color * (1 - junta[..., None]) + mortero * junta[..., None]

    # La humedad sube del piso con un frente irregular, y el pie está siempre sucio.
    frente = 0.20 + 0.16 * fractal(rng, 5, 1, 2) + 0.05 * fractal(rng, 40, 1, 2)
    altura = y / N
    humedad = suave(frente - altura, 0.0, 0.12) ** 0.8 * (0.55 + 0.45 * fractal(rng, 60, 30, 3))
    sal = suave(1 - np.abs(altura - frente) / 0.012, 0, 1) * 0.5 * (humedad > 0.0)
    verde = np.array([0.95, 1.0, 0.93])[None, None, :]
    color = color * (1 - 0.40 * humedad[..., None]) * (1 - humedad[..., None] * (1 - verde))
    color = color * (1 + 0.05 * sal[..., None])
    suciedad = suave(0.04 - altura, 0, 0.04)
    color = color * (1 - 0.22 * suciedad[..., None])

    # Chorreaduras que bajan de algunas juntas.
    for _ in range(18):
        cx = rng.uniform(0, N)
        cy = rng.uniform(0.3 * N, N)
        largo = rng.uniform(120, 420)
        ancho_ch = rng.uniform(3, 9)
        dx = np.minimum(np.abs(x - cx), N - np.abs(x - cx))
        dy = cy - y
        eje = suave(1 - dx / ancho_ch, 0, 1) * suave(dy, -2, 4) * suave(1 - dy / largo, 0, 1)
        color = color * (1 - rng.uniform(0.08, 0.17) * eje * (0.6 + 0.4 * grano))[..., None]

    # Se conserva la luz media del original, para no cambiar cómo toma la luz horneada.
    media_nueva = color.mean()
    color = np.clip(color * media_original / media_nueva, 0, 1)

    # Relieve: el mismo mapa de alturas da la normal.
    h = np.zeros((N, N))
    h -= 0.55 * (1 - np.clip(cara_d / REDONDEO, 0, 1)) ** 2
    h -= 1.7 * junta
    h -= 1.0 * chip
    h -= 0.45 * poros
    luz = color.mean(axis=2)
    h += 0.5 * (luz - desenfocar(luz, 2.0))
    fuerza = 1.1
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) / 2
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) / 2
    normal = np.dstack([-gx * fuerza, -gy * fuerza, np.ones((N, N))])
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    normal = normal * 0.5 + 0.5

    # Rugosidad: la cara seca es áspera, lo desportillado es concreto nuevo, la humedad brilla.
    rugosa = 0.74 + 0.10 * (fractal(rng, 30, 30, 3) - 0.5) + 0.05 * (tono - 1)
    rugosa = rugosa - 0.12 * chip - 0.14 * humedad
    rugosa = rugosa * (1 - junta) + 0.97 * junta
    rugosa = np.clip(rugosa, 0.2, 1.0)
    return color, normal, rugosa


def a_bytes(a):
    return np.clip(np.rint(a * 255), 0, 255).astype(np.uint8)


def leer(ruta):
    import bpy

    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    imagen.colorspace_settings.name = "Non-Color"
    ancho, alto = imagen.size
    datos = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    bpy.data.images.remove(imagen)
    return datos.reshape(alto, ancho, 4)[..., :3].astype(np.float64)


def escribir(ruta, rgb):
    import bpy

    alto, ancho = rgb.shape[:2]
    imagen = bpy.data.images.new(ruta.name, ancho, alto, alpha=False, float_buffer=False)
    imagen.colorspace_settings.name = "Non-Color"
    rgba = np.dstack([rgb, np.ones((alto, ancho))]).astype(np.float32)
    imagen.pixels.foreach_set(rgba.ravel())
    imagen.filepath_raw = str(ruta)
    imagen.file_format = "PNG"
    imagen.save()
    bpy.data.images.remove(imagen)


def huella(ruta):
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def main():
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path, default=RAIZ / "reports/bloques-del-deposito")
    opciones = parser.parse_args(argumentos)
    color, normal, rugosa = generar(leer(ORIGEN))
    carpeta = DESTINO if opciones.aplicar else opciones.destino
    carpeta.mkdir(parents=True, exist_ok=True)
    escribir(carpeta / NOMBRES["color"], color)
    escribir(carpeta / NOMBRES["normal"], normal)
    escribir(carpeta / NOMBRES["rough"], np.dstack([rugosa] * 3))
    ficha = {
        "source": "../ambientcg/bricks-066/source.json",
        "license": "CC0-1.0",
        "original": "../ambientcg/bricks-066/Bricks066_1K-JPG_Color.jpg",
        "original_sha256": huella(ORIGEN),
        "generator": ".claude/scripts/blender/texturizar_bloques_del_deposito.py",
        "operation": "27 caras del original, un tono y un desgaste por bloque, juntas hundidas, "
        "humedad al pie; normal y rugosidad del mismo mapa de alturas",
        "cobertura_metros": [COLUMNAS * BLOQUE_METROS[0], HILADAS * BLOQUE_METROS[1]],
        "size": [N, N],
        "files": {k: {"file": v, "sha256": huella(carpeta / v)} for k, v in NOMBRES.items()},
    }
    (carpeta / "deposito_bloques.source.json").write_text(
        json.dumps(ficha, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(ficha, indent=2))


if __name__ == "__main__":
    main()
