"""Lo que comparten las maderas del almacén para pintar tablas con veta, nudos y uso.

Lo usan `texturizar_madera_del_deposito.py`, `texturizar_frente_de_madera.py` y
`texturizar_patas_de_silla.py`. Es sólo numpy: no importa `bpy`, así que se prueba y se itera
fuera de Blender.

## Por qué

Una madera pintada con un solo tile parejo se lee como un papel tapiz: todas las tablas iguales,
el mismo nudo cada metro, ningún borde gastado. La luz del local está horneada, y un mapa de
relieve o de rugosidad sobre una superficie fija casi no se ve. El detalle viaja en el color.

## Qué hay

- `ruido`: ruido de valor que se repite en los dos ejes, para tiles que se juntan sin costura.
- `tabla`: UNA tabla con la veta a lo largo del eje 0: vetas finas, anillos que ondulan, poros,
  nudos y una variación de tono propia. Cada llamada con otra semilla da otra tabla.
- `rayones`, `desenfocar`, `suave`: el uso, con las mismas firmas que `detalle_de_plastico.py`.
- `de_srgb_a_lineal` y `a_srgb`: los colores del material de Blender están en lineal; la imagen,
  en sRGB.
"""

import numpy as np


def suave(a: float, b: float, x: np.ndarray) -> np.ndarray:
    """Un escalón suave: 0 en `a`, 1 en `b`. Sirve también con `a` mayor que `b`."""
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def a_srgb(lineal) -> np.ndarray:
    lineal = np.clip(np.asarray(lineal, dtype=np.float32), 0.0, 1.0)
    return np.where(lineal <= 0.0031308, lineal * 12.92, 1.055 * lineal ** (1 / 2.4) - 0.055)


def de_srgb_a_lineal(srgb) -> np.ndarray:
    srgb = np.clip(np.asarray(srgb, dtype=np.float32), 0.0, 1.0)
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)


def ruido(
    alto: int,
    ancho: int,
    celdas_y: int,
    celdas_x: int,
    azar: np.random.Generator,
    octavas: int = 1,
) -> np.ndarray:
    """Ruido de valor en [0, 1] que se repite en los dos ejes, con interpolación coseno.

    `celdas_y` y `celdas_x` son cuántas celdas entran en cada eje. Cada octava duplica las celdas
    y le da la mitad de peso. Con más celdas en x que en y salen vetas largas en vertical.
    """
    suma = np.zeros((alto, ancho), dtype=np.float32)
    peso, total = 1.0, 0.0
    ys, xs = np.arange(alto, dtype=np.float32) / alto, np.arange(ancho, dtype=np.float32) / ancho
    for octava in range(octavas):
        cy, cx = max(int(celdas_y) * 2**octava, 1), max(int(celdas_x) * 2**octava, 1)
        grilla = azar.random((cy, cx)).astype(np.float32)
        fy, fx = ys * cy, xs * cx
        y0, x0 = np.floor(fy).astype(int), np.floor(fx).astype(int)
        ty = (1 - np.cos(np.pi * (fy - y0))) / 2
        tx = (1 - np.cos(np.pi * (fx - x0))) / 2
        y1, x1 = (y0 + 1) % cy, (x0 + 1) % cx
        a, b = grilla[np.ix_(y0, x0)], grilla[np.ix_(y0, x1)]
        c, d = grilla[np.ix_(y1, x0)], grilla[np.ix_(y1, x1)]
        arriba = a + (b - a) * tx[None, :]
        abajo = c + (d - c) * tx[None, :]
        suma += peso * (arriba + (abajo - arriba) * ty[:, None])
        total += peso
        peso *= 0.5
    return suma / total


def desenfocar(imagen: np.ndarray, radio: int) -> np.ndarray:
    """Un promedio de caja por eje, que se repite en los bordes."""
    if radio <= 0:
        return imagen
    salida = imagen.astype(np.float32)
    for eje in (0, 1):
        acumulado = sum(np.roll(salida, k, axis=eje) for k in range(-radio, radio + 1))
        salida = acumulado / (2 * radio + 1)
    return salida


