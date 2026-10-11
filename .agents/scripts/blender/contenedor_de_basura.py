"""Contenedor de plástico con cavidad, tapa abierta, ruedas y pedal para el descarte.

Agrega solamente su colección al modelo. Sin --aplicar guarda una copia en reports.
La tapa conserva su pivote en la bisagra para que el artista pueda cambiar la apertura.
"""

import argparse
import json
import math
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.consola import configurar  # noqa: E402
from lamparas_del_deposito import _material, _malla, _uv  # noqa: E402
from revestimiento_del_deposito import _huellas  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
PREFIJO = "deposito_contenedor_"
CENTRO = (3.0, 14.91247, .102237001)
APERTURA = 78.0
PLASTICOS = RAIZ / "assets/source/textures/props/ambientcg"


def _contorno(ancho, fondo, radio, altura, pasos=1):
    """Una arista por esquina conserva el bisel sin subdividir planos."""
    centros = ((ancho / 2 - radio, fondo / 2 - radio),
               (-ancho / 2 + radio, fondo / 2 - radio),
               (-ancho / 2 + radio, -fondo / 2 + radio),
               (ancho / 2 - radio, -fondo / 2 + radio))
    return [(cx + radio * math.cos(math.radians(90 * esquina + 90 / pasos * paso)),
             cy + radio * math.sin(math.radians(90 * esquina + 90 / pasos * paso)), altura)
            for esquina, (cx, cy) in enumerate(centros) for paso in range(pasos + 1)]


def _perfil(nombre, perfil, material, coleccion, padre, desplazamiento=(0, 0, 0), pasos=1):
    vertices = [(x + desplazamiento[0], y + desplazamiento[1], z + desplazamiento[2])
                for ancho, fondo, radio, altura in perfil
                for x, y, z in _contorno(ancho, fondo, radio, altura, pasos)]
    n = 4 * (pasos + 1)
    caras = [(j * n + i, j * n + (i + 1) % n,
              (j + 1) * n + (i + 1) % n, (j + 1) * n + i)
             for j in range(len(perfil) - 1) for i in range(n)]
    caras += [tuple(reversed(range(n))), tuple(range((len(perfil) - 1) * n,
                                                    len(perfil) * n))]
    return _malla(nombre, vertices, caras, (material,), coleccion, padre)


def _caja(nombre, centro, medidas, material, coleccion, padre):
    ancho, fondo, alto = medidas
    vertices = [(x * ancho / 2, y * fondo / 2, z * alto / 2)
                for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)]
    caras = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
             (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    objeto = _malla(nombre, vertices, caras, (material,), coleccion, padre)
    objeto.location = centro
    return objeto


def _cilindro(nombre, centro, perfil, material, coleccion, padre, segmentos=8):
    # El eje X coincide con el eje de las ruedas. Las tapas quedan planas.
    vertices = [(x, radio * math.cos(2 * math.pi * i / segmentos),
                 radio * math.sin(2 * math.pi * i / segmentos))
                for x, radio in perfil for i in range(segmentos)]
    caras = [(j * segmentos + i, j * segmentos + (i + 1) % segmentos,
              (j + 1) * segmentos + (i + 1) % segmentos, (j + 1) * segmentos + i)
             for j in range(len(perfil) - 1) for i in range(segmentos)]
    caras += [tuple(reversed(range(segmentos))),
              tuple(range((len(perfil) - 1) * segmentos, len(perfil) * segmentos))]
    objeto = _malla(nombre, vertices, caras, (material,), coleccion, padre)
    objeto.location = centro
    for cara in objeto.data.polygons:
        cara.use_smooth = len(cara.vertices) == 4
    return objeto


def _normal_desde_detalles(destino, detalle, material, nombre, lado, alcance):
    """Los relieves quedan en un mapa pequeño; la malla detallada no viaja al juego."""
    imagen = bpy.data.images.get(nombre) or bpy.data.images.new(nombre, lado, lado)
    imagen.colorspace_settings.name = "Non-Color"
    textura = material.node_tree.nodes.new("ShaderNodeTexImage")
    textura.image = imagen
    material.node_tree.nodes.active = textura
    previa = bpy.context.window.scene
    escena = bpy.data.scenes.new("Horneado temporal del contenedor")
    escena.render.engine = "CYCLES"
    escena.cycles.samples = 1
    copias = []
    try:
        for original in (detalle, destino):
            copia = original.copy()
            copia.data = original.data.copy()
            copia.parent = None
            copia.matrix_world = original.matrix_world.copy()
            escena.collection.objects.link(copia)
            copias.append(copia)
        bpy.context.window.scene = escena
        for copia in copias:
            copia.select_set(True)
        bpy.context.view_layer.objects.active = copias[-1]
        bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True,
                            cage_extrusion=alcance, max_ray_distance=2 * alcance,
                            margin=4, normal_space="TANGENT")
        ruta = RAIZ / "assets/source/textures/props" / (nombre + ".png")
        ruta.parent.mkdir(parents=True, exist_ok=True)
        imagen.filepath_raw = str(ruta)
        imagen.file_format = "PNG"
        imagen.save()
        imagen.filepath = bpy.path.relpath(str(ruta), start=str(FUENTE.parent))
    finally:
        bpy.context.window.scene = previa
        for copia in copias:
            malla = copia.data
            bpy.data.objects.remove(copia, do_unlink=True)
            bpy.data.meshes.remove(malla)
        bpy.data.scenes.remove(escena)
    normal = material.node_tree.nodes.new("ShaderNodeNormalMap")
    material.node_tree.links.new(textura.outputs["Color"], normal.inputs["Color"])
    pbr = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    material.node_tree.links.new(normal.outputs["Normal"], pbr.inputs["Normal"])
    malla = detalle.data
    bpy.data.objects.remove(detalle, do_unlink=True)
    bpy.data.meshes.remove(malla)


