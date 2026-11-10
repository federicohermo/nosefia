"""Los bloques del depósito: textura nueva y bloques que salen del plano en los vanos.

Va después de `texturizar_bloques_del_deposito.py`, que genera los PNG.

Qué cambia, en el `.blend`:

1. **El material `deposito_revestimiento_bloques` usa los PNG nuevos** y sus caras cambian de UV:
   el tile cubre 2,4 m × 3,6 m (4 bloques × 12 hiladas) y no repite hacia arriba. La traba de la
   textura es la de antes, así que las juntas dibujadas siguen donde estaban.
2. **Los vanos con borde saliente ganan bloques de esquina** (`deposito_esquinas_*`): una pieza de
   3 cm por hilada, en traba, que sale de la pared y de la jamba. Cada pieza empieza y termina en
   una junta de la textura, y deja entre hiladas el hueco de la junta: el mortero que se ve ahí es
   el de la pared. La cara de cada pieza usa la misma proyección que la pared, así que de lejos
   no se distingue de ella. Son los dos vanos de puerta y las dos jambas del portón.
   Los dinteles quedan sin pieza: caen a media hilada y dejarían una cuña de 8 cm.
3. Cada vano es **un objeto aparte**, y el nombre lo toma el importador de Godot para dibujarlo
   sólo de cerca (`visibility_range_end`).

Lo que cuesta: los triángulos de las piezas (el informe de la corrida los cuenta) y, de cerca, un
dibujo por vano con material compartido. Los PNG van al mismo color de 1024 px; no hay
materiales ni texturas nuevas por pieza.

Es idempotente: borra las piezas de una corrida anterior y las rehace. No toca la geometría de la
pared, así que su mapa de luz no cambia.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/ladrillos_del_deposito.py -- [--aplicar]
"""

import argparse
import importlib.util
import json
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FINAL = RAIZ / "assets/source/textures/warehouse/final"
MAPAS = {"color": "deposito_bloques_color.png", "normal": "deposito_bloques_normal.png",
         "rough": "deposito_bloques_rough.png"}
PREFIJO_PIEZAS = "deposito_esquinas_"
COBERTURA = (2.4, 3.6)
SALIENTE = 0.03
JUNTA = 0.0103
MINIMO_DEL_BRAZO = 0.15


def _receta():
    spec = importlib.util.spec_from_file_location(
        "revestimiento", Path(__file__).with_name("revestimiento_del_deposito.py"))
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


RECETA = _receta()
PISO = RECETA.PISO
ALTO_HILADA = RECETA.BLOQUE_METROS[1]
ANCHO_BLOQUE = RECETA.BLOQUE_METROS[0]


def _u(p, normal, origen):
    """La coordenada horizontal en metros, la misma que usan la pared y las piezas."""
    if abs(normal.x) > .9:
        return (p.y - origen[1]) * (1 if normal.x > 0 else -1)
    return (p.x - origen[0]) * (-1 if normal.y > 0 else 1)


def _uv(p, normal, origen):
    return (_u(p, normal, origen) / COBERTURA[0], (p.z - PISO) / COBERTURA[1])


def _material(objeto):
    material = bpy.data.materials[RECETA.PREFIJO + "bloques"]
    imagenes = {}
    for clave, archivo in MAPAS.items():
        ruta = FINAL / archivo
        imagen = bpy.data.images.load(str(ruta), check_existing=True)
        imagen.reload()
        imagen.colorspace_settings.name = "sRGB" if clave == "color" else "Non-Color"
        imagen.filepath = bpy.path.relpath(str(ruta), start=str(RECETA.FUENTE.parent))
        imagenes[clave] = imagen
    cambiadas = 0
    for nodo in material.node_tree.nodes:
        if nodo.type != "TEX_IMAGE":
            continue
        enlace = nodo.outputs["Color"].links[0].to_node
        destino = ("color" if enlace.type == "MIX" else
                   "normal" if enlace.type == "NORMAL_MAP" else "rough")
        nodo.image = imagenes[destino]
        cambiadas += 1
    assert cambiadas == 3, "El material no tiene los tres mapas esperados"
    return material


def _caras_de_bloques(objeto):
    """Las caras con el material de bloques y el rincón de la proyección (x mínima, y mínima).

    El rincón es el de las caras del revestimiento, bloques y chapa: el mismo que usaron los
    scripts anteriores, así que la fase de la traba no cambia.
    """
    nombres = (RECETA.PREFIJO + "bloques", RECETA.PREFIJO + "chapa")
    revestidas = [p for p in objeto.data.polygons
                  if objeto.data.materials[p.material_index].name in nombres]
    puntos = [objeto.matrix_world @ objeto.data.vertices[i].co
              for p in revestidas for i in p.vertices]
    limites = [[min(p[k] for p in puntos) for k in range(3)],
               [max(p[k] for p in puntos) for k in range(3)]]
    bloques = [p.index for p in revestidas
               if objeto.data.materials[p.material_index].name == nombres[0]]
    assert bloques, "El depósito no tiene caras de bloques"
    return bloques, limites


