"""Ajusta el alto y los herrajes de la compuerta del mostrador para alinearla con el frente.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/ajustar_compuerta_mostrador.py -- [--aplicar]

Sin `--aplicar` modifica sólo la sesión en memoria e informa las medidas. Con `--aplicar` guarda
`assets/models/SEPT_JUEGOS_PROTOTIPO.blend`. Va antes de `listonar_frente_de_madera.py`,
`metal_con_detalle.py`, `armar_atlas.py`, `exportar_modelo.py` e `integrar_modelo.py`.

## Por qué

La hoja de `compuerta_mostrador` iba de `z = 0,222` a `1,050` m y llevaba encima un listón
saliente de `9,2 cm` de espesor hasta `1,072` m. Ese listón sobresalía del plano de la madera y
cortaba la banda superior, mientras el pie bajaba `2,5 cm` más que la madera de
`EscritorioComputadora-col` (`[0,24724, 1,104]` m). Además, las dos placas fijas de las bisagras
del lado del mostrador estaban unidas a la malla móvil: corrían el centro de la caja envolvente y
se metían en el mostrador al girar.

## Qué cambia

- Quita el listón superior saliente de `compuerta_mostrador`.
- Lleva el borde inferior y el superior de la hoja de madera al mismo rango vertical `[z_pie,
  z_tope]` que `MOSTRADOR | Frente de madera` en `EscritorioComputadora-col`, sin tapar la mesada
  blanca ni el zócalo de acero.
- Quita las dos placas fijas del lado del mostrador y conserva en la hoja las placas móviles y los
  tambores de giro.

## Lo que cuesta

Baja 36 triángulos (`96 -> 60`). No agrega materiales, texturas ni llamadas de dibujo. Es
idempotente: correrlo una segunda vez deja los mismos 60 triángulos sin cambios.
"""

import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

configurar()

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
MOSTRADOR = "EscritorioComputadora-col"
COMPUERTA = "compuerta_mostrador"
MADERA = "MOSTRADOR | Frente de madera"
ACERO = "MOSTRADOR | Acero satinado"


def _rango_z_madera(objeto) -> tuple[float, float]:
    malla = objeto.data
    indices = {i for i, m in enumerate(malla.materials) if m is not None and m.name == MADERA}
    matriz = objeto.matrix_world
    zs = [
        (matriz @ malla.vertices[v].co).z
        for p in malla.polygons
        if p.material_index in indices
        for v in p.vertices
    ]
    return min(zs), max(zs)


def _islas_de_caras(bm: bmesh.types.BMesh) -> list[list[bmesh.types.BMFace]]:
    visitadas: set[bmesh.types.BMFace] = set()
    islas: list[list[bmesh.types.BMFace]] = []
    for cara in bm.faces:
        if cara in visitadas:
            continue
        pila = [cara]
        visitadas.add(cara)
        isla = []
        while pila:
            actual = pila.pop()
            isla.append(actual)
            for vertice in actual.verts:
                for vecina in vertice.link_faces:
                    if vecina not in visitadas:
                        visitadas.add(vecina)
                        pila.append(vecina)
        islas.append(isla)
    return islas


def _triangulos(malla) -> int:
    return sum(len(p.vertices) - 2 for p in malla.polygons)


def ajustar() -> tuple[int, int, tuple[float, float]]:
    mostrador = bpy.data.objects[MOSTRADOR]
    compuerta = bpy.data.objects[COMPUERTA]
    z_pie, z_tope = _rango_z_madera(mostrador)

    malla = compuerta.data
    tris_antes = _triangulos(malla)
    nombres = {i: (m.name if m else "") for i, m in enumerate(malla.materials)}
    matriz = compuerta.matrix_world
    inversa = matriz.inverted()

    bm = bmesh.new()
    bm.from_mesh(malla)
    a_borrar: list[bmesh.types.BMFace] = []

    for isla in _islas_de_caras(bm):
        material = nombres.get(isla[0].material_index, "")
        verts = {v for cara in isla for v in cara.verts}
        mundial = [matriz @ v.co for v in verts]
        xs = [p.x for p in mundial]
        ys = [p.y for p in mundial]
        zs = [p.z for p in mundial]
        if material == MADERA:
            if max(ys) - min(ys) > 0.075:
                a_borrar.extend(isla)
            else:
                z_medio = 0.5 * (min(zs) + max(zs))
                for v in verts:
                    punto = matriz @ v.co
                    punto.z = z_pie if punto.z < z_medio else z_tope
                    v.co = inversa @ Vector(punto)
        elif material == ACERO and min(xs) > -1.150:
            a_borrar.extend(isla)

    if a_borrar:
        bmesh.ops.delete(bm, geom=a_borrar, context="FACES")
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    malla.update()
    tris_despues = _triangulos(malla)
    return tris_antes, tris_despues, _rango_z_madera(compuerta)


def main() -> None:
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    guardar = "--aplicar" in argumentos
    antes, despues, (z0, z1) = ajustar()
    print(
        f"{COMPUERTA}: {antes} -> {despues} triángulos ({despues - antes:+d}), "
        f"madera z=[{z0:.5f}, {z1:.5f}]"
    )
    if guardar:
        bpy.ops.wm.save_mainfile()
        print(f"guardado: {FUENTE}")
    else:
        print("sin --aplicar: fuente sin guardar")


if __name__ == "__main__":
    main()