def _unir(piezas, nombre):
    bpy.ops.object.select_all(action="DESELECT")
    for objeto in piezas:
        objeto.select_set(True)
    bpy.context.view_layer.objects.active = piezas[0]
    bpy.ops.object.join()
    objeto = piezas[0]
    objeto.name = nombre
    _uv(objeto)
    return objeto


def _hornear_acabado(objeto, material, salida, nombre, lado, tipo="EMIT"):
    """Convierte el material de trabajo a una textura, sin luces ni escena ajenas."""
    nodos = material.node_tree.nodes
    enlaces = material.node_tree.links
    imagen = bpy.data.images.get(nombre) or bpy.data.images.new(nombre, lado, lado)
    if tuple(imagen.size) != (lado, lado):
        imagen.scale(lado, lado)
    imagen.colorspace_settings.name = "sRGB" if nombre.endswith("color") else "Non-Color"
    textura = nodos.new("ShaderNodeTexImage")
    textura.image = imagen
    nodos.active = textura
    destino = next(n for n in nodos if n.type == "OUTPUT_MATERIAL")
    anterior = destino.inputs["Surface"].links[0].from_socket
    emision = nodos.new("ShaderNodeEmission")
    if tipo == "EMIT":
        enlaces.new(salida, emision.inputs["Color"])
        enlaces.new(emision.outputs[0], destino.inputs["Surface"])
    escena_previa = bpy.context.window.scene
    escena = bpy.data.scenes.new("Horneado del acabado del contenedor")
    escena.render.engine = "CYCLES"
    escena.cycles.samples = 1
    copia = objeto.copy()
    copia.data = objeto.data.copy()
    copia.parent = None
    copia.matrix_world = objeto.matrix_world.copy()
    escena.collection.objects.link(copia)
    try:
        bpy.context.window.scene = escena
        copia.select_set(True)
        bpy.context.view_layer.objects.active = copia
        bpy.ops.object.bake(type=tipo, use_selected_to_active=False, margin=4)
        ruta = RAIZ / "assets/source/textures/props" / (nombre + ".png")
        ruta.parent.mkdir(parents=True, exist_ok=True)
        imagen.filepath_raw = str(ruta)
        imagen.file_format = "PNG"
        imagen.save()
        imagen.filepath = bpy.path.relpath(str(ruta), start=str(FUENTE.parent))
    finally:
        enlaces.new(anterior, destino.inputs["Surface"])
        nodos.remove(emision)
        bpy.context.window.scene = escena_previa
        malla = copia.data
        bpy.data.objects.remove(copia, do_unlink=True)
        bpy.data.meshes.remove(malla)
        bpy.data.scenes.remove(escena)
    return textura