def _reproyectar(objeto, caras, limites):
    capa = objeto.data.uv_layers.active
    normales = objeto.matrix_world.to_3x3().inverted().transposed()
    for numero in caras:
        cara = objeto.data.polygons[numero]
        normal = (normales @ cara.normal).normalized()
        for bucle in cara.loop_indices:
            p = objeto.matrix_world @ objeto.data.vertices[objeto.data.loops[bucle].vertex_index].co
            capa.data[bucle].uv = _uv(p, normal, limites[0])


def _distancia_a_la_junta(u0, sentido, hilada):
    """Cuánto falta, hacia `sentido` (±1 en u), para la próxima junta vertical de la hilada.

    La textura corre un tercio de bloque por hilada, con período de tres.
    """
    desfase = (hilada % 3) * ANCHO_BLOQUE / 3
    resto = ((desfase - u0) * sentido) % ANCHO_BLOQUE
    return resto if resto >= MINIMO_DEL_BRAZO else resto + ANCHO_BLOQUE


def _pieza(nombre, borde, a_w, n_w, profundidad, z_tope, limites, material, coleccion):
    """Las piezas de una jamba. `borde` es el punto del borde en el plano de la pared (x, y)."""
    malla = bpy.data.meshes.new(nombre)
    objeto = bpy.data.objects.new(nombre, malla)
    coleccion.objects.link(objeto)
    malla.materials.append(material)
    capa = malla.uv_layers.new(name=bpy.data.objects["almacen-col"].data.uv_layers.active.name)
    forma = bmesh.new()
    capa_uv = forma.loops.layers.uv.new(capa.name)
    origen = limites[0]
    normal_pared = Vector((n_w[0], n_w[1], 0))
    # La pared del depósito mide la u por la normal: se usa la de su plano.
    centro = Vector((borde[0], borde[1], PISO))
    u_borde = _u(centro, normal_pared, origen)
    sentido = 1 if _u(centro + Vector((a_w[0], a_w[1], 0)), normal_pared, origen) > u_borde else -1
    hilada = 0
    cuenta = {"piezas": 0, "caras": 0}
    while PISO + hilada * ALTO_HILADA < z_tope - 0.02:
        z0 = PISO + hilada * ALTO_HILADA + JUNTA / 2
        z1 = min(PISO + (hilada + 1) * ALTO_HILADA - JUNTA / 2, z_tope)
        brazo = _distancia_a_la_junta(u_borde, sentido, hilada)
        brazo = min(brazo, ANCHO_BLOQUE)
        fondo = 0.0
        if profundidad > 0:
            fondo = min(0.2 if brazo >= 0.4 else 0.4, profundidad)
        # Perfil en (s, t): s hacia afuera del vano a lo largo de la pared, t hacia el interior.
        if profundidad > 0:
            perfil = [(brazo, 0), (0, 0), (0, -fondo), (-SALIENTE, -fondo),
                      (-SALIENTE, SALIENTE), (brazo, SALIENTE)]
        else:
            perfil = [(brazo, 0), (0, 0), (0, SALIENTE), (brazo, SALIENTE)]
        puntos = [Vector((borde[0] + a_w[0] * s + n_w[0] * t,
                          borde[1] + a_w[1] * s + n_w[1] * t)) for s, t in perfil]
        abajo = [forma.verts.new((p.x, p.y, z0)) for p in puntos]
        arriba = [forma.verts.new((p.x, p.y, z1)) for p in puntos]
        caras = [forma.faces.new(arriba[::-1]), forma.faces.new(abajo)]
        for i in range(len(puntos)):
            j = (i + 1) % len(puntos)
            caras.append(forma.faces.new((abajo[i], abajo[j], arriba[j], arriba[i])))
        forma.normal_update()
        # Se calcula hacia afuera por el centro: las caras ocultas en la pared se descartan.
        centro_pieza = sum((v.co for v in abajo + arriba), Vector()) / (2 * len(puntos))
        for cara in caras:
            if (cara.calc_center_median() - centro_pieza).dot(cara.normal) < 0:
                cara.normal_flip()
        ocultas = []
        for cara in caras:
            st = [((v.co.x - borde[0]) * a_w[0] + (v.co.y - borde[1]) * a_w[1],
                   (v.co.x - borde[0]) * n_w[0] + (v.co.y - borde[1]) * n_w[1])
                  for v in cara.verts]
            en_la_pared = all(abs(t) < 1e-6 for _, t in st)
            en_la_jamba = profundidad > 0 and all(abs(s) < 1e-6 and t < 1e-6 for s, t in st)
            fondo_del_brazo = profundidad > 0 and all(abs(t + fondo) < 1e-6 for _, t in st)
            if en_la_pared or en_la_jamba or fondo_del_brazo:
                ocultas.append(cara)
        for cara in caras:
            if cara in ocultas:
                continue
            for bucle in cara.loops:
                p = bucle.vert.co
                bucle[capa_uv].uv = _uv(p, cara.normal, origen)
        forma.faces.ensure_lookup_table()
        bmesh.ops.delete(forma, geom=ocultas, context="FACES_ONLY")
        cuenta["piezas"] += 1
        hilada += 1
    forma.verts.ensure_lookup_table()
    bmesh.ops.delete(forma, geom=[v for v in forma.verts if not v.link_faces], context="VERTS")
    for cara in forma.faces:
        cara.smooth = False
    forma.to_mesh(malla)
    forma.free()
    malla.update()
    cuenta["triangulos"] = sum(len(p.vertices) - 2 for p in malla.polygons)
    cuenta["caras"] = len(malla.polygons)
    return objeto, cuenta


