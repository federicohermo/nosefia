"""Deja planas y de un solo tono las dos caras grandes de la hoja del baño (`puerta2-col`).

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/aplanar_hoja_del_bano.py -- [--aplicar]

Sin `--aplicar` sólo valida en memoria. Con `--aplicar` guarda la fuente canónica.

## Por qué

`renovar_bano.py` construyó la hoja con un panel central hundido 9 mm respecto del perímetro
(8,2 mm tras el escalado del local). Eso dejó dos problemas visibles en juego:
1. Cuatro trapecios inclinados entre 2,4° y 4,3° alrededor del panel en cada cara, con líneas
   diagonales en las esquinas.
2. En la cara exterior (`-Y`), el cambio de material entre los trapecios (`bano_entrada_blanca`) y
   el panel (`bano_rejilla_texturizada`) marcaba un marco rectangular aun con caras coplanares.

## Qué cambia

Sólo en `puerta2-col`:
- Cada cara grande (`-Y` y `+Y`) pasa a ser un único cuadrilátero plano sobre el perímetro
  exterior, con una sola normal `(0, -1, 0)` y `(0, +1, 0)`.
- La cara exterior (`-Y`) usa `bano_rejilla_texturizada` con `extension = 'EXTEND'` (`CLAMP_TO_EDGE`)
  y sus UV extrapoladas linealmente desde el panel original, manteniendo la rejilla exactamente en
  su lugar físico sin modificar la textura fuente.
- La cara interior (`+Y`) usa `bano_entrada_blanca`.
- Se conservan los cuatro cantos, las dos manijas, las dimensiones, la bisagra, el pivote, el
  encuentro con `bano_marco_entrada` y el barrido de 0° a 90°. Es idempotente.
"""

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector  # type: ignore[import-not-found]
from mathutils.bvhtree import BVHTree  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402
from lib.hoja_del_bano import (  # noqa: E402
    desviacion_maxima_de_caras_grandes,
    esquinas_exteriores,
    hoja_ya_plana,
    plano_exterior_por_lado,
    proyectar_uv_afin,
)

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
OBJETO = "puerta2-col"
MARCO = "bano_marco_entrada"
EDIFICIO = "almacen-col"
MAT_BLANCO = "bano_entrada_blanca"
MAT_REJILLA = "bano_rejilla_texturizada"
MATERIALES_CUERPO = frozenset({MAT_BLANCO, MAT_REJILLA})


def _estado(objeto) -> dict:
    malla = objeto.data
    return {
        "matriz": [list(fila) for fila in objeto.matrix_world],
        "local": [list(fila) for fila in objeto.matrix_local],
        "padre": objeto.parent.name if objeto.parent else None,
        "vertices": [tuple(v.co) for v in malla.vertices],
        "caras": [(tuple(c.vertices), c.material_index, c.use_smooth) for c in malla.polygons],
        "materiales": [m.name if m else None for m in malla.materials],
        "uv": {c.name: [tuple(v.uv) for v in c.data] for c in malla.uv_layers},
    }


def _huella(datos: dict) -> str:
    return hashlib.sha256(json.dumps(datos, sort_keys=True).encode("utf-8")).hexdigest()


def _firma_cara(malla, poligono) -> dict:
    return {
        "puntos": [tuple(round(c, 5) for c in malla.vertices[i].co) for i in poligono.vertices],
        "material": malla.materials[poligono.material_index].name,
        "suave": poligono.use_smooth,
        "uv": {
            capa.name: [tuple(round(c, 5) for c in capa.data[i].uv) for i in poligono.loop_indices]
            for capa in malla.uv_layers
        },
    }