def _acabado_del_plastico(objeto, material, etiqueta, rotulo=False):
    """Plástico CC0 de ambientCG, desgaste localizado y pictograma propio."""
    nodos = material.node_tree.nodes
    enlaces = material.node_tree.links
    anteriores = set(nodos)

    def nodo(tipo):
        return nodos.new("ShaderNode" + tipo)

    def unir(valor, entrada):
        if isinstance(valor, (float, int)):
            entrada.default_value = valor
        else:
            enlaces.new(valor, entrada)

    def operar(operacion, a, b=0, c=0):
        n = nodo("Math")
        n.operation = operacion
        for valor, entrada in zip((a, b, c), n.inputs):
            unir(valor, entrada)
        return n.outputs[0]

    def mezclar(a, b, factor):
        n = nodo("MixRGB")
        unir(factor, n.inputs[0])
        for valor, entrada in ((a, n.inputs[1]), (b, n.inputs[2])):
            if isinstance(valor, tuple):
                entrada.default_value = (*valor, 1)
            else:
                unir(valor, entrada)
        return n.outputs[0]

    coordenadas = nodo("TexCoord")
    separar = nodo("SeparateXYZ")
    enlaces.new(coordenadas.outputs["Object"], separar.inputs[0])
    x, y, z = separar.outputs

    def mapa(asset, canal):
        ruta = PLASTICOS / asset / (asset + "_1K-JPG_" + canal + ".jpg")
        nombre = PREFIJO + "fuente_" + asset + "_" + canal
        imagen = bpy.data.images.get(nombre)
        if imagen is None:
            imagen = bpy.data.images.load(str(ruta), check_existing=False)
            imagen.name = nombre
        imagen.colorspace_settings.name = "sRGB" if canal == "Color" else "Non-Color"
        imagen.filepath = bpy.path.relpath(str(ruta), start=str(FUENTE.parent))
        n = nodo("TexImage")
        n.image = imagen
        n.projection = "BOX"
        n.projection_blend = .15
        enlaces.new(coordenadas.outputs["Object"], n.inputs["Vector"])
        return n.outputs["Color"]

    # El color queda casi uniforme: el acabado se lee principalmente en la rugosidad.
    gris = nodo("RGBToBW")
    enlaces.new(mapa("Plastic012A", "Color"), gris.inputs[0])
    color = mezclar((.024, .027, .03), gris.outputs[0], .28)
    rugosidad = operar("ADD", .38, operar("MULTIPLY", mapa("Plastic012A", "Roughness"), .26))
    altura = mapa("Plastic012A", "Displacement")
    if rotulo:
        # Los roces aparecen sólo en la parte baja, donde se apoya o arrastra el plástico.
        desgaste = nodo("RGBToBW")
        enlaces.new(mapa("Plastic001", "Color"), desgaste.inputs[0])
        roces = operar("MULTIPLY", operar("MAXIMUM", operar("SUBTRACT", .24, z), 0), 2)
        roces = operar("MULTIPLY", roces, operar("MULTIPLY", desgaste.outputs[0], 2))
        color = mezclar(color, (.075, .078, .08), roces)
        rugosidad = operar("ADD", rugosidad, operar("MULTIPLY", roces, .2))
    if rotulo:
        # Círculo y figura de una persona tirando basura, dibujados en el material.
        # No se copia marca, texto comercial ni fotografía de las referencias.
        def distancia(px, pz):
            return operar("SQRT", operar("ADD",
                operar("MULTIPLY", operar("SUBTRACT", x, px), operar("SUBTRACT", x, px)),
                operar("MULTIPLY", operar("SUBTRACT", z, pz), operar("SUBTRACT", z, pz))))

        def segmento(a, b, grosor):
            dx, dz = b[0] - a[0], b[1] - a[1]
            proyeccion = operar("DIVIDE", operar("ADD",
                operar("MULTIPLY", operar("SUBTRACT", x, a[0]), dx),
                operar("MULTIPLY", operar("SUBTRACT", z, a[1]), dz)), dx * dx + dz * dz)
            t = operar("MINIMUM", operar("MAXIMUM", proyeccion, 0), 1)
            return operar("LESS_THAN", distancia(
                operar("ADD", a[0], operar("MULTIPLY", t, dx)),
                operar("ADD", a[1], operar("MULTIPLY", t, dz))), grosor)

        mascara = operar("LESS_THAN", operar("ABSOLUTE",
            operar("SUBTRACT", distancia(0, .625), .125)), .005)
        mascara = operar("MAXIMUM", mascara, operar("LESS_THAN", distancia(.025, .703), .014))
        trazos = [((.025, .676), (.012, .632), .012),
                  ((.012, .633), (.05, .559), .007),
                  ((.012, .633), (-.016, .562), .007),
                  ((.021, .665), (-.009, .638), .006),
                  ((-.009, .638), (-.047, .654), .006),
                  ((-.089, .626), (-.075, .562), .005),
                  ((-.045, .626), (-.056, .562), .005),
                  ((-.089, .626), (-.045, .626), .005),
                  ((-.075, .562), (-.056, .562), .005)]
        for a, b, grosor in trazos:
            mascara = operar("MAXIMUM", mascara, segmento(a, b, grosor))
        mascara = operar("MULTIPLY", mascara, operar("LESS_THAN", y, -.27))
        color = mezclar(color, (.9, .92, .89), mascara)
        rugosidad = operar("ADD", operar("MULTIPLY", rugosidad,
            operar("SUBTRACT", 1, mascara)), operar("MULTIPLY", mascara, .72))
        # Dos nervaduras verticales y el refuerzo bajo el borde, resueltos con normales.
        separacion = operar("ABSOLUTE", operar("SUBTRACT", operar("ABSOLUTE", x), .228))
        nervadura = operar("MAXIMUM", operar("SUBTRACT", 1,
            operar("DIVIDE", separacion, .009)), 0)
        nervadura = operar("MULTIPLY", nervadura, operar("LESS_THAN", z, 1.015))
        nervadura = operar("MULTIPLY", nervadura, operar("GREATER_THAN", z, .07))
        nervadura = operar("MULTIPLY", nervadura, operar("LESS_THAN", y, -.27))
        altura = operar("ADD", operar("MULTIPLY", altura, .08), nervadura)
    pbr = next(n for n in nodos if n.type == "BSDF_PRINCIPLED")
    normal_existente = pbr.inputs["Normal"].links[0].from_socket if pbr.inputs["Normal"].links else None
    color_horneado = _hornear_acabado(objeto, material, color, PREFIJO + etiqueta + "_color", 256)
    rugosidad_horneada = _hornear_acabado(objeto, material, rugosidad,
                                         PREFIJO + etiqueta + "_roughness", 128)
    relieve = nodo("Bump")
    relieve.inputs["Distance"].default_value = .003 if rotulo else .00018
    if normal_existente:
        enlaces.new(normal_existente, relieve.inputs["Normal"])
    enlaces.new(altura, relieve.inputs["Height"])
    enlaces.new(relieve.outputs["Normal"], pbr.inputs["Normal"])
    normal_horneada = _hornear_acabado(objeto, material, altura,
                                      PREFIJO + etiqueta + "_normal", 256, "NORMAL")
    conservar = anteriores | {color_horneado, rugosidad_horneada, normal_horneada}
    for n in list(nodos):
        if n not in conservar:
            nodos.remove(n)
    enlaces.new(color_horneado.outputs["Color"], pbr.inputs["Base Color"])
    enlaces.new(rugosidad_horneada.outputs["Color"], pbr.inputs["Roughness"])
    if normal_horneada:
        normal = nodo("NormalMap")
        enlaces.new(normal_horneada.outputs["Color"], normal.inputs["Color"])
        enlaces.new(normal.outputs["Normal"], pbr.inputs["Normal"])
    elif normal_existente:
        enlaces.new(normal_existente, pbr.inputs["Normal"])


