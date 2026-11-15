"""Fotografía los paquetes de Oremos y de Pepito desde la altura de los ojos del jugador.

    blender <archivo>.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/fotografiar_paquetes_de_galletitas.py -- <carpeta>

No guarda el `.blend`. Por cada paquete deja tres tomas, con la cámara a 1,7 m de altura:

- `frente`: a 1,7 m del paquete, de frente al pasillo.
- `tres_cuartos`: a la misma distancia, 35 grados hacia un lado.
- `estante`: el estante entero, para ver el paquete entre sus vecinos.

Elige una unidad de la fila de adelante de la tanda principal, que es la que ve el jugador.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

PAQUETES = {"OREMOS": "oremos-col", "PEPITO": "pepitos2-col.025"}
ALTURA_DE_LOS_OJOS = 1.7
DISTANCIA = 1.7
ANCHO, ALTO = 1400, 1000


def unidad_de_adelante(clave: str, base):
    candidatas = [
        o for o in bpy.data.objects
        if o.data == base.data and o.get("fila") == "adelante" and not o.get("fija", False)
    ]
    if not candidatas:
        candidatas = [o for o in bpy.data.objects if o.data == base.data]
    candidatas.sort(key=lambda o: (o.get("orden", 0), o.name))
    return candidatas[len(candidatas) // 2]


def preparar_la_escena() -> None:
    escena = bpy.context.scene
    escena.render.engine = "BLENDER_WORKBENCH"
    escena.render.resolution_x, escena.render.resolution_y = ANCHO, ALTO
    escena.render.image_settings.file_format = "PNG"
    sombreado = escena.display.shading
    sombreado.light = "STUDIO"
    sombreado.color_type = "TEXTURE"
    sombreado.show_object_outline = False
    sombreado.studio_light = "studio.sl"
    escena.display.render_aa = "8"
    escena.view_settings.view_transform = "Standard"
    escena.world = escena.world or bpy.data.worlds.new("mundo")
    escena.world.color = (0.55, 0.55, 0.58)


def camara(posicion: Vector, objetivo: Vector, focal: float):
    datos = bpy.data.cameras.new("foto")
    datos.lens = focal
    datos.clip_start, datos.clip_end = 0.05, 50
    objeto = bpy.data.objects.new("foto", datos)
    bpy.context.scene.collection.objects.link(objeto)
    objeto.location = posicion
    objeto.rotation_euler = (objetivo - posicion).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = objeto
    return objeto


def foto(nombre: str, posicion: Vector, objetivo: Vector, focal: float, carpeta: Path) -> None:
    objeto = camara(posicion, objetivo, focal)
    bpy.context.view_layer.update()
    bpy.context.scene.render.filepath = str(carpeta / f"{nombre}.png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(objeto)


def main() -> None:
    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1 :]
    carpeta = Path(argumentos[0]).resolve()
    carpeta.mkdir(parents=True, exist_ok=True)
    preparar_la_escena()
    for clave, nombre in PAQUETES.items():
        base = bpy.data.objects[nombre]
        unidad = unidad_de_adelante(clave, base)
        giro = unidad.matrix_world.to_3x3()
        frente = (giro @ Vector((1, 0, 0))).normalized()
        frente.z = 0
        frente.normalize()
        puntos = [unidad.matrix_world @ v.co for v in unidad.data.vertices]
        centro = sum(puntos, Vector()) / len(puntos)
        lado = Vector((-frente.y, frente.x, 0))
        base_xy = Vector((centro.x, centro.y, ALTURA_DE_LOS_OJOS))
        de_frente = base_xy + frente * DISTANCIA
        angulo = math.radians(35)
        a_tres_cuartos = base_xy + (frente * math.cos(angulo) + lado * math.sin(angulo)) * DISTANCIA
        foto(f"{clave.lower()}_frente", de_frente, centro, 120, carpeta)
        foto(f"{clave.lower()}_tres_cuartos", a_tres_cuartos, centro, 120, carpeta)
        lejos = base_xy + frente * (DISTANCIA + 0.6)
        foto(f"{clave.lower()}_estante", lejos, centro + Vector((0, 0, 0.1)), 40, carpeta)
        donde = tuple(round(c, 2) for c in centro)
        print(f"{clave}: {unidad.name} en {donde}")


if __name__ == "__main__":
    main()
