"""Arma el render de comprobación de Oremos y de Pepito. Corre en Blender.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/comprobar_textura_de_paquetes.py -- \
        [--oremos <png>] [--pepito <png>] [--salida <carpeta>]

Sin argumentos toma `oremos_paquete.png` y `pepito_paquete.png` de
`reports/paquetes-de-galletitas/`,
los que deja `recortar_paquetes_de_galletitas.py` sin `--aplicar`, y deja los renders en su
`comprobacion/`. **No guarda el `.blend`.** Arma en memoria el paquete con su forma y su UV, le pone
la textura y fotografía, desde la altura de los ojos del jugador (1,7 m):

- `frente`: de frente al pasillo, a 1,7 m.
- `tres_cuartos`: a la misma distancia, 35 grados hacia un lado.
- `en_la_mano`: el paquete a 40 cm de los ojos, inclinado, como cuando se lo levanta.
- `estante`: el estante entero, para ver el paquete entre sus vecinos.

Y una hoja por paquete, `comparacion_<producto>.png`, con la foto real de referencia al lado de
los cuatro renders. Se corta si la textura no mide lo que pide el atlas del paquete.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np
from mathutils import Euler, Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import armar_paquetes_de_galletitas as armado  # noqa: E402
import fotografiar_paquetes_de_galletitas as foto  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

CARPETA = RAIZ / "reports/paquetes-de-galletitas"
ENTREGAS = {
    "OREMOS": CARPETA / "oremos_paquete.png",
    "PEPITO": CARPETA / "pepito_paquete.png",
}
REFERENCIAS = {
    "OREMOS": RAIZ.parent / "referencias/paquete_real_galletitas_rellenas.png",
    "PEPITO": RAIZ.parent / "referencias/paquete_real_galletitas_con_chispas.png",
}
#: A qué distancia de los ojos se sostiene el paquete, y cuánto más abajo que ellos, en metros.
DISTANCIA_EN_LA_MANO = 0.4
CAIDA_EN_LA_MANO = 0.1
INCLINACION_EN_LA_MANO = math.radians(14)


def argumento(nombre: str) -> Path | None:
    if nombre in sys.argv:
        return Path(sys.argv[sys.argv.index(nombre) + 1]).resolve()
    return None


def centro_local(objeto) -> Vector:
    puntos = [v.co for v in objeto.data.vertices]
    return Vector(
        [(min(p[i] for p in puntos) + max(p[i] for p in puntos)) / 2 for i in range(3)]
    )


def en_la_mano(clave: str, base, unidad, carpeta: Path) -> None:
    """El paquete sostenido frente a la cámara, de cara a ella y echado hacia atrás."""
    giro = unidad.matrix_world.to_3x3()
    frente = (giro @ Vector((1, 0, 0))).normalized()
    frente.z = 0
    frente.normalize()
    puntos = [unidad.matrix_world @ v.co for v in unidad.data.vertices]
    centro = sum(puntos, Vector()) / len(puntos)
    ojos = Vector((centro.x, centro.y, foto.ALTURA_DE_LOS_OJOS)) + frente * foto.DISTANCIA
    mirada = -frente
    sostenido = ojos + mirada * DISTANCIA_EN_LA_MANO + Vector((0, 0, -CAIDA_EN_LA_MANO))
    hacia_la_camara = (ojos - sostenido).normalized()
    cuaternion = hacia_la_camara.to_track_quat("X", "Z")
    cuaternion = cuaternion @ Euler((0, -INCLINACION_EN_LA_MANO, 0)).to_quaternion()
    copia = bpy.data.objects.new("en_la_mano", base.data)
    bpy.context.scene.collection.objects.link(copia)
    copia.rotation_mode = "QUATERNION"
    copia.rotation_quaternion = cuaternion
    copia.scale = base.scale
    desfase = Vector(c * s for c, s in zip(centro_local(base), base.scale))
    copia.location = sostenido - cuaternion @ desfase
    bpy.context.view_layer.update()
    foto.foto(f"{clave.lower()}_en_la_mano", ojos, sostenido, 50, carpeta)
    bpy.data.objects.remove(copia)


def leer(ruta: Path):
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    try:
        ancho, alto = imagen.size
        datos = np.empty(ancho * alto * 4, dtype=np.float32)
        imagen.pixels.foreach_get(datos)
        return np.ascontiguousarray(datos.reshape(alto, ancho, 4)[::-1])
    finally:
        bpy.data.images.remove(imagen)


def a_tamano(matriz, ancho: int, alto: int):
    imagen = bpy.data.images.new("escala", matriz.shape[1], matriz.shape[0], alpha=True)
    try:
        imagen.pixels.foreach_set(np.ascontiguousarray(matriz[::-1]).reshape(-1))
        imagen.scale(ancho, alto)
        datos = np.empty(ancho * alto * 4, dtype=np.float32)
        imagen.pixels.foreach_get(datos)
        return np.ascontiguousarray(datos.reshape(alto, ancho, 4)[::-1])
    finally:
        bpy.data.images.remove(imagen)


def hoja_comparativa(clave: str, salida: Path) -> None:
    """La foto real de referencia a la izquierda y los cuatro renders en una grilla."""
    referencia = leer(REFERENCIAS[clave])
    tomas = [
        leer(salida / f"{clave.lower()}_{nombre}.png")
        for nombre in ("frente", "tres_cuartos", "en_la_mano", "estante")
    ]
    ancho_t, alto_t = 700, 500
    alto = 2 * alto_t + 30
    ancho_r = round(referencia.shape[1] * alto / referencia.shape[0])
    hoja = np.ones((alto, ancho_r + 2 * (ancho_t + 10) + 10, 4), dtype=np.float32)
    hoja[..., :3] = 0.1
    hoja[:, :ancho_r] = a_tamano(referencia, ancho_r, alto)
    for i, toma in enumerate(tomas):
        fila, columna = divmod(i, 2)
        x, y = ancho_r + 10 + columna * (ancho_t + 10), 10 + fila * (alto_t + 10)
        hoja[y : y + alto_t, x : x + ancho_t] = a_tamano(toma, ancho_t, alto_t)
    imagen = bpy.data.images.new("hoja", hoja.shape[1], hoja.shape[0], alpha=True)
    try:
        imagen.colorspace_settings.name = "sRGB"
        imagen.pixels.foreach_set(np.ascontiguousarray(hoja[::-1]).reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(salida / f"comparacion_{clave.lower()}.png")
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)


def main() -> None:
    configurar()
    elegidas = {"OREMOS": argumento("--oremos"), "PEPITO": argumento("--pepito")}
    salida = argumento("--salida") or CARPETA / "comprobacion"
    salida.mkdir(parents=True, exist_ok=True)
    hechos = 0
    foto.preparar_la_escena()
    for objeto, (clave, _) in armado.PAQUETES.items():
        ruta = elegidas[clave] or ENTREGAS[clave]
        if not ruta.is_file():
            print(f"{clave}: no hay textura en {ruta}, se saltea")
            continue
        base = bpy.data.objects[objeto]
        armado.apuntar_la_textura(base, ruta, clave)
        armado.armar(base, clave)
        unidad = foto.unidad_de_adelante(clave, base)
        giro = unidad.matrix_world.to_3x3()
        frente = (giro @ Vector((1, 0, 0))).normalized()
        frente.z = 0
        frente.normalize()
        puntos = [unidad.matrix_world @ v.co for v in unidad.data.vertices]
        centro = sum(puntos, Vector()) / len(puntos)
        lado = Vector((-frente.y, frente.x, 0))
        ojos = Vector((centro.x, centro.y, foto.ALTURA_DE_LOS_OJOS))
        angulo = math.radians(35)
        foto.foto(f"{clave.lower()}_frente", ojos + frente * foto.DISTANCIA, centro, 120, salida)
        tres_cuartos = ojos + (frente * math.cos(angulo) + lado * math.sin(angulo)) * foto.DISTANCIA
        foto.foto(f"{clave.lower()}_tres_cuartos", tres_cuartos, centro, 120, salida)
        en_la_mano(clave, base, unidad, salida)
        lejos = ojos + frente * (foto.DISTANCIA + 0.6)
        foto.foto(f"{clave.lower()}_estante", lejos, centro + Vector((0, 0, 0.1)), 40, salida)
        hoja_comparativa(clave, salida)
        print(f"{clave}: renders en {salida}")
        hechos += 1
    if not hechos:
        raise SystemExit("no hay ninguna textura para comprobar")


if __name__ == "__main__":
    main()
