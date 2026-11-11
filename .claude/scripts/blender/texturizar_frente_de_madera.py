"""Texturizar la madera clara del mostrador y del friso: tablas verticales con juntas, veta y uso.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_frente_de_madera.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/madera/` y cambia sólo la sesión de Blender. Con
`--aplicar` escribe `assets/source/textures/store/madera_lambrin.png` y guarda el `.blend`.
Después va `exportar_modelo.py`. Si el friso va a llevar marcos, antes va
`molduras_del_friso.py`.

## Por qué

El frente del mostrador y el friso de las heladeras eran una sola madera lisa de 512 px que se
repetía cada metro: sin tablas, sin juntas, sin un solo roce. Un frente de madera de verdad es
un lambrín: tablas verticales, cada una con su tono y su veta, unidas por una junta que se ve
como una línea oscura, y gastado donde se lo toca y donde se lo patea.

## Qué cambia

- **Una imagen de 1024×1024** que cubre 1,8 m de ancho y 2,49 m de alto, de 10 cm sobre el piso
  hasta el tope del friso. Lleva doce tablas de 15 cm, cada una con su tono, su veta, sus poros
  y a veces un nudo. Entre una y otra corre una junta en V: oscura, con un filo claro.
- **Largos distintos.** Cinco tablas se cortan a media altura, cada una a otra altura. El corte
  es una línea oscura y las dos mitades son tablas distintas. Ninguno cae donde llega el mostrador.
- **Uso**, pintado en el color: mugre y roces de patada al pie, la franja pulida por las manos a
  la altura del mostrador, manchas anchas, rayones a lo largo de la veta y algunos cruzados.
  Una cenefa oscura marca el zócalo del friso (`v` de 0 a 0,084), y la sombra del cornisamento
  cierra el tope.
- **Las UV** de todas las caras de madera de `mueble_continuo`, `compuerta_mostrador` y
  `EscritorioComputadora-col` se rehacen en metros del mundo: la u es la posición horizontal
  sobre 1,8 y la v es la altura sobre el piso sobre 2,49. Las tiras largas y finas, como el
  canto de un marco, giran la imagen: su veta corre a lo largo de la tira y sale de una sola
  tabla.
- **El material** `MOSTRADOR | Frente de madera` apunta a la imagen nueva.

## Lo que cuesta

Ningún triángulo, ningún material ni dibujo más. La textura pasa de 512×512 a 1024×1024 (el PNG
fuente pesa 747 KB).
Es determinista y idempotente.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_madera import desenfocar, rayones, ruido, suave, tabla  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "assets/source/textures/store/madera_lambrin.png"
PRUEBA = RAIZ / "build" / "madera" / DESTINO.name
MATERIAL = "MOSTRADOR | Frente de madera"
OBJETOS = ("mueble_continuo", "compuerta_mostrador", "EscritorioComputadora-col")
DESPLAZAMIENTO_DE_U = {"mueble_continuo": 0.0, "compuerta_mostrador": 0.37, "EscritorioComputadora-col": 0.71}

N = 1024
TABLAS = 12
ANCHO_EN_METROS = 1.8
ALTO_EN_METROS = 2.49
PISO = 0.1
#: El zócalo del friso termina a 31 cm del suelo.
V_DEL_ZOCALO = (0.31 - PISO) / ALTO_EN_METROS
SEMILLA = 20261111
#: El color de siempre de esta madera, en sRGB: el promedio de la imagen de 512 px.
BASE = np.array([0.690, 0.519, 0.353], dtype=np.float32)
#: Las tablas que se cortan a media altura, y a qué fracción del alto. Sólo por arriba de la
#: mitad: abajo está el frente del mostrador, que corre sin cortes.
CORTES = {1: 0.56, 4: 0.71, 6: 0.48, 8: 0.84, 10: 0.63}
#: Una tira es de canto si es al menos tres veces más larga que alta, y de menos de 9 cm de alto.
ALTO_DE_CANTO = 0.09
VUELTA_DE_CANTO = 2.5
V_DE_CANTO = 0.46


def _colores(azar: np.random.Generator):
    factor = azar.uniform(0.9, 1.08)
    tinte = azar.uniform(-0.03, 0.03)
    base = BASE * factor * np.array([1 + tinte, 1.0, 1 - tinte * 1.6], dtype=np.float32)
    return np.clip(base * 1.1, 0, 1), np.clip(base * 0.82, 0, 1)


def pintar() -> np.ndarray:
    """La imagen entera, (N, N, 3) en sRGB 0..1, con la fila 0 abajo."""
    azar = np.random.default_rng(SEMILLA)
    bordes = np.linspace(0, N, TABLAS + 1).round().astype(int)
    imagen = np.zeros((N, N, 3), dtype=np.float32)
    filas = np.arange(N, dtype=np.float32)[:, None]
    for i in range(TABLAS):
        a, b = bordes[i], bordes[i + 1]
        ancho = b - a
        claro, oscuro = _colores(azar)
        nudos = int(azar.choice([0, 0, 1]))
        cuerpo = tabla(N, ancho, azar, claro, oscuro, nudos=nudos, contraste=0.85)
        if i in CORTES:
            corte = int(CORTES[i] * N)
            otra = tabla(N, ancho, azar, *_colores(azar), nudos=int(azar.choice([0, 1])), contraste=0.85)
            cuerpo = np.where(filas[:, :, None] >= corte, np.roll(otra, 300, axis=0), cuerpo)
            sombra = suave(4.5, 0.0, np.abs(filas - corte + 0.5))
            claridad = suave(1.5, 0.0, np.abs(filas - corte - 3.5))
            cuerpo = cuerpo * (1 - 0.7 * sombra)[..., None]
            cuerpo = cuerpo + (1 - cuerpo) * (0.12 * claridad)[..., None]
        # La junta en V: dos píxeles oscuros, otros dos de sombra y un filo claro a la derecha.
        columnas = np.arange(ancho, dtype=np.float32)[None, :]
        junta = suave(3.2, 0.5, columnas) * 0.62
        filo = suave(ancho - 3.0, ancho - 1.0, columnas) * 0.10
        cuerpo = cuerpo * (1 - junta)[..., None]
        cuerpo = cuerpo + (1 - cuerpo) * filo[..., None]
        imagen[:, a:b] = cuerpo

    alto, ancho = N, N
    filas = np.arange(alto, dtype=np.float32)[:, None] * np.ones((1, ancho), dtype=np.float32)
    columnas = np.arange(ancho, dtype=np.float32)[None, :] * np.ones((alto, 1), dtype=np.float32)

    # Manchas anchas: la mugre que se junta, y algún chorreado.
    manchas = ruido(alto, ancho, 5, 4, azar, 3)
    imagen = imagen * (1 - 0.20 * suave(0.55, 0.85, manchas))[..., None]
    humedad = suave(0.62, 0.9, ruido(alto, ancho, 3, 12, azar, 2))
    imagen = imagen * (1 - 0.12 * humedad * suave(500, 0, filas))[..., None]

    # Al pie: mugre y roce de patada.
    suciedad = suave(260, 0, filas) * (0.55 + 0.6 * ruido(alto, ancho, 2, 10, azar, 3))
    imagen = imagen * (1 - 0.24 * np.clip(suciedad, 0, 1))[..., None]
    patadas = rayones(alto, ancho, 90, 26, azar, angulo=0.0, dispersion=0.7, peso=np.clip(suave(260, 0, filas), 0, 1))
    imagen = imagen * (1 - 0.36 * patadas)[..., None]
    # La franja pulida por las manos, a la altura del mostrador.
    pulido = np.exp(-(((filas - 330) / 90) ** 2)) * suave(0.5, 0.85, ruido(alto, ancho, 4, 8, azar, 2))
    imagen = imagen + (np.array([0.96, 0.83, 0.62]) - imagen) * (0.20 * pulido)[..., None]

    # El zócalo del friso: más oscuro, con la cenefa donde termina.
    fila_zocalo = V_DEL_ZOCALO * N
    zocalo = suave(fila_zocalo + 1.5, fila_zocalo - 1.5, filas)
    imagen = imagen * (1 - 0.22 * zocalo)[..., None]
    cenefa = suave(3.5, 0.5, np.abs(filas - fila_zocalo))
    imagen = imagen * (1 - 0.62 * cenefa)[..., None]
    filo = suave(5.0, 2.0, np.abs(filas - fila_zocalo - 4.5))
    imagen = imagen + (1 - imagen) * (0.10 * filo)[..., None]
    # El tope, bajo el cornisamento.
    imagen = imagen * (1 - 0.16 * suave(N - 90, N, filas))[..., None]

    # Rayones a lo largo de la veta y unos cruzados.
    largos = rayones(alto, ancho, 120, 120, azar, angulo=np.pi / 2, dispersion=0.05)
    cruzados = rayones(alto, ancho, 50, 40, azar)
    claros = rayones(alto, ancho, 70, 70, azar, angulo=np.pi / 2, dispersion=0.12)
    imagen = imagen * (1 - 0.18 * largos)[..., None]
    imagen = imagen * (1 - 0.22 * cruzados)[..., None]
    imagen = imagen + (np.array([0.97, 0.88, 0.7]) - imagen) * (0.20 * claros)[..., None]

    polvo = desenfocar(ruido(alto, ancho, 8, 8, azar, 3), 3)
    imagen = imagen * (0.95 + 0.1 * polvo)[..., None]
    # La imagen conserva la luz media de la madera que reemplaza: el detalle no la oscurece.
    imagen = imagen * (BASE.mean() / imagen.mean())
    return np.clip(imagen, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# Lo que sigue necesita Blender.
# ---------------------------------------------------------------------------------------------


def uv_de_cara(puntos, normal, desplazamiento: float, tabla_de_canto: float):
    """Las UV de las esquinas de una cara, en metros del mundo. Ver el docstring del módulo."""
    zs = [p[2] for p in puntos]
    alto = max(zs) - min(zs)
    if abs(normal[2]) >= 0.8:
        return [(p[0] / ANCHO_EN_METROS + desplazamiento, p[1] / ALTO_EN_METROS) for p in puntos]
    hacia_x = abs(normal[0]) >= abs(normal[1])
    horizontal = [p[1] if hacia_x else p[0] for p in puntos]
    largo = max(horizontal) - min(horizontal)
    if alto <= ALTO_DE_CANTO and largo >= VUELTA_DE_CANTO * alto:
        centro = (max(zs) + min(zs)) / 2
        return [
            (
                tabla_de_canto + (p[2] - centro) / ANCHO_EN_METROS,
                V_DE_CANTO + (h - min(horizontal)) / ALTO_EN_METROS,
            )
            for p, h in zip(puntos, horizontal)
        ]
    return [(h / ANCHO_EN_METROS + desplazamiento, (p[2] - PISO) / ALTO_EN_METROS) for p, h in zip(puntos, horizontal)]


def reasignar_uv(objeto, material) -> int:
    malla = objeto.data
    capa = malla.uv_layers.active.data
    indices = {i for i, ranura in enumerate(objeto.material_slots) if ranura.material == material}
    desplazamiento = DESPLAZAMIENTO_DE_U.get(objeto.name, 0.0)
    matriz = objeto.matrix_world
    cantidad = 0
    for cara in malla.polygons:
        if cara.material_index not in indices:
            continue
        puntos = [matriz @ malla.vertices[i].co for i in cara.vertices]
        normal = matriz.to_3x3() @ cara.normal
        centro = sum((p for p in puntos), puntos[0] * 0) / len(puntos)
        # Cada tira de canto sale de una sola tabla, elegida por dónde cae.
        tabla_de_canto = ((int(abs(centro[0] * 7.3 + centro[1] * 3.1)) % TABLAS) + 0.5) / TABLAS
        for lazo, uv in zip(cara.loop_indices, uv_de_cara(puntos, normal, desplazamiento, tabla_de_canto)):
            capa[lazo].uv = uv
        cantidad += 1
    return cantidad


def enlazar_imagen(ruta: Path, relativa: bool):
    import bpy  # type: ignore[import-not-found]

    material = bpy.data.materials[MATERIAL]
    nodo = next(n for n in material.node_tree.nodes if n.type == "TEX_IMAGE")
    anterior = nodo.image
    for imagen in list(bpy.data.images):
        if imagen.filepath and Path(bpy.path.abspath(imagen.filepath)).name == ruta.name:
            bpy.data.images.remove(imagen)
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    if relativa:
        imagen.filepath = "//../source/textures/store/" + ruta.name
    imagen.colorspace_settings.name = "sRGB"
    nodo.image = imagen
    if anterior is not None and anterior != imagen and anterior.users == 0:
        bpy.data.images.remove(anterior)
    return imagen


def main() -> None:
    import bpy  # type: ignore[import-not-found]

    from detalle_de_plastico import escribir_png
    from lib.consola import configurar

    configurar()
    aplicar = "--aplicar" in sys.argv
    destino = DESTINO if aplicar else PRUEBA
    destino.parent.mkdir(parents=True, exist_ok=True)
    escribir_png(pintar(), destino)
    enlazar_imagen(destino, relativa=aplicar)
    material = bpy.data.materials[MATERIAL]
    for nombre in OBJETOS:
        print(nombre, "caras:", reasignar_uv(bpy.data.objects[nombre], material))
    print("imagen:", destino)
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
