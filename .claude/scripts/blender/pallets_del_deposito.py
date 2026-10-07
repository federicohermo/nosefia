"""Reemplazar tablas de estante por pallets y conservar el alcance de las cajas.

Las tres estanterias tienen 3.30 m utiles y sostienen las 31 cajas. Las cajas
superiores no suben. Importar este modulo no modifica Blender.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
OBJETOS = ("gondola_deposito03-col", "gondola_deposito03-col.001")
MARCA = "deposito_pallets_v2"
MARCA_ANTERIOR = "deposito_pallets_v1"
LARGO_ESTANTE = 3.30
LARGO_ANTERIOR = 2.55
LARGO_PALLET = (LARGO_ESTANTE - .02) / 2
ALTURAS = (.55, 1.36, 2.1696505546569824)
ALTURAS_ANTES = (.7861762046813965, 1.4829134941101074, 2.1696505546569824)
PISO = .10223698616027832
ALTO = .12


def _huella(objeto):
    malla = objeto.data
    datos = ([tuple(v.co) for v in malla.vertices],
             [tuple(p.vertices) for p in malla.polygons],
             [[c.name, [tuple(l.uv) for l in c.data]] for c in malla.uv_layers],
             [m.name if m else None for m in malla.materials],
             [p.material_index for p in malla.polygons],
             [tuple(f) for f in objeto.matrix_world])
    return hashlib.sha256(json.dumps(datos).encode()).hexdigest()


def _acero(objeto):
    original = objeto.data
    assert len(original.polygons) == 204, "Medir la estanteria antes de reemplazar los listones."
    vertices, caras, indices, mapa = [], [], [], {}
    capas = {c.name: [] for c in original.uv_layers}
    conservadas = []
    for p in original.polygons:
        if original.materials[p.material_index].name == "deposito_madera_listones":
            continue
        nivel = 2 - (p.index - 24) // 60 if p.index >= 24 else None
        delta = ((ALTURAS[nivel] - ALTURAS_ANTES[nivel] - ALTO + .025)
                 / objeto.matrix_world.to_scale().z) if nivel is not None else 0
        cara = []
        for i in p.vertices:
            if i not in mapa:
                mapa[i] = len(vertices)
                punto = original.vertices[i].co.copy()
                punto.z += delta
                vertices.append(tuple(punto))
            cara.append(mapa[i])
        caras.append(cara)
        indices.append(p.material_index)
        conservadas.append(p.index)
        for capa in original.uv_layers:
            capas[capa.name].extend(tuple(capa.data[i].uv) for i in p.loop_indices)
    nueva = bpy.data.meshes.new(original.name + "_acero_pallets")
    nueva.from_pydata(vertices, [], caras)
    for material in original.materials:
        nueva.materials.append(material)
    for p, indice in zip(nueva.polygons, indices):
        p.material_index = indice
    for nombre, coords in capas.items():
        capa = nueva.uv_layers.new(name=nombre)
        for dato, uv in zip(capa.data, coords):
            dato.uv = uv
    nueva.uv_layers.active = nueva.uv_layers[original.uv_layers.active.name]
    nueva.update()
    objeto.data = nueva
    piezas = []
    for i in range(4, 19):
        puntos = [nueva.vertices[v].co for p in list(nueva.polygons)[i * 6:(i + 1) * 6]
                  for v in p.vertices]
        piezas.append({"nivel": 2 - (i - 4) // 5, "pieza": (i - 4) % 5,
                       "min_local_blender": [min(p[k] for p in puntos) for k in range(3)],
                       "max_local_blender": [max(p[k] for p in puntos) for k in range(3)]})
    return {"caras_antes": 204, "caras_despues": len(caras),
            "postes_conservados": 24, "caras_acero_uv_conservadas": conservadas,
            "alturas_del_acero_superior": [a - ALTO for a in ALTURAS],
            "matrix_blender": [list(f) for f in objeto.matrix_world],
            "piezas": piezas}


def _alargar_acero(objeto):
    original = objeto.data
    assert len(original.polygons) == 114, "La estanteria no es la version de pallets conocida."
    matriz = objeto.matrix_world.copy()
    nueva = original.copy()
    escala = objeto.matrix_world.to_scale().x
    crecimiento = (LARGO_ESTANTE - LARGO_ANTERIOR) / escala
    extremo = max(v.co.x for p in list(original.polygons)[24:36] for v in
                  [original.vertices[i] for i in p.vertices])
    movidos = {}
    for cubo in range(19):
        caras = list(original.polygons)[cubo * 6:(cubo + 1) * 6]
        usados = {i for p in caras for i in p.vertices}
        centro = sum(original.vertices[i].co.x for i in usados) / len(usados)
        pieza = (cubo - 4) % 5
        for i in usados:
            punto = original.vertices[i].co
            if cubo < 4:
                delta = crecimiento if centro > 0 else 0
            elif pieza in (0, 1):
                delta = crecimiento if abs(punto.x - extremo) < 1e-5 else 0
            else:
                delta = (0, crecimiento / 2, crecimiento)[pieza - 2]
            nueva.vertices[i].co.x += delta
            movidos[i] = delta
    nueva.update()
    objeto.data = nueva
    assert objeto.matrix_world == matriz
    assert [tuple(d.uv) for c in original.uv_layers for d in c.data] == [
        tuple(d.uv) for c in nueva.uv_layers for d in c.data]
    assert all(abs(v.co.y - original.vertices[v.index].co.y) < 1e-7
               and abs(v.co.z - original.vertices[v.index].co.z) < 1e-7
               for v in nueva.vertices)
    piezas = []
    postes = []
    for cubo in range(19):
        puntos = [nueva.vertices[v].co for p in list(nueva.polygons)[cubo * 6:(cubo + 1) * 6]
                  for v in p.vertices]
        datos = {"min_local_blender": [min(p[k] for p in puntos) for k in range(3)],
                 "max_local_blender": [max(p[k] for p in puntos) for k in range(3)]}
        if cubo < 4:
            datos["poste"] = cubo
            postes.append(datos)
        else:
            datos.update(nivel=2 - (cubo - 4) // 5, pieza=(cubo - 4) % 5)
            piezas.append(datos)
    return {"caras_antes": 114, "caras_despues": 114, "crecimiento_local_x": crecimiento,
            "largo_util_m": LARGO_ESTANTE, "matriz_conservada": True,
            "uv_conservadas": True, "secciones_y_alturas_conservadas": True,
            "matrix_blender": [list(f) for f in matriz], "piezas": piezas, "postes": postes}


def _piezas(largo, ancho):
    piezas = []

    def pieza(nombre, x0, x1, y0, y1, z0, z1):
        piezas.append({"nombre": nombre, "min": [x0, y0, z0], "max": [x1, y1, z1]})

    xs = (-largo / 2 + .06, 0, largo / 2 - .06)
    ys = (-ancho / 2 + .06, 0, ancho / 2 - .06)
    for j, y in enumerate(ys):
        pieza(f"patin_{j}", -largo / 2, largo / 2, y - .06, y + .06, 0, .02)
        for i, x in enumerate(xs):
            pieza(f"taco_{i}_{j}", x - .06, x + .06, y - .06, y + .06, .02, .08)
    for i, x in enumerate(xs):
        pieza(f"travesano_{i}", x - .06, x + .06, -ancho / 2, ancho / 2, .08, .10)
    ancho_tabla = (ancho - .012 * 4) / 5
    for j in range(5):
        y = -ancho / 2 + j * (ancho_tabla + .012)
        pieza(f"tabla_{j}", -largo / 2, largo / 2, y, y + ancho_tabla, .10, ALTO)
    return piezas


def _malla(nombre, piezas, material):
    vertices, caras, coords = [], [], []
    orden = ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
    for numero, pieza in enumerate(piezas):
        x0, y0, z0 = pieza["min"]
        x1, y1, z1 = pieza["max"]
        puntos = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                  (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        inicio = len(vertices)
        vertices.extend(puntos)
        for cara in orden:
            caras.append(tuple(inicio + i for i in cara))
            for i in cara:
                x, y, z = puntos[i]
                if cara in orden[:2]:
                    coords.append(((x - x0) / .75 + numero * .173, (y - y0) / .18))
                elif cara in (orden[2], orden[4]):
                    coords.append(((x - x0) / .75 + numero * .173, (z - z0) / .18))
                else:
                    coords.append(((y - y0) / .75, (z - z0) / .18))
    malla = bpy.data.meshes.new(nombre)
    malla.from_pydata(vertices, [], caras)
    malla.materials.append(material)
    uv = malla.uv_layers.new(name="UVMap")
    for dato, coord in zip(uv.data, coords):
        dato.uv = coord
    malla.update()
    return malla


def _soportes():
    resultado = []
    for objeto in ("central_derecho", "central_izquierdo", "fondo"):
        if objeto == "fondo":
            modelo = bpy.data.objects[OBJETOS[1]]
            pts = [modelo.matrix_world @ v.co for v in modelo.data.vertices]
            minimo = min(p.x for p in pts) + .060958
            centro = modelo.matrix_world.translation.y
            rotacion = 0
        else:
            minimo = 8.314248085021973
            centro = 3.193497657775879 if objeto == "central_derecho" else -.4149139
            rotacion = 1.5707963267948966
        for nivel, altura in enumerate(ALTURAS):
            for mitad in range(2):
                largo = minimo + LARGO_PALLET / 2 + mitad * (LARGO_PALLET + .02)
                xy = (largo, centro) if objeto == "fondo" else (centro, largo)
                resultado.append({"nombre": f"deposito_pallet_{objeto}_{nivel}_{mitad}",
                                  "modulo": objeto, "nivel": nivel, "mitad": mitad,
                                  "position_blender": [*xy, altura - ALTO],
                                  "rotacion_z": rotacion, "altura_apoyo": altura,
                                  "largo_m": LARGO_PALLET, "ancho_m": .82})
    resultado.append({"nombre": "deposito_pallet_piso", "modulo": "piso", "nivel": 0,
                      "mitad": 0, "position_blender": [.8, 13, PISO],
                      "rotacion_z": 0, "altura_apoyo": PISO + ALTO,
                      "largo_m": 1.2, "ancho_m": .8})
    return resultado


def _cajas(soportes):
    texto = (RAIZ / "src/escenas/puestos/objetos_del_almacen.tscn").read_text(encoding="utf-8")
    producto = (RAIZ / "src/dominio/almacen/producto.gd").read_text(encoding="utf-8")
    catalogo = (RAIZ / "src/dominio/almacen/catalogo.gd").read_text(encoding="utf-8")
    nombres = re.findall(r"^\s*(\w+),", re.search(r"enum Id \{(.*?)\}", producto, re.S)[1], re.M)
    tamanos = dict(re.findall(r"Producto.Id.(\w+): TamanoDeCaja.(\w+)", catalogo))
    cajas = {}
    for bloque in texto.split("[node ")[1:]:
        nombre = re.match(r'name="([^"]+)"', bloque)[1]
        if not nombre.startswith("CajaDe"):
            continue
        identidad = int(re.search(r"^producto = (\d+)", bloque, re.M)[1])
        transform = re.search(r"^(position|transform) = \w+\(([^)]+)\)", bloque, re.M)
        valores = [float(c) for c in transform[2].split(",")]
        posicion = valores if transform[1] == "position" else valores[9:]
        media = .2 if tamanos[nombres[identidad]] == "CHICA" else .3037077
        modulo = ("fondo" if posicion[0] > 5 else
                  "central_derecho" if posicion[0] > 1 else "central_izquierdo")
        nivel = min(range(3), key=lambda n: abs(posicion[1] - media - ALTURAS[n]))
        cajas[identidad] = {"nombre": nombre, "producto": identidad, "media": media,
                            "position_antes": posicion, "modulo": modulo, "nivel": nivel}
    # Las dos cajas del pallet de piso regresan a sus filas superiores originales.
    cajas[22].update(modulo="fondo", nivel=2)
    cajas[24].update(modulo="central_izquierdo", nivel=2)
    for modulo in ("central_derecho", "central_izquierdo", "fondo"):
        for nivel in range(3):
            fila = [c for c in cajas.values() if c["modulo"] == modulo and c["nivel"] == nivel]
            if not fila:
                continue
            eje = 0 if modulo in ("fondo", "piso") else 2
            fila.sort(key=lambda c: c["position_antes"][eje] * (1 if eje == 0 else -1))
            if modulo == "central_izquierdo" and nivel == 2:
                fila.sort(key=lambda c: c["producto"] == 24)
            if modulo == "fondo" and nivel == 2:
                fila.sort(key=lambda c: c["producto"] != 22)
            grupos = [fila] if modulo == "piso" else [fila[:2], fila[2:]]
            for mitad, grupo in enumerate(grupos):
                if not grupo:
                    continue
                apoyo = next(s for s in soportes if s["modulo"] == modulo
                             and s["nivel"] == nivel and s["mitad"] == mitad)
                ocupacion = sum(c["media"] * 2 for c in grupo) + .04 * (len(grupo) - 1)
                assert ocupacion < apoyo["largo_m"], (modulo, nivel, ocupacion)
                cursor = -ocupacion / 2
                for caja in grupo:
                    desplazamiento = cursor + caja["media"]
                    origen = apoyo["position_blender"]
                    if eje == 0:
                        posicion = [origen[0] + desplazamiento,
                                    apoyo["altura_apoyo"] + caja["media"], -origen[1]]
                        base = [0, 0, -1, 0, 1, 0, 1, 0, 0]
                    else:
                        posicion = [origen[0], apoyo["altura_apoyo"] + caja["media"],
                                    -origen[1] - desplazamiento]
                        base = [1, 0, 0, 0, 1, 0, 0, 0, 1]
                    caja.update(position=posicion, basis=base, pallet=apoyo["nombre"],
                                altura_del_apoyo_m=apoyo["altura_apoyo"])
                    cursor += caja["media"] * 2 + .04
    assert len(cajas) == 31 and all("pallet" in c for c in cajas.values())
    return list(cajas.values())


def aplicar():
    configurar()
    if bpy.context.scene.get(MARCA):
        return {"ya_aplicado": True}
    ajenos = {o.name: _huella(o) for o in bpy.data.objects
              if o.type == "MESH" and o.name not in OBJETOS
              and not o.name.startswith("deposito_pallet_")}
    imagenes = [(i.name, i.filepath) for i in bpy.data.images]
    piso = bpy.data.objects.get("deposito_pallet_piso")
    huella_piso = _huella(piso) if piso is not None else None
    if not bpy.context.scene.get(MARCA_ANTERIOR):
        for nombre in OBJETOS:
            _acero(bpy.data.objects[nombre])
        bpy.context.scene[MARCA_ANTERIOR] = True
    acero = {nombre: _alargar_acero(bpy.data.objects[nombre]) for nombre in OBJETOS}
    soportes = _soportes()
    material = bpy.data.materials["deposito_madera_listones"]
    modelos = {}
    coleccion = bpy.data.collections.get("Deposito pallets")
    if coleccion is None:
        coleccion = bpy.data.collections.new("Deposito pallets")
        bpy.context.scene.collection.children.link(coleccion)
    for soporte in soportes:
        tipo = "piso" if soporte["modulo"] == "piso" else "estante"
        if tipo not in modelos:
            piezas = _piezas(soporte["largo_m"], soporte["ancho_m"])
            modelos[tipo] = (_malla("Pallet " + tipo, piezas, material), piezas)
        malla, piezas = modelos[tipo]
        objeto = bpy.data.objects.get(soporte["nombre"])
        if objeto is None:
            objeto = bpy.data.objects.new(soporte["nombre"], malla)
            coleccion.objects.link(objeto)
        else:
            objeto.data = malla
        objeto.location = soporte["position_blender"]
        objeto.rotation_euler.z = soporte["rotacion_z"]
        objeto[MARCA] = True
        soporte["colisiones_local_blender"] = piezas
    bpy.context.view_layer.update()
    assert all(_huella(bpy.data.objects[n]) == huella for n, huella in ajenos.items())
    assert imagenes == [(i.name, i.filepath) for i in bpy.data.images]
    assert huella_piso is None or _huella(bpy.data.objects["deposito_pallet_piso"]) == huella_piso
    cajas = _cajas(soportes)
    bpy.context.scene[MARCA] = True
    return {"acero": acero, "pallets": soportes, "cajas": cajas,
            "objetos_ajenos_identicos": len(ajenos), "rutas_imagenes_conservadas": True,
            "alturas_apoyos": ALTURAS, "altura_pallet_m": ALTO,
            "largo_util_estanterias_m": LARGO_ESTANTE, "pallet_piso_vacio": True,
            "pallet_piso_modelo_conservado": huella_piso is not None,
            "colision": "20 cajas por pallet; conservar abiertos los huecos de horquilla."}


def main():
    configurar()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--salida", type=Path, default=RAIZ / "reports/pallets-deposito.blend")
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    informe = aplicar()
    opciones.salida.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(opciones.salida), check_existing=False)
    reporte = RAIZ / "reports/pallets-deposito-integracion.json"
    reporte.write_text(json.dumps(informe, indent=2), encoding="utf-8")
    print(json.dumps({"salida": str(opciones.salida), "informe": str(reporte)}))


if __name__ == "__main__":
    main()
