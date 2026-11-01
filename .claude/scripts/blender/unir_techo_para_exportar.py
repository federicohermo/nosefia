"""Agrupa las piezas de acero del techo sólo durante la exportación."""

import bpy  # type: ignore[import-not-found]


def unir() -> tuple[list[str], str]:
    piezas = [
        objeto for objeto in bpy.context.view_layer.objects
        if objeto.type == "MESH"
        and objeto.parent is not None
        and objeto.parent.name == "deposito_techo_industrial"
        and len(objeto.data.materials) == 1
        and objeto.data.materials[0] is not None
        and objeto.data.materials[0].name == "deposito_techo_acero"
        and objeto.visible_get()
    ]
    if len(piezas) < 2:
        raise RuntimeError("No se encontraron las piezas visibles del techo para unir")
    bpy.ops.object.select_all(action="DESELECT")
    copias = []
    for pieza in piezas:
        copia = pieza.copy()
        copia.data = pieza.data.copy()
        bpy.context.collection.objects.link(copia)
        copia.select_set(True)
        copias.append(copia)
        pieza.hide_set(True)
    bpy.context.view_layer.objects.active = copias[0]
    bpy.ops.object.join()
    unido = copias[0]
    unido.name = "deposito_techo_acero_unido"
    print(f"piezas de acero del techo unidas: {len(piezas)}")
    return [pieza.name for pieza in piezas], unido.name


def restaurar(nombres: list[str], unido: str) -> None:
    objeto = bpy.data.objects.get(unido)
    if objeto is not None:
        bpy.data.objects.remove(objeto, do_unlink=True)
    for nombre in nombres:
        bpy.data.objects[nombre].hide_set(False)
