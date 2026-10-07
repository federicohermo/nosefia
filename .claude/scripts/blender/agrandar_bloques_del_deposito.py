"""Agrandar los bloques mediante sus UV, preservando piso, chapa y altura del revestimiento."""

import json
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import revestimiento_del_deposito as receta

sys.path.insert(0, str(receta.RAIZ / ".claude/scripts"))
from lib.consola import configurar


def aplicar():
    objeto = bpy.data.objects["almacen-col"]
    seleccion, limites = receta._caras(objeto)
    caras = {i for i in seleccion if objeto.data.materials[
        objeto.data.polygons[i].material_index].name == receta.PREFIJO + "bloques"}
    assert len(caras) == 15, "Revisar las caras de bloques antes de aplicar."
    antes = receta._huellas(caras)
    imagenes = [(im.name, im.filepath) for im in bpy.data.images]
    capa = objeto.data.uv_layers.active
    normales = objeto.matrix_world.to_3x3().inverted().transposed()
    cobertura_u, cobertura_v = receta.COBERTURA_BLOQUES
    borde = []
    for numero in caras:
        cara = objeto.data.polygons[numero]
        normal = (normales @ cara.normal).normalized()
        for i in cara.loop_indices:
            p = objeto.matrix_world @ objeto.data.vertices[objeto.data.loops[i].vertex_index].co
            u = ((p.y - limites[0][1]) * (1 if normal.x > 0 else -1)
                 if abs(normal.x) > .9 else
                 (p.x - limites[0][0]) * (-1 if normal.y > 0 else 1))
            capa.data[i].uv = (u / cobertura_u, (p.z - receta.PISO) / cobertura_v)
            if abs(p.z - receta.CORTE) < .0001:
                borde.append(capa.data[i].uv.y)
    assert borde and all(abs(v - receta.HILADAS / 9) < .00001 for v in borde)
    despues = receta._huellas(caras)
    assert antes == despues, "Se modificaron geometria, materiales o UV ajenas."
    assert imagenes == [(im.name, im.filepath) for im in bpy.data.images]
    objeto["deposito_bloque_metros"] = receta.BLOQUE_METROS
    return {"caras": sorted(caras), "bloque_metros": list(receta.BLOQUE_METROS),
            "cobertura_metros": list(receta.COBERTURA_BLOQUES),
            "hiladas_completas": receta.HILADAS, "corte_m": receta.CORTE,
            "junta_superior_uv_v": receta.HILADAS / 9,
            "sobre_porton_m": receta.CORTE - 3.489375,
            "sobre_puerta_jefe_m": receta.CORTE - 2.917734,
            "huellas_antes": antes, "huellas_despues": despues}


def main():
    configurar()
    bpy.ops.wm.open_mainfile(filepath=str(receta.FUENTE), load_ui=False)
    resultado = aplicar()
    destino = (receta.FUENTE if "--aplicar" in sys.argv else
               receta.RAIZ / "reports/deposito-bloques-grandes.blend")
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    (receta.RAIZ / "reports/deposito-bloques-grandes-auditoria.json").write_text(
        json.dumps(resultado, indent=2), encoding="utf-8")
    print("Bloques:", resultado["bloque_metros"], "hiladas:", receta.HILADAS)


if __name__ == "__main__":
    main()
