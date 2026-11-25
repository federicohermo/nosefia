"""Fotografía las bolsas de galletitas desde la altura de los ojos del jugador: 1,7 m.

    blender <archivo>.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/fotografiar_bolsas.py -- <carpeta> <prefijo>

No guarda el `.blend`. Escribe en `<carpeta>`, por cada producto, `<prefijo>_<producto>_frente.png`,
`..._tres_cuartos.png`, `..._lado.png`, `..._lado_opuesto.png`, `..._dorso.png`,
`..._cara.png` y `..._estante.png`:

- **frente** y **tres cuartos**: la bolsa sola, a 1,7 m de altura y a 1,1 m de ella, de frente y
  girada 35 grados. Es lo que ve el jugador al acercarse.
- **lado** y **lado_opuesto**: la bolsa sola, a 1,7 m, vista desde cada costado.
- **dorso**: la bolsa sola, a 1,7 m, vista desde atrás.
- **cara**: la bolsa sola, a su altura y de frente, sin perspectiva hacia abajo: para mirar la
  textura y la silueta del cierre.
- **estante**: el estante con todo lo que lleva, a 1,7 m de altura y a 1,8 m de él.

Lleva las mismas luces cada vez: dos corridas, antes y después de un cambio, se comparan.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

ALTURA_DE_LOS_OJOS = 1.7

#: Qué se fotografía: la unidad y hacia dónde mira, en el espacio de su malla.
PRODUCTOS = {
    "petisas": ("petisas-convcol", (-1.0, 0.0, 0.0)),
    "macumbas": ("macumbas-convcol", (-1.0, 0.0, 0.0)),
    "donsaturados": ("donsaturados-convcol.001", (-1.0, 0.0, 0.0)),
    "chisitos": ("chisitos2-convcol.001", (1.0, 0.0, 0.0)),
    "laysntt": ("snackpapas1-convcol.002", (1.0, 0.0, 0.0)),
    "oremos": ("oremos-col", (1.0, 0.0, 0.0)),
    "pepito": ("pepitos2-col.025", (1.0, 0.0, 0.0)),
}


def luces() -> None:
    mundo = bpy.data.worlds[0] if bpy.data.worlds else bpy.data.worlds.new("mundo")
    bpy.context.scene.world = mundo
    mundo.use_nodes = True
    fondo = mundo.node_tree.nodes["Background"]
    fondo.inputs["Color"].default_value = (0.55, 0.57, 0.6, 1.0)
    fondo.inputs["Strength"].default_value = 0.9
    rig = (("sol", 2.6, (0.9, 0.2, 0.7)), ("relleno", 0.9, (1.1, 0.0, -2.2)))
    for nombre, energia, giro in rig:
        luz = bpy.data.lights.new(nombre, "SUN")
        luz.energy = energia
        objeto = bpy.data.objects.new(nombre, luz)
        objeto.rotation_euler = giro
        bpy.context.scene.collection.objects.link(objeto)


def centro_del_mundo(objeto) -> Vector:
    puntos = [objeto.matrix_world @ Vector(c) for c in objeto.bound_box]
    return sum(puntos, Vector()) / len(puntos)


def apuntar(camara, desde: Vector, hacia: Vector) -> None:
    camara.location = desde
    camara.rotation_euler = (hacia - desde).to_track_quat("-Z", "Y").to_euler()


def fotografiar(camara, ruta: Path) -> None:
    bpy.context.scene.camera = camara
    bpy.context.scene.render.filepath = str(ruta)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    configurar()
    carpeta, prefijo = sys.argv[sys.argv.index("--") + 1 :][:2]
    carpeta = Path(carpeta)
    carpeta.mkdir(parents=True, exist_ok=True)
    escena = bpy.context.scene
    escena.render.engine = "BLENDER_EEVEE"
    escena.render.resolution_x, escena.render.resolution_y = 1000, 1000
    escena.render.film_transparent = False
    escena.view_settings.view_transform = "Standard"
    luces()
    datos = bpy.data.cameras.new("ojos")
    datos.lens = 105
    camara = bpy.data.objects.new("ojos", datos)
    escena.collection.objects.link(camara)
    todos = [o for o in bpy.data.objects if o.type == "MESH"]
    for clave, (nombre, local) in PRODUCTOS.items():
        objeto = bpy.data.objects[nombre]
        centro = centro_del_mundo(objeto)
        frente = (objeto.matrix_world.to_3x3() @ Vector(local)).normalized()
        frente.z = 0.0
        frente.normalize()
        lado = Vector((-frente.y, frente.x, 0.0))
        escena.render.resolution_x, escena.render.resolution_y = 1000, 1000
        datos.lens = 105
        for o in todos:
            o.hide_render = o is not objeto
        for sufijo, direccion, distancia, altura in (
            ("frente", frente, 1.1, ALTURA_DE_LOS_OJOS),
            (
                "tres_cuartos",
                frente * math.cos(0.61) + lado * math.sin(0.61),
                1.1,
                ALTURA_DE_LOS_OJOS,
            ),
            ("lado", lado, 1.1, ALTURA_DE_LOS_OJOS),
            ("lado_opuesto", -lado, 1.1, ALTURA_DE_LOS_OJOS),
            ("dorso", -frente, 1.1, ALTURA_DE_LOS_OJOS),
            ("cara", frente, 1.0, centro.z),
        ):
            desde = Vector((centro.x, centro.y, 0.0)) + direccion * distancia
            desde.z = altura
            apuntar(camara, desde, centro)
            fotografiar(camara, carpeta / f"{prefijo}_{clave}_{sufijo}.png")
        for o in todos:
            o.hide_render = False
        escena.render.resolution_x, escena.render.resolution_y = 1600, 900
        datos.lens = 32
        desde = Vector((centro.x, centro.y, 0.0)) + frente * 1.8
        desde.z = ALTURA_DE_LOS_OJOS
        apuntar(camara, desde, centro)
        fotografiar(camara, carpeta / f"{prefijo}_{clave}_estante.png")
    print(f"fotos en {carpeta}")


if __name__ == "__main__":
    main()