def rayones(
    alto: int,
    ancho: int,
    cantidad: int,
    largo: float,
    azar: np.random.Generator,
    angulo: float | None = None,
    dispersion: float = 0.25,
    grosor: int = 1,
    peso: np.ndarray | None = None,
) -> np.ndarray:
    """Segmentos finos y casi rectos, de fuerza distinta, en [0, 1].

    Con `angulo` salen casi paralelos; sin él, en cualquier dirección. `peso` es un mapa en
    [0, 1] que deja más rayones donde vale más. Se repiten en los bordes.
    """
    lienzo = np.zeros((alto, ancho), dtype=np.float32)
    for _ in range(cantidad):
        x0, y0 = azar.uniform(0, ancho), azar.uniform(0, alto)
        if peso is not None and azar.random() > peso[int(y0) % alto, int(x0) % ancho]:
            continue
        rumbo = azar.uniform(0, np.pi) if angulo is None else angulo + azar.normal(0, dispersion)
        longitud = largo * azar.uniform(0.3, 1.6)
        pasos = int(longitud * 2) + 2
        t = np.linspace(0.0, 1.0, pasos)
        curva = azar.normal(0, 0.05) * longitud * t * (1 - t)
        xs = x0 + np.cos(rumbo) * longitud * t - np.sin(rumbo) * curva
        ys = y0 + np.sin(rumbo) * longitud * t + np.cos(rumbo) * curva
        fuerza = azar.uniform(0.35, 1.0) * np.sin(np.pi * t) ** 0.5
        for dy in range(grosor):
            for dx in range(grosor):
                yi = (ys.astype(int) + dy) % alto
                xi = (xs.astype(int) + dx) % ancho
                np.maximum.at(lienzo, (yi, xi), fuerza)
    return lienzo


def tabla(
    largo: int,
    ancho: int,
    azar: np.random.Generator,
    claro: np.ndarray,
    oscuro: np.ndarray,
    nudos: int = 1,
    contraste: float = 1.0,
    anillos: float | None = None,
) -> np.ndarray:
    """Una tabla de `largo` por `ancho` píxeles, con la veta a lo largo del eje 0.

    Va de `claro` a `oscuro` (colores RGB en sRGB) según la veta. Los nudos desvían los anillos
    a su alrededor, como en la madera de verdad, y no se repiten de una tabla a otra. Se repite
    en el eje 0, así que se puede usar de tile vertical. Con `anillos` entero, también en el eje 1:
    sirve para envolver un cilindro.
    """
    y = np.arange(largo, dtype=np.float32)[:, None]
    x = np.arange(ancho, dtype=np.float32)[None, :]

    tono = ruido(largo, ancho, max(largo // 420, 2), 2, azar, 2)
    finas = ruido(largo, ancho, max(largo // 150, 4), max(ancho // 2, 3), azar, 2)
    medias = ruido(largo, ancho, max(largo // 500, 2), max(ancho // 9, 2), azar, 2)
    onda = ruido(largo, ancho, max(largo // 230, 2), max(ancho // 26, 2), azar, 2)

    cuantos = azar.uniform(2.6, 4.2) if anillos is None else anillos
    fase = x / ancho * cuantos + onda * azar.uniform(1.6, 2.6)
    nudos_en = []
    for _ in range(nudos):
        cy = azar.uniform(0.1, 0.9) * largo
        cx = azar.uniform(0.22, 0.78) * ancho
        radio = azar.uniform(0.11, 0.2) * ancho
        dy = (y - cy + largo / 2) % largo - largo / 2
        d = np.sqrt(((x - cx) / radio) ** 2 + (dy / (radio * 1.8)) ** 2)
        fase = fase + azar.choice([-1.0, 1.0]) * 1.1 * np.exp(-((d * 0.75) ** 2))
        nudos_en.append(d)

    anillo = np.abs(np.sin(np.pi * fase))
    banda = anillo**2
    linea = suave(0.9, 1.0, anillo)

    mezcla = (
        0.5
        + (finas - 0.5) * 0.55 * contraste
        + (medias - 0.5) * 0.7 * contraste
        + (tono - 0.5) * 0.9
        + (banda - 0.4) * 0.35 * contraste
        + linea * 0.18 * contraste
    )
    mezcla = np.clip(mezcla, 0.0, 1.0)[..., None]
    color = claro[None, None, :] * (1 - mezcla) + oscuro[None, None, :] * mezcla

    poros = ruido(largo, ancho, max(largo // 5, 8), ancho, azar, 1) > 0.86
    color = color * np.where(poros, 0.82, 1.0)[..., None]

    for d in nudos_en:
        nucleo = suave(1.0, 0.5, d)
        halo = suave(2.4, 0.9, d)
        vueltas = 0.5 + 0.5 * np.sin(d * 15.0)
        color = color * (1 - 0.6 * nucleo * (0.55 + 0.45 * vueltas))[..., None]
        color = color * (1 - 0.2 * halo)[..., None]
    return np.clip(color, 0.0, 1.0).astype(np.float32)