def _verificar_cierre_y_barrido(hoja, marco, edificio, cuerpo: set[int]) -> dict:
    """Comprueba cierre sin rendijas y barrido de 0° a 90° sin cruzar el marco."""
    arboles = {}
    for objeto in (hoja, marco, edificio):
        verts = [objeto.matrix_world @ v.co for v in objeto.data.vertices]
        caras = [tuple(p.vertices) for p in objeto.data.polygons]
        arboles[objeto.name] = BVHTree.FromPolygons(verts, caras)

    ps = [hoja.matrix_world @ hoja.data.vertices[i].co for i in cuerpo]
    x_centro = (min(p.x for p in ps) + max(p.x for p in ps)) / 2.0
    y_min, y_max = min(p.y for p in ps), max(p.y for p in ps)
    z_min, z_max = min(p.z for p in ps), max(p.z for p in ps)
    y_medio = (y_min + y_max) / 2.0

    puntos = [(y_max - 0.002, z) for z in (z_min + 0.25, (z_min + z_max) / 2.0, z_max - 0.15)]
    puntos += [(y_min + 0.002, (z_min + z_max) / 2.0)]
    puntos += [(y, z_min + 0.012) for y in (y_min + 0.2, y_medio, y_max - 0.2)]
    rayos_sin_bloqueo = 0
    for y, z in puntos:
        for pendiente in (-0.15, 0.0, 0.15):
            direccion = Vector((1.0, -pendiente, 0.0))
            for sentido in (-1, 1):
                origen = Vector((x_centro, y, z)) - sentido * direccion * 0.5
                avance = sentido * direccion.normalized()
                golpeado = any(
                    arbol.ray_cast(origen, avance, direccion.length)[0] is not None
                    for arbol in arboles.values()
                )
                if not golpeado:
                    rayos_sin_bloqueo += 1
    assert rayos_sin_bloqueo == 0, f"Quedaron {rayos_sin_bloqueo} rayos sin bloquear al cerrar"

    x_local = min(hoja.data.vertices[i].co.x for i in cuerpo)
    bisagra = hoja.matrix_world @ Vector((x_local, 0.0, 0.0))
    assert max(p.y for p in ps) <= bisagra.y + 1e-5
    arbol_marco = arboles[marco.name]
    marco_x_max = max((marco.matrix_world @ v.co).x for v in marco.data.vertices)
    holgura_minima = float("inf")
    for grados in range(0, 91, 5):
        giro = Matrix.Rotation(math.radians(grados), 4, "Z")
        min_x = min((bisagra + giro @ (p - bisagra)).x for p in ps)
        holgura_minima = min(holgura_minima, min_x - marco_x_max)
        puntos_girados = [
            bisagra + giro @ (hoja.matrix_world @ v.co - bisagra) for v in hoja.data.vertices
        ]
        arbol_hoja = BVHTree.FromPolygons(
            puntos_girados, [tuple(p.vertices) for p in hoja.data.polygons]
        )
        cruces = arbol_marco.overlap(arbol_hoja)
        assert not cruces, f"La hoja cruza el marco a {grados}°: {len(cruces)} pares"
    assert holgura_minima > 0.0, f"Sin holgura frente al rebaje: {holgura_minima}"
    return {
        "rayos_sin_bloqueo": rayos_sin_bloqueo,
        "holgura_minima_mm": round(holgura_minima * 1000.0, 3),
        "intersecciones_en_barrido": 0,
    }


def _fijar_extension_rejilla(material) -> bool:
    """Usa EXTEND (CLAMP_TO_EDGE) para que las UV fuera de [0, 1] continúen el borde blanco."""
    cambiado = False
    for nodo in material.node_tree.nodes:
        if nodo.type == "TEX_IMAGE" and nodo.extension != "EXTEND":
            nodo.extension = "EXTEND"
            cambiado = True
    return cambiado


def _referencias_uv_de_cara(malla, poligono, capa_uv) -> list[tuple[tuple[float, float], tuple[float, float]]]:
    refs = []
    for lazo in poligono.loop_indices:
        v = malla.vertices[malla.loops[lazo].vertex_index].co
        uv = capa_uv.data[lazo].uv
        refs.append(((float(v.x), float(v.z)), (float(uv.x), float(uv.y))))
    return refs


