"""Acortar el deposito y ensancharlo sin deformar muebles ni mover la entrada.

La pared compartida con la tienda conserva su abertura. Las caras del edificio
ajenas al deposito se separan antes de mover sus vertices compartidos. Importar
el modulo no abre ni guarda archivos; aplicar() trabaja sobre la escena abierta.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
MARCA = "deposito_proporciones_v1"
X0, X1 = -6.803772926330566, 7.925535678863525
Y0, Y1 = 8.253290176391602, 14.466056823730469
ANCLAJE_X = 4.647406101226807
DESPLAZAMIENTO_X = (X1 - X0) * .15
DESPLAZAMIENTO_Y = (Y1 - Y0) * .15
NUEVO_X0 = X0 + DESPLAZAMIENTO_X
NUEVO_Y1 = Y1 + DESPLAZAMIENTO_Y
FACTOR_OESTE = (ANCLAJE_X - NUEVO_X0) / (ANCLAJE_X - X0)
TRASLADOS = {
    "gondola_deposito03-col.001": (0, DESPLAZAMIENTO_Y, 0),
    "puertajefe-col": (0, DESPLAZAMIENTO_Y, 0),
    "porton-col": (DESPLAZAMIENTO_X, 0, 0),
}


def coordenada_x(x):
    """Conservar espesor oeste y el ancho de la abertura de entrada."""
    if x <= X0:
        return x + DESPLAZAMIENTO_X
    if x < ANCLAJE_X:
        return ANCLAJE_X + (x - ANCLAJE_X) * FACTOR_OESTE
    return x


def coordenada_y(y):
    """Ampliar el interior conservando los espesores de ambos muros."""
    if y <= Y0:
        return y
    if y < Y1:
        return Y0 + (y - Y0) * 1.15
    return y + DESPLAZAMIENTO_Y


def _punto(punto):
    return Vector((coordenada_x(punto.x), coordenada_y(punto.y), punto.z))


def _huella(objeto):
    malla = objeto.data
    datos = ([tuple(v.co) for v in malla.vertices],
             [tuple(p.vertices) for p in malla.polygons],
             [[c.name, [tuple(l.uv) for l in c.data]] for c in malla.uv_layers],
             [m.name if m else None for m in malla.materials],
             [p.material_index for p in malla.polygons],
             [tuple(f) for f in objeto.matrix_world])
    return hashlib.sha256(json.dumps(datos).encode()).hexdigest()


def _cara(objeto, cara):
    return ([tuple(objeto.data.vertices[i].co) for i in cara.vertices],
            cara.material_index, cara.use_smooth,
            [[c.name, [tuple(c.data[i].uv) for i in cara.loop_indices]]
             for c in objeto.data.uv_layers])


def _edificio():
    objeto = bpy.data.objects["almacen-col"]
    original = objeto.data
    mundo = objeto.matrix_world
    inversa = mundo.inverted()
    seleccion = {p.index for p in original.polygons
                 if max((mundo @ original.vertices[i].co).y for i in p.vertices) > Y0 - .001}
    assert len(seleccion) == 54, "La envolvente cambio: medir las caras del deposito."
    ajenas = {p.index: _cara(objeto, p) for p in original.polygons
             if p.index not in seleccion}
    usados_fuera = {i for p in original.polygons if p.index not in seleccion for i in p.vertices}
    usados_dentro = {i for p in original.polygons if p.index in seleccion for i in p.vertices}
    vertices = [tuple(v.co) for v in original.vertices]
    mapa = {}
    separados = []
    for i in usados_dentro:
        antes = mundo @ original.vertices[i].co
        nuevo = _punto(antes)
        if (antes - nuevo).length < 1e-7:
            mapa[i] = i
            continue
        if i in usados_fuera:
            mapa[i] = len(vertices)
            vertices.append(tuple(inversa @ nuevo))
            separados.append(i)
        else:
            mapa[i] = i
            vertices[i] = tuple(inversa @ nuevo)
    caras = [tuple(mapa[i] for i in p.vertices) if p.index in seleccion
             else tuple(p.vertices) for p in original.polygons]
    malla = bpy.data.meshes.new(original.name + "_proporciones")
    malla.from_pydata(vertices, [], caras)
    for material in original.materials:
        malla.materials.append(material)
    for vieja, nueva in zip(original.polygons, malla.polygons):
        nueva.material_index = vieja.material_index
        nueva.use_smooth = vieja.use_smooth
    for capa in original.uv_layers:
        nueva = malla.uv_layers.new(name=capa.name)
        for i, bucle in enumerate(capa.data):
            nueva.data[i].uv = bucle.uv
    if original.uv_layers.active:
        malla.uv_layers.active = malla.uv_layers[original.uv_layers.active.name]
    # El atlas contiene dieciseis variaciones de 1,5 m y conserva su periodo de 6 m.
    for cara in malla.polygons:
        if cara.index not in seleccion:
            continue
        material = malla.materials[cara.material_index]
        if material.name != "deposito_concreto":
            continue
        for capa in malla.uv_layers:
            for bucle in cara.loop_indices:
                p = mundo @ malla.vertices[malla.loops[bucle].vertex_index].co
                capa.data[bucle].uv = (p.x / 1.75, (p.y - 7.871065) / 1.75)
    malla.update()
    objeto.data = malla
    assert all(_cara(objeto, malla.polygons[i]) == datos for i, datos in ajenas.items())
    return {"caras_del_deposito": sorted(seleccion), "caras_ajenas_identicas": len(ajenas),
            "vertices_separados_de_la_tienda": separados, "repeticion_concreto_m": 1.75}


def aplicar():
    """Modificar envolvente y trasladar piezas completas; nunca escalar cajas."""
    if bpy.context.scene.get(MARCA):
        return {"ya_aplicado": True, "limites_xy": [[NUEVO_X0, Y0], [X1, NUEVO_Y1]]}
    afectados = {"almacen-col", "marco puerta-col", *TRASLADOS}
    afectados.update(o.name for o in bpy.data.objects if o.name.startswith("deposito_techo_"))
    ajenos = {o.name: _huella(o) for o in bpy.data.objects
             if o.type == "MESH" and o.name not in afectados}
    imagenes = [(i.name, i.filepath) for i in bpy.data.images]
    edificio = _edificio()
    techos = []
    for objeto in bpy.data.objects:
        if objeto.type != "MESH" or not objeto.name.startswith("deposito_techo_"):
            continue
        inversa = objeto.matrix_world.inverted()
        for vertice in objeto.data.vertices:
            punto = objeto.matrix_world @ vertice.co
            nuevo = Vector((X1 + (punto.x - X1) * .85, coordenada_y(punto.y), punto.z))
            vertice.co = inversa @ nuevo
        objeto.data.update()
        techos.append(objeto.name)
    for nombre, desplazamiento in TRASLADOS.items():
        objeto = bpy.data.objects[nombre]
        matriz = objeto.matrix_world.copy()
        matriz.translation += Vector(desplazamiento)
        objeto.matrix_world = matriz
    bpy.context.view_layer.update()
    assert all(_huella(bpy.data.objects[n]) == h for n, h in ajenos.items())
    assert imagenes == [(i.name, i.filepath) for i in bpy.data.images]
    bpy.context.scene[MARCA] = True
    return {"limites_antes_xy": [[X0, Y0], [X1, Y1]],
            "limites_xy": [[NUEVO_X0, Y0], [X1, NUEVO_Y1]],
            "dimensiones_antes_m": [X1 - X0, Y1 - Y0],
            "dimensiones_m": [X1 - NUEVO_X0, NUEVO_Y1 - Y0],
            "edificio": edificio, "techo_mallas_adaptadas": len(techos),
            "traslados_m": TRASLADOS, "mallas_ajenas_identicas": len(ajenos),
            "rutas_imagenes_identicas": len(imagenes)}


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destino", type=Path, default=RAIZ / "reports/deposito-proporciones.blend")
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    reporte = RAIZ / "reports/deposito-proporciones.json"
    reporte.parent.mkdir(parents=True, exist_ok=True)
    reporte.write_text(json.dumps(resultado, indent=2), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(opciones.destino), check_existing=False)
    print(json.dumps(resultado, indent=2))


if __name__ == "__main__":
    main()