def aplicar():
    antes = {n: h for n, h in _huellas().items() if not n.startswith(PREFIJO)}
    imagenes = [(im.name, im.filepath) for im in bpy.data.images
                if not im.name.startswith(PREFIJO)]
    for objeto in list(bpy.data.objects):
        if objeto.name.startswith(PREFIJO):
            bpy.data.objects.remove(objeto, do_unlink=True)
    for malla in list(bpy.data.meshes):
        if malla.name.startswith(PREFIJO) and malla.users == 0:
            bpy.data.meshes.remove(malla)
    coleccion = bpy.data.collections.get("Deposito contenedor de basura")
    if coleccion is None:
        coleccion = bpy.data.collections.new("Deposito contenedor de basura")
        bpy.context.scene.collection.children.link(coleccion)
    padre = bpy.data.objects.new(PREFIJO + "soporte", None)
    coleccion.objects.link(padre)
    padre.location = CENTRO
    padre.empty_display_size = .15
    plastico = _material(PREFIJO + "plastico", (.05, .06, .08), 0, .48)
    goma = _material(PREFIJO + "goma", (.018, .02, .024), 0, .88)
    metal = _material(PREFIJO + "metal", (.36, .39, .41), .65, .48)
    plastico_tapa = _material(PREFIJO + "plastico_tapa", (.05, .06, .08), 0, .48)
    goma_detallada = _material(PREFIJO + "goma_detallada", (.018, .02, .024), 0, .88)

    # La pared exterior vuelve por el borde y baja al fondo interior. Es una sola cáscara
    # cerrada con boca abierta y 18 mm de espesor, sin un volumen que rellene la cavidad.
    cuerpo = _perfil(PREFIJO + "cuerpo-col", (
        (.48, .56, .035, .045), (.64, .72, .05, 1.025),
        (.69, .77, .055, 1.025), (.69, .77, .055, 1.065),
        (.674, .754, .05, 1.075), (.604, .684, .042, 1.075),
        (.604, .684, .042, 1.005), (.453, .533, .027, .13)),
        plastico, coleccion, padre)
    piezas = [cuerpo]
    for lado, x in (("izquierda", -.202), ("derecha", .202)):
        piezas.append(_caja(PREFIJO + "pata_" + lado, (x, -.245, .025),
                             (.063, .072, .05), plastico, coleccion, padre))
    # Asa trasera con hueco utilizable: dos apoyos cortos y una barra transversal.
    for x in (-.21, .21):
        piezas.append(_caja(PREFIJO + "asa_apoyo", (x, .396, .995),
                             (.039, .076, .12), plastico, coleccion, padre))
    piezas.append(_caja(PREFIJO + "asa", (0, .417, 1.045),
                         (.46, .037, .037), plastico, coleccion, padre))
    cuerpo = _unir(piezas, PREFIJO + "cuerpo-col")
    # La cara del pictograma ocupa más atlas; las caras lisas requieren menos texeles.
    uv = cuerpo.data.uv_layers.active.data
    for punto in uv:
        punto.uv.x = .64 + .36 * punto.uv.x
    frentes = [cara for cara in cuerpo.data.polygons
               if cara.normal.y < -.99 and cara.center.y < -.25 and cara.area > .4]
    assert len(frentes) == 1, "El atlas requiere una sola cara frontal exterior"
    for indice in frentes[0].loop_indices:
        vertice = cuerpo.data.vertices[cuerpo.data.loops[indice].vertex_index].co
        uv[indice].uv = (.02 + .56 * (vertice.x / .64 + .5),
                          .04 + .92 * (vertice.z - .045) / .98)

    bisagra = bpy.data.objects.new(PREFIJO + "bisagra_tapa", None)
    coleccion.objects.link(bisagra)
    bisagra.parent = padre
    bisagra.location = (0, .352, 1.085)
    bisagra.rotation_euler.x = math.radians(-APERTURA)
    tapa = _perfil(PREFIJO + "tapa-col", (
        (.682, .762, .054, -.014), (.682, .762, .054, .011)),
        plastico_tapa, coleccion, bisagra, desplazamiento=(0, -.352, 0))
    detalle_tapa = _perfil(PREFIJO + "detalle_tapa", (
        (.682, .762, .054, -.014), (.682, .762, .054, .011),
        (.654, .734, .05, .03), (.54, .62, .048, .03),
        (.465, .53, .042, .075)), plastico, coleccion, bisagra,
        desplazamiento=(0, -.352, 0), pasos=3)
    piezas = [detalle_tapa]
    # Dos pequeños agarres elevados cerca de la bisagra; conservan un hueco bajo cada barra.
    for x in (-.23, .23):
        for y in (-.145, -.025):
            piezas.append(_caja(PREFIJO + "agarre_apoyo", (x, y, .04),
                                 (.033, .027, .035), plastico, coleccion, bisagra))
        piezas.append(_caja(PREFIJO + "agarre", (x, -.085, .064),
                             (.034, .145, .025), plastico, coleccion, bisagra))
    detalle_tapa = _unir(piezas, PREFIJO + "detalle_tapa")

    ruedas = []
    detalles_ruedas = []
    for lado, x in (("izquierda", -.311), ("derecha", .311)):
        rueda = _cilindro(PREFIJO + "rueda_" + lado, (x, .25, .14),
                           ((-.043, .135), (.043, .135)),
                           goma_detallada, coleccion, padre)
        ruedas.append(rueda)
        detalle = _cilindro(PREFIJO + "detalle_rueda_" + lado, (x, .25, .14),
                           ((-.043, .065), (-.04, .105), (-.04, .11), (-.031, .135),
                            (.031, .135), (.04, .11), (.04, .105), (.043, .065)),
                           goma, coleccion, padre, 16)
        detalles_ruedas.append(detalle)
        detalles_ruedas.append(_cilindro(PREFIJO + "cubo_" + lado, (x, .25, .14),
                                 ((-.044, .041), (.044, .041)), goma, coleccion, padre, 16))
    ruedas = _unir(ruedas, PREFIJO + "ruedas")
    detalles_ruedas = _unir(detalles_ruedas, PREFIJO + "detalles_ruedas")

    piezas = [_cilindro(PREFIJO + "eje", (0, .25, .14),
                        ((-.352, .013), (.352, .013)), metal, coleccion, padre, 8)]
    piezas.append(_caja(PREFIJO + "pedal", (0, -.31, .15),
                         (.31, .105, .027), metal, coleccion, padre))
    for x in (-.17, .17):
        piezas.append(_caja(PREFIJO + "brazo_pedal", (x, -.055, .115),
                             (.022, .55, .025), metal, coleccion, padre))
    for x in (-.341, .341):
        piezas.append(_caja(PREFIJO + "varilla", (x, .278, .627),
                             (.014, .014, .9), metal, coleccion, padre))
    herrajes = _unir(piezas, PREFIJO + "herrajes")
    bpy.context.view_layer.update()
    _normal_desde_detalles(tapa, detalle_tapa, plastico_tapa,
                           PREFIJO + "tapa_relieve_normal", 256, .09)
    _normal_desde_detalles(ruedas, detalles_ruedas, goma_detallada,
                           PREFIJO + "ruedas_normal", 128, .02)
    for n in plastico_tapa.node_tree.nodes:
        if n.type == "NORMAL_MAP":
            n.inputs["Strength"].default_value = .65
    _acabado_del_plastico(cuerpo, plastico, "cuerpo", rotulo=True)
    _acabado_del_plastico(tapa, plastico_tapa, "tapa")
    despues = _huellas()
    assert all(despues[n] == h for n, h in antes.items()), "Se modificó una malla ajena"
    assert imagenes == [(im.name, im.filepath) for im in bpy.data.images
                       if not im.name.startswith(PREFIJO)]
    triangulos = 0
    for objeto in (cuerpo, tapa, ruedas, herrajes):
        bm = bmesh.new()
        bm.from_mesh(objeto.data)
        assert all(e.is_manifold for e in bm.edges), objeto.name
        assert bm.calc_volume(signed=True) > 0, objeto.name
        assert min(f.calc_area() for f in bm.faces) > 1e-9, objeto.name
        bm.free()
        objeto.data.calc_loop_triangles()
        triangulos += len(objeto.data.loop_triangles)
    assert triangulos <= 400, triangulos
    padre["tapa_abierta_grados"] = APERTURA
    padre["zona_de_descarte_godot"] = (CENTRO[0], CENTRO[2], -CENTRO[1])
    return {"objetos": [o.name for o in (cuerpo, tapa, ruedas, herrajes)],
            "triangulos": triangulos, "materiales": 4, "normales": [256, 256, 128],
            "albedos": [256, 256], "rugosidades": [128, 128],
            "boca_interior_m": [.604, .684], "altura_boca_m": 1.075,
            "apertura_grados": APERTURA, "centro_blender": CENTRO,
            "mallas_ajenas_conservadas": len(antes)}


def main():
    configurar()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    respaldo = RAIZ / "reports/deposito-antes-contenedor.blend"
    if opciones.aplicar and not respaldo.exists():
        shutil.copy2(FUENTE, respaldo)
    destino = FUENTE if opciones.aplicar else RAIZ / "reports/contenedor-basura.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    (RAIZ / "reports/contenedor-basura-integracion.json").write_text(
        json.dumps(resultado, indent=2), encoding="utf-8")
    print(json.dumps(resultado))


if __name__ == "__main__":
    main()
