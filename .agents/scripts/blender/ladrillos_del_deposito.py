"""Los bloques del depósito: textura nueva y bloques que salen del plano en los vanos.

Va después de `texturizar_bloques_del_deposito.py`, que genera los PNG.

Qué cambia, en el `.blend`:

1. **El material `deposito_revestimiento_bloques` usa los PNG nuevos** y sus caras cambian de UV:
   el tile cubre 2,4 m × 3,6 m (6 bloques × 18 hiladas, de 0,40 × 0,20 m) y no repite hacia
   arriba. La traba de la textura corre un tercio de bloque por hilada.
2. **Los vanos con borde saliente ganan bloques de esquina** (`deposito_esquinas_*`): una pieza de
   3 cm por hilada, en traba, que sale de la pared y de la jamba. Es un bloque de esquina: su
   frente y su costado son la misma pieza. El frente termina en una junta de la textura, y el
   costado termina en otra: su UV se apoya en la jamba y no en el plano de la pared. En alto, la
   pieza deja entre hiladas el hueco de la junta pintada. La cara del frente usa la misma
   proyección que la pared, así que muestra el mismo bloque que la pared de al lado y de lejos
   no se distingue de ella. Son los dos vanos de puerta, las dos jambas del portón y los dos
   costados del marco de la puerta del jefe, que no corta la pared.
   Los dinteles quedan sin pieza: la última hilada que los cruza dejaría una cuña de pocos
   centímetros (`MINIMO_DE_LA_PIEZA`).
3. **Los cuatro rincones del depósito ganan piezas en sus dos paredes, intercaladas.** En un
   rincón de obra, el bloque de una pared termina contra la otra, y en la hilada siguiente es
   al revés. Con la pared lisa, los dos bloques de una hilada se encontraban sin junta y se
   leían como uno solo doblado, y el dibujo dejaba tiras de pocos centímetros contra el rincón.
   En cada hilada, a una pared le toca (`_le_toca`) el bloque que termina contra la otra: sale
   `SALIENTE` y lleva su junta en el rincón. El de la otra pared pasa por detrás: sale apenas
   (`RELIEVE_DE_ATRAS`), arranca en el frente de la primera y no lleva junta ahí. Con dos
   salientes distintos, las piezas no se cruzan.
   El frente de las dos no usa la proyección de la pared, sino un bloque entero de la textura
   estirado al largo de la pieza. Los dos bloques de una hilada salen de mitades distintas de
   la textura, una clara y otra oscura, y cada uno es el más distinto del bloque de pared que
   le sigue.
   Un vano muy cerca de un rincón (`CERCA_DEL_RINCON`) se queda con ese lado: su pieza va de la
   jamba al rincón, o al frente de la pieza ajena. Lleva bloques enteros, y una hilada lleva
   uno más que la siguiente: con la misma cuenta, todas las hiladas se veían del mismo ancho.
   Donde lleva dos, la junta entre ellos cambia de lugar de una hilada a otra (`REPARTOS`).
   El bloque da la vuelta a la jamba: el costado sigue el dibujo del frente. Arriba del dintel,
   ese lado vuelve a llevar la pieza del rincón.
   Cada vano es **un objeto aparte**, y los rincones son uno solo. El prefijo del nombre lo toma
   el importador de Godot para sacarlos del horneado.
4. **El cuartito de limpieza usa la misma proyección que el depósito** en sus dos objetos con
   bloques: el revestimiento de la pared de la puerta y el cuerpo, que lleva el fondo y los
   costados. Con la UV vieja, el cuerpo repetía la textura cada 1,8 m y la humedad del pie se
   veía a 1,8 m de altura como una franja oscura de dos hiladas.

El tamaño del bloque (0,40 × 0,20 m) es de esta textura. `revestimiento_del_deposito.py` conserva
el suyo (0,60 × 0,30 m) porque decide la altura del corte, y 12 × 0,30 m = 18 × 0,20 m = 3,6 m.

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
import numpy as np
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FINAL = RAIZ / "assets/source/textures/warehouse/final"
MAPAS = {"color": "deposito_bloques_color.png", "normal": "deposito_bloques_normal.png",
         "rough": "deposito_bloques_rough.png"}
PREFIJO_PIEZAS = "deposito_esquinas_"
CUARTITO = ("cuartito_revestimiento", "cuartito_cuerpo-col")
COBERTURA = (2.4, 3.6)
BLOQUE_METROS = (0.4, 0.2)
N_PX = 1024
JUNTA_PX = 4.4
# La junta pintada mide los mismos píxeles en los dos sentidos, pero el tile no se estira igual.
JUNTA_H = JUNTA_PX * COBERTURA[0] / N_PX
JUNTA_V = JUNTA_PX * COBERTURA[1] / N_PX
SALIENTE = 0.03
MINIMO_DEL_BRAZO = 0.1
MINIMO_DE_LA_PIEZA = 0.06
CANTO_ADENTRO = 0.05
#: El rectángulo del depósito, de pared a pared: (x mínima, y mínima) y (x máxima, y máxima).
SALA = ((-4.594, 8.253), (7.926, 15.398))
COLUMNAS = round(COBERTURA[0] / BLOQUE_METROS[0])
HILADAS = round(COBERTURA[1] / BLOQUE_METROS[1])
#: La pieza de un rincón lleva un bloque entero estirado: más corta, se vería aplastado.
MINIMO_DEL_RINCON = 0.2
#: Qué parte del frente toma el primero de dos bloques. Una junta siempre al medio se veía pareja.
REPARTOS = (0.36, 0.56, 0.44, 0.64)
#: Lo que sale, en un rincón, el bloque que pasa por detrás del de la otra pared.
RELIEVE_DE_ATRAS = 0.01
#: Más lejos que esto, entre la pieza de un vano y la de un rincón siempre cae una junta de la
#: pared, y cada una termina en ella. Más cerca se pisarían.
CERCA_DEL_RINCON = MINIMO_DEL_RINCON + MINIMO_DEL_BRAZO + BLOQUE_METROS[0]


def _receta():
    spec = importlib.util.spec_from_file_location(
        "revestimiento", Path(__file__).with_name("revestimiento_del_deposito.py"))
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


RECETA = _receta()
PISO = RECETA.PISO
ALTO_HILADA = BLOQUE_METROS[1]
ANCHO_BLOQUE = BLOQUE_METROS[0]


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


def _desfase(hilada):
    """La u de una junta vertical de la hilada. La textura corre un tercio de bloque por hilada."""
    return (hilada % 3) * ANCHO_BLOQUE / 3


def _distancia_a_la_junta(u0, sentido, hilada, minimo=MINIMO_DEL_BRAZO):
    """Cuánto falta, hacia `sentido` (±1 en u), para la próxima junta vertical de la hilada.

    Nunca queda menos que `minimo`: si falta menos, el brazo llega a la junta siguiente.
    """
    resto = ((_desfase(hilada) - u0) * sentido) % ANCHO_BLOQUE
    return resto if resto >= minimo else resto + ANCHO_BLOQUE


def _columna(u, hilada):
    """La columna de la textura del bloque de pared que pasa por `u`."""
    return int((u - _desfase(hilada)) // ANCHO_BLOQUE) % COLUMNAS


def _tonos():
    """La luz media de cada bloque de la textura: `tonos[hilada][columna]`."""
    imagen = bpy.data.images.load(str(FINAL / MAPAS["color"]), check_existing=True)
    ancho, alto = imagen.size
    pixeles = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    luz = pixeles.reshape(alto, ancho, 4)[..., :3].mean(axis=2)
    tonos = []
    for hilada in range(HILADAS):
        filas = slice(round((hilada + 0.25) * alto / HILADAS),
                      round((hilada + 0.75) * alto / HILADAS))
        tonos.append([])
        for columna in range(COLUMNAS):
            # El medio del bloque: sin juntas ni bordes.
            desde = (columna + 0.25) * ANCHO_BLOQUE + _desfase(hilada)
            xs = np.arange(round(desde / COBERTURA[0] * ancho),
                           round((desde + ANCHO_BLOQUE / 2) / COBERTURA[0] * ancho)) % ancho
            tonos[-1].append(float(luz[filas][:, xs].mean()))
    return tonos


def _frente_desde_el_rincon(columna, hilada, hacia, desde, hasta, con_junta, bloques=1,
                            reparto=0.5):
    """La u del frente de una pieza de rincón, según lo que falta para el rincón.

    Son `bloques` enteros de la textura, desde `columna` y hacia `hacia` (±1 en u), estirados
    para llenar el frente, que va de `desde` a `hasta`. El último bloque termina con la pieza.
    `con_junta` pone la junta en el rincón: es el bloque que termina contra la otra pared.
    Con dos bloques, `reparto` es la parte del frente que toma el primero.
    """
    arranque = -JUNTA_H / 2 if con_junta else JUNTA_H / 2
    final = bloques * ANCHO_BLOQUE - JUNTA_H / 2
    base = (columna + (hacia < 0)) * ANCHO_BLOQUE + _desfase(hilada)

    def u(al_rincon):
        parte = (al_rincon - desde) / (hasta - desde)
        if bloques != 2:
            en_la_textura = arranque + parte * (final - arranque)
        elif parte <= reparto:
            en_la_textura = arranque + parte / reparto * (ANCHO_BLOQUE - arranque)
        else:
            en_la_textura = ANCHO_BLOQUE + (parte - reparto) / (1 - reparto) * (final - ANCHO_BLOQUE)
        return base + hacia * en_la_textura

    return u


def _le_toca(n_w, hilada):
    """Si el bloque de la pared de normal `n_w` es el que termina contra la otra en esta hilada."""
    return (abs(n_w[0]) > 0.5) == (hilada % 2 == 0)


def _rincon_de(borde, a_w):
    """El rincón al que lleva `a_w` desde `borde`, sobre su pared, y cuánto falta para llegar."""
    (x0, y0), (x1, y1) = SALA
    if a_w[0]:
        x = x1 if a_w[0] > 0 else x0
        return (x, borde[1]), abs(x - borde[0])
    y = y1 if a_w[1] > 0 else y0
    return (borde[0], y), abs(y - borde[1])


def _rincones():
    """Las dos paredes de cada rincón: el punto, hacia dónde corre la pared y su normal."""
    (x0, y0), (x1, y1) = SALA
    for x, hacia_x in ((x0, 1), (x1, -1)):
        for y, hacia_y in ((y0, 1), (y1, -1)):
            yield (x, y), (0, hacia_y), (hacia_x, 0)
            yield (x, y), (hacia_x, 0), (0, hacia_y)


def _pieza(nombre, borde, a_w, n_w, profundidad, z_tope, limites, material, coleccion,
           rincon=None, de_rincon=False, borde_tapado=False, desde_hilada=0, tonos=None):
    """Las piezas de una jamba. `borde` es el punto del borde en el plano de la pared (x, y).

    `rincon` es la distancia a un rincón que la pieza comparte con la otra pared.
    `de_rincon` dice que el borde es el rincón mismo.
    `borde_tapado` descarta la cara del borde, que queda contra otra pared o contra un marco.
    `desde_hilada` saltea las hiladas de abajo, que ya cubre la pieza de un vano.
    `tonos` es la luz de cada bloque de la textura: la pieza del rincón elige el suyo con ella.
    """
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
    hilada = -1
    cuenta = {"piezas": 0, "caras": 0}
    # La u crece hacia la derecha mirando la cara de frente, y la jamba se mira desde el vano.
    derecha = a_w[1] * n_w[0] - a_w[0] * n_w[1]
    while PISO + (hilada + 1) * ALTO_HILADA < z_tope - MINIMO_DE_LA_PIEZA:
        hilada += 1
        if hilada < desde_hilada:
            continue
        le_toca = _le_toca(n_w, hilada)
        z0 = PISO + hilada * ALTO_HILADA + JUNTA_V / 2
        z1 = min(PISO + (hilada + 1) * ALTO_HILADA - JUNTA_V / 2, z_tope)
        junta = _distancia_a_la_junta(u_borde, sentido, hilada,
                                      MINIMO_DEL_RINCON if de_rincon else MINIMO_DEL_BRAZO)
        # El frente termina en el borde del bloque, y no en el centro de la junta pintada.
        brazo = junta - JUNTA_H / 2
        # La u en metros de un punto de la pieza, por su `s`. Es la de la pared, salvo en la pieza
        # que termina contra la otra pared.
        def u_de(s):
            return _u(Vector((borde[0] + a_w[0] * s, borde[1] + a_w[1] * s, PISO)),
                      normal_pared, origen)
        # Dónde arranca la pieza y cuánto sale. La que pasa por detrás arranca en el frente de la otra.
        inicio, saliente = 0.0, SALIENTE
        # La `s` de la junta entre dos bloques de un mismo frente: el dibujo se quiebra ahí, y una
        # cara sola no puede.
        quiebre = None
        if de_rincon:
            if not le_toca:
                inicio, saliente = SALIENTE, RELIEVE_DE_ATRAS
            por_tono = sorted(range(COLUMNAS), key=lambda c: tonos[hilada][c])
            clara = le_toca == (hilada // 2 % 2 == 0)
            mitad = por_tono[COLUMNAS // 2:] if clara else por_tono[:COLUMNAS // 2]
            vecino = tonos[hilada][_columna(u_borde + sentido * (junta + CANTO_ADENTRO), hilada)]
            columna = max(mitad, key=lambda c: abs(tonos[hilada][c] - vecino))
            u_de = _frente_desde_el_rincon(columna, hilada, sentido, inicio, brazo, le_toca)
        elif rincon is not None:
            brazo = rincon if le_toca else rincon - SALIENTE
            bloques = max(1, round(rincon / ANCHO_BLOQUE))
            if not le_toca:
                bloques += 1 if bloques == 1 else -1
            # El frente de una jamba con fondo sigue hasta su canto, pasado el borde.
            desde, hasta = rincon - brazo, rincon + (SALIENTE if profundidad > 0 else 0)
            reparto = REPARTOS[hilada // 2 % len(REPARTOS)]
            frente = _frente_desde_el_rincon(hilada, hilada, -sentido, desde, hasta,
                                             le_toca, bloques, reparto)
            if bloques == 2:
                quiebre = rincon - (desde + reparto * (hasta - desde))
            def u_de(s, frente=frente):
                return frente(rincon - s)
        # El extremo del brazo queda contra la otra pared o contra su pieza.
        extremo_tapado = rincon is not None
        fondo = 0.0
        if profundidad > 0:
            tercio = ANCHO_BLOQUE / 3
            fondo = min(tercio if junta >= 2 * tercio else 2 * tercio, profundidad)
        # Perfil en (s, t): s hacia afuera del vano a lo largo de la pared, t hacia el interior.
        if profundidad > 0:
            perfil = [(brazo, 0), (0, 0), (0, -fondo), (-SALIENTE, -fondo),
                      (-SALIENTE, SALIENTE), (brazo, SALIENTE)]
        else:
            perfil = [(brazo, 0), (inicio, 0), (inicio, saliente), (brazo, saliente)]
        if quiebre is not None:
            perfil.insert(1, (quiebre, 0))
            perfil.insert(-1, (quiebre, perfil[-1][1]))
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
            en_el_borde = borde_tapado and all(abs(s - inicio) < 1e-6 for s, _ in st)
            en_el_extremo = extremo_tapado and all(abs(s - brazo) < 1e-6 for s, _ in st)
            if en_la_pared or en_la_jamba or fondo_del_brazo or en_el_borde or en_el_extremo:
                ocultas.append(cara)
        for cara in caras:
            if cara in ocultas:
                continue
            st = {v: ((v.co.x - borde[0]) * a_w[0] + (v.co.y - borde[1]) * a_w[1],
                            (v.co.x - borde[0]) * n_w[0] + (v.co.y - borde[1]) * n_w[1])
                  for v in cara.verts}
            costado = next((s0 for s0 in {round(s, 6) for s, _ in st.values()}
                            if all(abs(s - s0) < 1e-6 for s, _ in st.values())), None)
            canto = costado is not None and abs(cara.normal.z) < 0.5
            es_jamba = canto and fondo > 0 and abs(costado + SALIENTE) < 1e-6
            for bucle in cara.loops:
                p = bucle.vert.co
                v_uv = (p.z - PISO) / COBERTURA[1]
                if es_jamba and rincon is not None:
                    # El costado repite, espejado, el final del bloque del frente.
                    bucle[capa_uv].uv = (u_de(-st[bucle.vert][1]) / COBERTURA[0], v_uv)
                elif es_jamba:
                    # La jamba: el bloque de esquina da la vuelta y su costado termina en una junta.
                    t_v = st[bucle.vert][1]
                    u_m = _desfase(hilada) + derecha * (JUNTA_H / 2 + t_v + fondo)
                    bucle[capa_uv].uv = (u_m / COBERTURA[0], v_uv)
                elif canto:
                    # El canto de una pieza toma una columna de su cara, adentro del bloque.
                    s_ref = costado - CANTO_ADENTRO if costado > 1e-6 else CANTO_ADENTRO
                    bucle[capa_uv].uv = (u_de(s_ref) / COBERTURA[0], v_uv)
                elif abs(cara.normal.z) > 0.5:
                    # La cara de arriba y la de abajo toman la fila del medio del bloque.
                    v_medio = (hilada + 0.5) * ALTO_HILADA / COBERTURA[1]
                    bucle[capa_uv].uv = (u_de(st[bucle.vert][0]) / COBERTURA[0], v_medio)
                else:
                    # El frente: la proyección de la pared de al lado, o el bloque del rincón.
                    bucle[capa_uv].uv = (u_de(st[bucle.vert][0]) / COBERTURA[0], v_uv)
        forma.faces.ensure_lookup_table()
        bmesh.ops.delete(forma, geom=ocultas, context="FACES_ONLY")
        cuenta["piezas"] += 1
    forma.verts.ensure_lookup_table()
    bmesh.ops.delete(forma, geom=[v for v in forma.verts if not v.link_faces], context="VERTS")
    for cara in forma.faces:
        cara.smooth = False
    forma.to_mesh(malla)
    forma.free()
    malla.update()
    cuenta["hiladas"] = hilada + 1
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
    marco = bpy.data.objects["marco puerta-col"]
    del_marco = [marco.matrix_world @ Vector(c) for c in marco.bound_box]
    y_jefe = min(e.y for e in del_marco), max(e.y for e in del_marco)
    return {
        "puerta_sur": {"bordes": [((5.933, SALA[0][1]), (-1, 0)), ((7.555, SALA[0][1]), (1, 0))],
                       "normal": (0, 1), "profundidad": SALA[0][1] - 7.87, "z": 2.723},
        "puerta_este": {"bordes": [((SALA[1][0], 13.14), (0, -1)), ((SALA[1][0], 14.78), (0, 1))],
                        "normal": (-1, 0), "profundidad": 8.08 - SALA[1][0], "z": 2.722},
        "porton": {"bordes": [((SALA[0][0], y_min), (0, -1)), ((SALA[0][0], y_max), (0, 1))],
                   "normal": (1, 0), "profundidad": 0, "z": z_porton},
        # El marco sale de la pared más que la pieza: la cara del borde queda contra él.
        "puerta_jefe": {"bordes": [((SALA[1][0], y_jefe[0]), (0, -1)),
                                   ((SALA[1][0], y_jefe[1]), (0, 1))],
                        "normal": (-1, 0), "profundidad": 0, "borde_tapado": True,
                        "z": max(e.z for e in del_marco)},
    }


def _unir(formas, nombre):
    bpy.ops.object.select_all(action="DESELECT")
    for pieza in formas:
        pieza.select_set(True)
    bpy.context.view_layer.objects.active = formas[0]
    bpy.ops.object.join()
    unida = bpy.context.view_layer.objects.active
    unida.name = unida.data.name = PREFIJO_PIEZAS + nombre


def aplicar():
    objeto = bpy.data.objects["almacen-col"]
    caras_bloques, limites = _caras_de_bloques(objeto)
    antes = RECETA._huellas(set(caras_bloques))
    material = _material(objeto)
    _reproyectar(objeto, caras_bloques, limites)
    for nombre in CUARTITO:
        cuartito = bpy.data.objects[nombre]
        propias = [c.index for c in cuartito.data.polygons
                   if cuartito.data.materials[c.material_index].name == material.name]
        assert propias, f"{nombre} no tiene caras de bloques"
        vertices_del_cuartito = [tuple(v.co) for v in cuartito.data.vertices]
        _reproyectar(cuartito, propias, limites)
        assert vertices_del_cuartito == [tuple(v.co) for v in cuartito.data.vertices]
    despues = RECETA._huellas(set(caras_bloques))
    # El cuartito cambia a propósito, sólo en su UV: se compara todo lo demás.
    for huellas in (antes, despues):
        for nombre in CUARTITO:
            huellas.pop(nombre)
    assert antes == despues, "Se modificaron mallas o caras ajenas"
    _borrar_piezas()
    coleccion = objeto.users_collection[0]
    informe = {"cobertura_metros": list(COBERTURA), "saliente_m": SALIENTE, "vanos": {}}
    total = 0
    # Los lados de rincón que cubre la pieza de un vano, y hasta qué hilada: (punto, normal).
    cubiertos = {}
    for nombre, vano in _vanos().items():
        suma = {"piezas": 0, "triangulos": 0}
        formas = []
        for indice, (borde, a_w) in enumerate(vano["bordes"]):
            punto, rincon = _rincon_de(borde, a_w)
            cubre = rincon < CERCA_DEL_RINCON
            pieza, cuenta = _pieza(f"__tmp_{nombre}_{indice}", borde, a_w, vano["normal"],
                                   vano["profundidad"], vano["z"], limites, material, coleccion,
                                   rincon=rincon if cubre else None,
                                   borde_tapado=vano.get("borde_tapado", False))
            if cubre:
                cubiertos[punto, vano["normal"]] = cuenta["hiladas"]
            formas.append(pieza)
            suma["piezas"] += cuenta["piezas"]
            suma["triangulos"] += cuenta["triangulos"]
        _unir(formas, nombre)
        total += suma["triangulos"]
        informe["vanos"][nombre] = {**suma, "bordes": [list(b) for b, _ in vano["bordes"]]}
    suma = {"piezas": 0, "triangulos": 0}
    formas = []
    tonos = _tonos()
    for indice, (punto, a_w, n_w) in enumerate(_rincones()):
        pieza, cuenta = _pieza(f"__tmp_rincon_{indice}", punto, a_w, n_w, 0,
                               PISO + COBERTURA[1], limites, material, coleccion,
                               de_rincon=True, borde_tapado=True,
                               desde_hilada=cubiertos.pop((punto, n_w), 0), tonos=tonos)
        formas.append(pieza)
        suma["piezas"] += cuenta["piezas"]
        suma["triangulos"] += cuenta["triangulos"]
    assert not cubiertos, f"Un vano cubre un rincón que no existe: {cubiertos}"
    _unir(formas, "rincones")
    total += suma["triangulos"]
    informe["rincones"] = suma
    informe["triangulos_agregados"] = total
    informe["objetos_agregados"] = len(informe["vanos"]) + 1
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