def _borrar_piezas():
    for objeto in [o for o in bpy.data.objects if o.name.startswith(PREFIJO_PIEZAS)]:
        malla = objeto.data
        bpy.data.objects.remove(objeto)
        if malla.users == 0:
            bpy.data.meshes.remove(malla)


def _vanos():
    """Los bordes salientes: cada uno con su punto, hacia dónde corre la pared y su profundidad."""
    porton = bpy.data.objects["porton-col"]
    esquinas = [porton.matrix_world @ Vector(c) for c in porton.bound_box]
    y_min, y_max = min(e.y for e in esquinas), max(e.y for e in esquinas)
    z_porton = max(e.z for e in esquinas)
    return {
        "puerta_sur": {"bordes": [((5.933, 8.253), (-1, 0)), ((7.555, 8.253), (1, 0))],
                       "normal": (0, 1), "profundidad": 8.253 - 7.87, "z": 2.723},
        "puerta_este": {"bordes": [((7.926, 13.14), (0, -1)), ((7.926, 14.78), (0, 1))],
                        "normal": (-1, 0), "profundidad": 8.08 - 7.926, "z": 2.722},
        "porton": {"bordes": [((-4.594, y_min), (0, -1)), ((-4.594, y_max), (0, 1))],
                   "normal": (1, 0), "profundidad": 0, "z": z_porton},
    }


def aplicar():
    objeto = bpy.data.objects["almacen-col"]
    caras_bloques, limites = _caras_de_bloques(objeto)
    antes = RECETA._huellas(set(caras_bloques))
    material = _material(objeto)
    _reproyectar(objeto, caras_bloques, limites)
    despues = RECETA._huellas(set(caras_bloques))
    assert antes == despues, "Se modificaron mallas o caras ajenas"
    _borrar_piezas()
    coleccion = objeto.users_collection[0]
    informe = {"cobertura_metros": list(COBERTURA), "saliente_m": SALIENTE, "vanos": {}}
    total = 0
    for nombre, vano in _vanos().items():
        suma = {"piezas": 0, "triangulos": 0}
        formas = []
        for indice, (borde, a_w) in enumerate(vano["bordes"]):
            pieza, cuenta = _pieza(f"__tmp_{nombre}_{indice}", borde, a_w, vano["normal"],
                                   vano["profundidad"], vano["z"], limites, material, coleccion)
            formas.append(pieza)
            suma["piezas"] += cuenta["piezas"]
            suma["triangulos"] += cuenta["triangulos"]
        bpy.ops.object.select_all(action="DESELECT")
        for pieza in formas:
            pieza.select_set(True)
        bpy.context.view_layer.objects.active = formas[0]
        bpy.ops.object.join()
        unida = bpy.context.view_layer.objects.active
        unida.name = unida.data.name = PREFIJO_PIEZAS + nombre
        total += suma["triangulos"]
        informe["vanos"][nombre] = {**suma, "bordes": [list(b) for b, _ in vano["bordes"]]}
    informe["triangulos_agregados"] = total
    informe["objetos_agregados"] = len(informe["vanos"])
    return informe


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path,
                        default=RAIZ / "reports/ladrillos-del-deposito.blend")
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(RECETA.FUENTE), load_ui=False)
    resultado = aplicar()
    destino = RECETA.FUENTE if opciones.aplicar else opciones.destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(resultado, indent=2))


if __name__ == "__main__":
    main()