def aplicar() -> dict:
    hoja = bpy.data.objects[OBJETO]
    marco = bpy.data.objects[MARCO]
    edificio = bpy.data.objects[EDIFICIO]
    malla = hoja.data
    assert malla.users == 1, "La hoja debe tener una malla propia"

    vecinos = {
        o.name: _huella(_estado(o))
        for o in bpy.data.objects
        if o.type == "MESH" and o != hoja
    }
    estado_antes = _estado(hoja)

    cuerpo = {
        i
        for p in malla.polygons
        if malla.materials[p.material_index].name in MATERIALES_CUERPO
        for i in p.vertices
    }
    caras_cuerpo = [
        p for p in malla.polygons if malla.materials[p.material_index].name in MATERIALES_CUERPO
    ]
    caras_frente = [p for p in caras_cuerpo if p.normal.y < -0.5]
    caras_dorso = [p for p in caras_cuerpo if p.normal.y > 0.5]
    vertices_antes = [(float(v.co.x), float(v.co.y), float(v.co.z)) for v in malla.vertices]
    desviacion_antes = desviacion_maxima_de_caras_grandes(
        vertices_antes, [tuple(p.vertices) for p in caras_cuerpo]
    )

    slot_blanco = [m.name for m in malla.materials].index(MAT_BLANCO)
    slot_rejilla = [m.name for m in malla.materials].index(MAT_REJILLA)
    mat_rejilla = malla.materials[slot_rejilla]

    ya_plana = hoja_ya_plana(
        [malla.materials[p.material_index].name for p in caras_frente],
        [malla.materials[p.material_index].name for p in caras_dorso],
        desviacion_antes,
        [n.extension for n in mat_rejilla.node_tree.nodes if n.type == "TEX_IMAGE"],
        material_frente=MAT_REJILLA,
        material_dorso=MAT_BLANCO,
    )
    if ya_plana:
        cierre = _verificar_cierre_y_barrido(hoja, marco, edificio, cuerpo)
        return {
            "objeto": OBJETO,
            "ya_plana": True,
            "caras_eliminadas": 0,
            "vertices_eliminados": 0,
            "desviacion_antes_grados": round(desviacion_antes, 6),
            "desviacion_despues_grados": round(desviacion_antes, 6),
            "vecinos_intactos": len(vecinos),
            "cierre_y_barrido": cierre,
        }

    # Conservamos las firmas de los cantos y las manijas antes de simplificar las dos caras grandes.
    caras_grandes_ids = {p.index for p in caras_frente + caras_dorso}
    conservadas_antes = [
        _firma_cara(malla, p) for p in malla.polygons if p.index not in caras_grandes_ids
    ]

    paneles_rejilla = [p for p in caras_frente if p.material_index == slot_rejilla]
    assert len(paneles_rejilla) == 1, "Se requiere exactamente un panel de rejilla en la cara -Y"
    panel_frente = paneles_rejilla[0]
    paneles_dorso = [p for p in caras_dorso if abs(p.normal.y - 1.0) < 1e-4]
    assert len(paneles_dorso) == 1, "Se requiere exactamente un panel plano de referencia en +Y"
    panel_dorso = paneles_dorso[0]

    refs_frente = {
        capa.name: _referencias_uv_de_cara(malla, panel_frente, capa) for capa in malla.uv_layers
    }
    refs_dorso = {
        capa.name: _referencias_uv_de_cara(malla, panel_dorso, capa) for capa in malla.uv_layers
    }

    y_neg, y_pos = plano_exterior_por_lado(vertices_antes, cuerpo)
    esq_frente = esquinas_exteriores(vertices_antes, cuerpo, -1)
    esq_dorso = esquinas_exteriores(vertices_antes, cuerpo, 1)
    exteriores = set(esq_frente) | set(esq_dorso)
    interiores = cuerpo - exteriores

    _fijar_extension_rejilla(mat_rejilla)

    bm = bmesh.new()
    bm.from_mesh(malla)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()

    # Alineamos las 4 esquinas de cada plano exterior para eliminar ruido float32 (< 1 µm).
    for i in esq_frente:
        bm.verts[i].co.y = y_neg
    for i in esq_dorso:
        bm.verts[i].co.y = y_pos

    v_frente = [bm.verts[i] for i in esq_frente]
    v_dorso = [bm.verts[i] for i in esq_dorso]
    verts_interiores = [bm.verts[i] for i in sorted(interiores)]
    caras_a_borrar = [bm.faces[i] for i in sorted(caras_grandes_ids)]
    bmesh.ops.delete(bm, geom=caras_a_borrar, context="FACES")

    verts_sueltos = [v for v in verts_interiores if v.is_valid]
    if verts_sueltos:
        bmesh.ops.delete(bm, geom=verts_sueltos, context="VERTS")

    nueva_frente = bm.faces.new(v_frente)
    nueva_frente.material_index = slot_rejilla
    nueva_frente.smooth = False
    nueva_frente.normal_update()
    if nueva_frente.normal.y > 0:
        nueva_frente.normal_flip()

    nueva_dorso = bm.faces.new(v_dorso)
    nueva_dorso.material_index = slot_blanco
    nueva_dorso.smooth = False
    nueva_dorso.normal_update()
    if nueva_dorso.normal.y < 0:
        nueva_dorso.normal_flip()

    for nombre_capa, capa_bm in bm.loops.layers.uv.items():
        for lazo in nueva_frente.loops:
            lazo[capa_bm].uv = proyectar_uv_afin(
                refs_frente[nombre_capa], (float(lazo.vert.co.x), float(lazo.vert.co.z))
            )
        for lazo in nueva_dorso.loops:
            lazo[capa_bm].uv = proyectar_uv_afin(
                refs_dorso[nombre_capa], (float(lazo.vert.co.x), float(lazo.vert.co.z))
            )

    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    malla.update()
    bpy.context.view_layer.update()

    cuerpo_despues = {
        i
        for p in malla.polygons
        if malla.materials[p.material_index].name in MATERIALES_CUERPO
        for i in p.vertices
    }
    caras_cuerpo_despues = [
        p for p in malla.polygons if malla.materials[p.material_index].name in MATERIALES_CUERPO
    ]
    vertices_finales = [(float(v.co.x), float(v.co.y), float(v.co.z)) for v in malla.vertices]
    desviacion_despues = desviacion_maxima_de_caras_grandes(
        vertices_finales, [tuple(p.vertices) for p in caras_cuerpo_despues]
    )
    assert desviacion_despues < 1e-4, f"Las caras siguen inclinadas: {desviacion_despues}°"

    frente_final = [p for p in caras_cuerpo_despues if p.normal.y < -0.5]
    dorso_final = [p for p in caras_cuerpo_despues if p.normal.y > 0.5]
    assert len(frente_final) == 1 and frente_final[0].material_index == slot_rejilla
    assert len(dorso_final) == 1 and dorso_final[0].material_index == slot_blanco

    estado_despues = _estado(hoja)
    assert estado_despues["matriz"] == estado_antes["matriz"]
    assert estado_despues["local"] == estado_antes["local"]
    assert estado_despues["padre"] == estado_antes["padre"]
    assert estado_despues["materiales"] == estado_antes["materiales"]

    caras_grandes_final = {frente_final[0].index, dorso_final[0].index}
    conservadas_despues = [
        _firma_cara(malla, p) for p in malla.polygons if p.index not in caras_grandes_final
    ]
    assert conservadas_despues == conservadas_antes, "Cambiaron cantos o herrajes"

    for eje in range(3):
        assert abs(
            min(v[eje] for v in vertices_finales) - min(v[eje] for v in vertices_antes)
        ) < 1e-5
        assert abs(
            max(v[eje] for v in vertices_finales) - max(v[eje] for v in vertices_antes)
        ) < 1e-5

    cierre = _verificar_cierre_y_barrido(hoja, marco, edificio, cuerpo_despues)

    cambiados = [
        o.name
        for o in bpy.data.objects
        if o.type == "MESH" and o != hoja and _huella(_estado(o)) != vecinos[o.name]
    ]
    assert not cambiados, f"Cambiaron mallas vecinas: {cambiados}"

    return {
        "objeto": OBJETO,
        "ya_plana": False,
        "caras_eliminadas": len(estado_antes["caras"]) - len(malla.polygons),
        "vertices_eliminados": len(estado_antes["vertices"]) - len(malla.vertices),
        "vertices_finales": len(malla.vertices),
        "caras_finales": len(malla.polygons),
        "desviacion_antes_grados": round(desviacion_antes, 4),
        "desviacion_despues_grados": round(desviacion_despues, 6),
        "vecinos_intactos": len(vecinos),
        "cierre_y_barrido": cierre,
    }


def main() -> None:
    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--aplicar", action="store_true")
    opciones = parser.parse_args(argumentos)
    if Path(bpy.data.filepath).resolve() != FUENTE.resolve():
        raise ValueError(f"Abrir la fuente canónica antes de aplicar: {FUENTE}")
    informe = aplicar()
    informe["guardado"] = opciones.aplicar
    if opciones.aplicar:
        bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE))
    print(json.dumps(informe, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
