"""Una luminaria tubular corta, fijada a la pared sobre el tablero del deposito."""

import argparse
import importlib.util
import json
import math
import shutil
import sys
from pathlib import Path

import bmesh
import bpy

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
PREFIJO = "deposito_tubo_tablero_"


def _receta(nombre):
    ruta = Path(__file__).with_name(nombre + ".py")
    spec = importlib.util.spec_from_file_location(nombre, ruta)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def aplicar():
    """Agregar el arte visible sin rehacer el tablero ni las lamparas del techo."""
    herramientas = _receta("lamparas_del_deposito")
    auditoria = _receta("revestimiento_del_deposito")
    antes = {n: h for n, h in auditoria._huellas().items() if not n.startswith(PREFIJO)}
    imagenes = [(im.name, im.filepath) for im in bpy.data.images]
    for objeto in list(bpy.data.objects):
        if objeto.name.startswith(PREFIJO):
            bpy.data.objects.remove(objeto, do_unlink=True)
    coleccion = bpy.data.collections.get("Deposito tubo del tablero")
    if coleccion is None:
        coleccion = bpy.data.collections.new("Deposito tubo del tablero")
        bpy.context.scene.collection.children.link(coleccion)
    padre = bpy.data.objects.new(PREFIJO + "soporte", None)
    coleccion.objects.link(padre)
    padre.location = (1.408411, 8.44, 2.32)
    metal = herramientas._material(PREFIJO + "metal", (.23, .245, .25), .45, .65)
    luminoso = herramientas._material(PREFIJO + "difusor", (1, .96, .88), 0, .5, 1.2)
    cable = herramientas._material(PREFIJO + "cable", (.018, .021, .02), 0, .85)
    placa = herramientas._caja(PREFIJO + "placa", (.494, .034, .058), 0,
                               metal, coleccion, padre)
    placa.location.y = -.168
    for lado, x in (("izquierdo", -.235), ("derecho", .235)):
        casquillo = herramientas._caja(PREFIJO + lado, (.024, .168, .06), 0,
                                      metal, coleccion, padre)
        casquillo.location = (x, -.077, 0)
    segmentos = 8
    radio = .015
    vertices = [(x, radio * math.cos(2 * math.pi * i / segmentos),
                 radio * math.sin(2 * math.pi * i / segmentos))
                for x in (-.223, .223) for i in range(segmentos)]
    caras = [(i, (i + 1) % segmentos, (i + 1) % segmentos + segmentos, i + segmentos)
             for i in range(segmentos)]
    caras += [tuple(range(segmentos)), tuple(range(segmentos, segmentos * 2))]
    tubo = herramientas._malla(PREFIJO + "tubo_luminoso", vertices, caras,
                              (luminoso,), coleccion, padre)
    for cara in tubo.data.polygons:
        cara.use_smooth = len(cara.vertices) == 4
    alimentacion = herramientas._caja(PREFIJO + "alimentacion", (.012, .012, .14), -.10,
                                      cable, coleccion, padre)
    alimentacion.location = (-.18, -.14, 0)
    bpy.context.view_layer.update()
    despues = auditoria._huellas()
    assert all(despues[n] == h for n, h in antes.items()), "Se modifico una malla ajena"
    assert imagenes == [(im.name, im.filepath) for im in bpy.data.images]
    triangulos = 0
    piezas = []
    for objeto in coleccion.objects:
        if objeto.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(objeto.data)
        assert all(arista.is_manifold for arista in bm.edges)
        assert bm.calc_volume(signed=True) > 0
        assert objeto.data.uv_layers.active is not None
        assert all(cara.area > 0 for cara in objeto.data.polygons)
        bm.free()
        objeto.data.calc_loop_triangles()
        triangulos += len(objeto.data.loop_triangles)
        piezas.append(objeto.name)
    return {"piezas": piezas, "triangulos": triangulos, "largo_tubo_m": .446,
            "diametro_tubo_m": .03, "centro_godot": [1.408411, 2.32, -8.44],
            "mallas_ajenas_conservadas": len(antes), "mallas_cerradas_y_uv": True}


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    if opciones.aplicar:
        respaldo = RAIZ / "reports/deposito-antes-tubo-tablero.blend"
        if not respaldo.exists():
            shutil.copy2(FUENTE, respaldo)
    destino = FUENTE if opciones.aplicar else RAIZ / "reports/tubo-del-tablero.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    (RAIZ / "reports/tubo-del-tablero-auditoria.json").write_text(
        json.dumps(resultado, indent=2), encoding="utf-8")
    print(json.dumps(resultado))


if __name__ == "__main__":
    main()
