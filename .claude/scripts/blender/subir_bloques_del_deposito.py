"""Terminar los bloques en una junta, por encima del marco mas alto del deposito."""

import argparse
import importlib.util
import json
import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
MARCA = "deposito_bloques_hilada_extra"


def _revestimiento():
    spec = importlib.util.spec_from_file_location(
        "revestimiento", Path(__file__).with_name("revestimiento_del_deposito.py"))
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def _cara(objeto, indice):
    cara = objeto.data.polygons[indice]
    return ([tuple(objeto.data.vertices[i].co) for i in cara.vertices],
            cara.material_index, cara.use_smooth,
            [[c.name, [tuple(c.data[i].uv) for i in cara.loop_indices]]
             for c in objeto.data.uv_layers])


def _ajustar_limite(objeto, receta):
    malla = objeto.data
    seleccion = {p.index for p in malla.polygons
                 if malla.materials[p.material_index].name.startswith(receta.PREFIJO)}
    bloques = [p for p in malla.polygons
               if malla.materials[p.material_index].name == receta.PREFIJO + "bloques"]
    anterior = max((objeto.matrix_world @ malla.vertices[i].co).z
                   for p in bloques for i in p.vertices)
    if abs(anterior - receta.CORTE) < .0001:
        return {"ya_aplicado": True, "corte_m": receta.CORTE}
    vertices = {i for p in bloques for i in p.vertices
                if abs((objeto.matrix_world @ malla.vertices[i].co).z - anterior) < .0001}
    assert len(vertices) == 8
    afectadas = {p.index for p in malla.polygons if any(i in vertices for i in p.vertices)}
    assert afectadas <= seleccion
    ajenas = {p.index: _cara(objeto, p.index) for p in malla.polygons
              if p.index not in afectadas}
    antes = receta._huellas()
    posiciones = {v.index: tuple(v.co) for v in malla.vertices if v.index not in vertices}
    inversa = objeto.matrix_world.inverted()
    for i in vertices:
        punto = objeto.matrix_world @ malla.vertices[i].co
        punto.z = receta.CORTE
        malla.vertices[i].co = inversa @ punto
    malla.update()
    resultado = receta.aplicar()
    despues = receta._huellas()
    assert all(despues[n] == h for n, h in antes.items() if n != objeto.name)
    assert all(_cara(objeto, i) == datos for i, datos in ajenas.items())
    assert all(tuple(malla.vertices[i].co) == co for i, co in posiciones.items())
    assert all(p.area > 0 for p in malla.polygons)
    for p in bloques:
        for i in p.loop_indices:
            vertice = malla.loops[i].vertex_index
            z = (objeto.matrix_world @ malla.vertices[vertice].co).z
            if abs(z - receta.CORTE) < .0001:
                assert abs(malla.uv_layers.active.data[i].uv.y - receta.HILADAS / 9) < .00001
    objeto[MARCA] = receta.CORTE
    resultado.update({"corte_anterior_m": anterior, "alto_hilada_m": receta.BLOQUE_METROS[1],
                      "hiladas_completas": receta.HILADAS,
                      "junta_superior_uv_v": receta.HILADAS / 9,
                      "marco_porton_godot_m": 3.489375,
                      "bloques_sobre_porton_m": receta.CORTE - 3.489375,
                      "marco_jefe_godot_m": 2.917734,
                      "caras_ajenas_identicas": len(ajenas),
                      "mallas_ajenas_identicas": len(antes) - 1,
                      "vertices_del_limite": sorted(vertices)})
    return resultado


