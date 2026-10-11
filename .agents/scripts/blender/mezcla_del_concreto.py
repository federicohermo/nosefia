"""Hornear variaciones PBR: los nodos costosos sólo se ejecutan en Blender.

Dieciséis parches mezclan la misma fotografía, con rotaciones y desplazamientos distintos.
La transición periódica conserva las costuras; las normales giran con cada parche.
El motor recibe tres mapas habituales, sin shaders ni geometría adicionales.
"""

import math
import random

import bpy


def hornear_variaciones(color, normal, rugosidad, destino, fuente, ganancia):
    escena_anterior = bpy.context.window.scene
    escena = bpy.data.scenes.new("__hornear_concreto")
    bpy.context.window.scene = escena
    escena.render.engine = "CYCLES"
    escena.cycles.samples = 1
    escena.render.threads_mode = "FIXED"
    escena.render.threads = 8
    escena.render.bake.margin = 0
    bpy.ops.mesh.primitive_plane_add()
    plano = bpy.context.object
    material = bpy.data.materials.get("deposito_concreto_variaciones_receta")
    if material is not None:
        bpy.data.materials.remove(material)
    material = bpy.data.materials.new("deposito_concreto_variaciones_receta")
    material.use_nodes = True
    material.use_fake_user = True
    plano.data.materials.append(material)
    arbol = material.node_tree
    arbol.nodes.clear()

    def nodo(tipo, **valores):
        n = arbol.nodes.new(tipo)
        for clave, valor in valores.items():
            setattr(n, clave, valor)
        return n

    def conectar(valor, entrada):
        if isinstance(valor, bpy.types.NodeSocket):
            arbol.links.new(valor, entrada)
        else:
            entrada.default_value = valor

    def matematico(operacion, *entradas):
        n = nodo("ShaderNodeMath", operation=operacion)
        for i, valor in enumerate(entradas):
            conectar(valor, n.inputs[i])
        return n.outputs[0]

    def vector(operacion, *entradas):
        n = nodo("ShaderNodeVectorMath", operation=operacion)
        for i, valor in enumerate(entradas):
            conectar(valor, n.inputs[i])
        return n.outputs[0]

    def girar(entrada, angulo):
        n = nodo("ShaderNodeVectorRotate", rotation_type="AXIS_ANGLE")
        conectar(entrada, n.inputs["Vector"])
        n.inputs["Axis"].default_value = (0, 0, 1)
        n.inputs["Angle"].default_value = angulo
        return n.outputs[0]

    def peso(distancia):
        v = matematico("MAXIMUM", matematico("SUBTRACT", 1, distancia), 0)
        return matematico("MULTIPLY", matematico("MULTIPLY", v, v),
                          matematico("SUBTRACT", 3, matematico("MULTIPLY", 2, v)))

    uv = nodo("ShaderNodeTexCoord").outputs["UV"]
    separar = nodo("ShaderNodeSeparateXYZ")
    conectar(vector("MULTIPLY", uv, (4, 4, 1)), separar.inputs[0])
    sumas = {"color": (0, 0, 0), "normal": (0, 0, 0), "rough": (0, 0, 0)}
    azar = random.Random(20261006)
    for fila in range(4):
        for columna in range(4):
            deltas = [matematico("WRAP", matematico("SUBTRACT", separar.outputs[eje],
                      centro + .5), -2, 2) for eje, centro in enumerate((columna, fila))]
            w = matematico("MULTIPLY", *(peso(matematico("ABSOLUTE", d)) for d in deltas))
            combinar = nodo("ShaderNodeCombineXYZ")
            for i, delta in enumerate(deltas):
                conectar(delta, combinar.inputs[i])
            angulo = azar.uniform(-math.pi, math.pi)
            coords = vector("ADD", girar(combinar.outputs[0], angulo),
                            (azar.random(), azar.random(), 0))
            for canal, original in (("color", color), ("normal", normal), ("rough", rugosidad)):
                tex = nodo("ShaderNodeTexImage")
                tex.image = original
                conectar(coords, tex.inputs["Vector"])
                valor = tex.outputs["Color"]
                if canal == "normal":
                    valor = girar(vector("SUBTRACT", vector("MULTIPLY", valor, (2, 2, 2)),
                                         (1, 1, 1)), -angulo)
                    valor = vector("ADD", vector("MULTIPLY", valor, (.5, .5, .5)),
                                   (.5, .5, .5))
                escalar = nodo("ShaderNodeVectorMath", operation="SCALE")
                conectar(valor, escalar.inputs[0])
                conectar(w, escalar.inputs[3])
                sumas[canal] = vector("ADD", sumas[canal], escalar.outputs[0])
    sumas["color"] = vector("MULTIPLY", sumas["color"], (ganancia,) * 3)
    emision = nodo("ShaderNodeEmission")
    salida = nodo("ShaderNodeOutputMaterial")
    conectar(emision.outputs[0], salida.inputs["Surface"])
    objetivo = nodo("ShaderNodeTexImage")
    mapas = {}
    for canal, nombre in (("color", "deposito_concreto_color"),
                          ("normal", "deposito_concreto_normal"),
                          ("rough", "concrete_floor_worn_001_rough_1k")):
        viejo = bpy.data.images.get(nombre)
        if viejo is not None:
            viejo.name = nombre + "_anterior"
        im = bpy.data.images.new(nombre, 1024, 1024, alpha=False)
        im.colorspace_settings.name = "sRGB" if canal == "color" else "Non-Color"
        objetivo.image = im
        arbol.nodes.active = objetivo
        conectar(sumas[canal], emision.inputs[0])
        bpy.ops.object.bake(type="EMIT")
        im.filepath_raw = str(destino / (nombre + ".png"))
        im.file_format = "PNG"
        im.save()
        im.filepath = bpy.path.relpath(im.filepath_raw, start=str(fuente.parent))
        if viejo is not None:
            viejo.user_remap(im)
            # La rugosidad original sigue en la receta; no reemplazar su fotografía por sí misma.
            if viejo == rugosidad:
                for tex in arbol.nodes:
                    if tex.type == "TEX_IMAGE" and tex != objetivo and tex.image == im:
                        tex.image = rugosidad
            else:
                bpy.data.images.remove(viejo)
        mapas[canal] = im
    conectar(sumas["color"], emision.inputs[0])
    objetivo.image = mapas["color"]
    malla = plano.data
    bpy.data.objects.remove(plano, do_unlink=True)
    bpy.data.meshes.remove(malla)
    bpy.context.window.scene = escena_anterior
    bpy.data.scenes.remove(escena)
    return mapas["color"], mapas["normal"], mapas["rough"]