def aplicar():
    receta = _revestimiento()
    objeto = bpy.data.objects["almacen-col"]
    if objeto.get(MARCA):
        return _ajustar_limite(objeto, receta)
    original = objeto.data
    assert not original.has_custom_normals, "Conservar normales personalizadas antes de reconstruir"
    seleccion = [p.index for p in original.polygons
                 if original.materials[p.material_index].name == receta.PREFIJO + "chapa"]
    assert len(seleccion) == 8
    antes = receta._huellas()
    ajenas = {p.index: _cara(objeto, p.index) for p in original.polygons
              if p.index not in seleccion}
    imagenes = [(im.name, im.filepath) for im in bpy.data.images]
    vertices = [tuple(v.co) for v in original.vertices]
    caras = [list(p.vertices) for p in original.polygons]
    capas = {c.name: [[tuple(c.data[i].uv) for i in p.loop_indices]
                     for p in original.polygons] for c in original.uv_layers}
    intersecciones = {}
    inversa = objeto.matrix_world.inverted()

    def recortar(numero, abajo):
        cara = original.polygons[numero]
        resultado, uv = [], {nombre: [] for nombre in capas}
        for esquina, indice in enumerate(cara.vertices):
            siguiente = (esquina + 1) % len(cara.vertices)
            otro = cara.vertices[siguiente]
            p = objeto.matrix_world @ original.vertices[indice].co
            q = objeto.matrix_world @ original.vertices[otro].co
            dentro = p.z <= receta.CORTE if abajo else p.z >= receta.CORTE
            otro_dentro = q.z <= receta.CORTE if abajo else q.z >= receta.CORTE
            if dentro:
                resultado.append(indice)
                for nombre in capas:
                    uv[nombre].append(capas[nombre][numero][esquina])
            if dentro != otro_dentro:
                t = (receta.CORTE - p.z) / (q.z - p.z)
                arista = tuple(sorted((indice, otro)))
                if arista not in intersecciones:
                    intersecciones[arista] = len(vertices)
                    vertices.append(tuple(inversa @ p.lerp(q, t)))
                resultado.append(intersecciones[arista])
                for nombre in capas:
                    a = Vector(capas[nombre][numero][esquina])
                    b = Vector(capas[nombre][numero][siguiente])
                    uv[nombre].append(tuple(a.lerp(b, t)))
        assert len(resultado) == 4
        return resultado, uv

    tiras, uv_superiores, uv_tiras = [], {}, {}
    for numero in seleccion:
        superior, uv_arriba = recortar(numero, False)
        tira, uv_abajo = recortar(numero, True)
        caras[numero] = superior
        tiras.append(tira)
        uv_superiores[numero] = uv_arriba
        uv_tiras[numero] = uv_abajo
    malla = bpy.data.meshes.new(original.name + "_hilada_extra")
    malla.from_pydata(vertices, [], caras + tiras)
    for material in original.materials:
        malla.materials.append(material)
    for vieja, nueva in zip(original.polygons, malla.polygons):
        nueva.material_index = vieja.material_index
        nueva.use_smooth = vieja.use_smooth
    indice_bloques = malla.materials.find(receta.PREFIJO + "bloques")
    for p in list(malla.polygons)[len(original.polygons):]:
        p.material_index = indice_bloques
    for capa in original.uv_layers:
        nueva = malla.uv_layers.new(name=capa.name)
        nueva.active_render = capa.active_render
        for p in malla.polygons:
            if p.index < len(original.polygons):
                datos = uv_superiores[p.index][capa.name] if p.index in seleccion else (
                    capas[capa.name][p.index])
            else:
                numero = seleccion[p.index - len(original.polygons)]
                datos = uv_tiras[numero][capa.name]
            for i, valor in zip(p.loop_indices, datos):
                nueva.data[i].uv = valor
    malla.uv_layers.active = malla.uv_layers[original.uv_layers.active.name]
    malla.update()
    objeto.data = malla
    assert all(_cara(objeto, i) == datos for i, datos in ajenas.items())
    resultado = receta.aplicar()
    despues = receta._huellas()
    assert all(despues[n] == h for n, h in antes.items() if n != objeto.name)
    assert all(_cara(objeto, i) == datos for i, datos in ajenas.items())
    assert imagenes == [(im.name, im.filepath) for im in bpy.data.images]
    assert all(p.area > 0 for p in malla.polygons)
    assert [tuple(v.co) for v in malla.vertices[:len(original.vertices)]] == (
        [tuple(v.co) for v in original.vertices])
    assert len(intersecciones) == 8
    objeto[MARCA] = receta.CORTE
    resultado.update({"hiladas_completas": receta.HILADAS, "franjas_agregadas": len(tiras),
                      "triangulos_agregados": 16,
                      "vertices_originales_conservados": len(original.vertices),
                      "caras_ajenas_identicas": len(ajenas),
                      "mallas_ajenas_identicas": len(antes) - 1})
    return resultado


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
        respaldo = RAIZ / "reports/deposito-antes-bloques-alineados.blend"
        if not respaldo.exists():
            shutil.copy2(FUENTE, respaldo)
    destino = FUENTE if opciones.aplicar else RAIZ / "reports/deposito-hilada-extra.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    (RAIZ / "reports/deposito-hilada-extra-auditoria.json").write_text(
        json.dumps(resultado, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in resultado.items() if k != "mapas"}))


if __name__ == "__main__":
    main()
