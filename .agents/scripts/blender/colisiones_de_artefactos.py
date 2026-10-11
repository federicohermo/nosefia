"""Ajusta los tres volúmenes de cada inodoro a las piezas del modelo exportado.

El tanque admite apoyar objetos: un único casco convexo con la tapa levantada dejaría
una superficie invisible por encima del tanque. Los dos inodoros usan los mismos volúmenes.

    blender -b --python .claude/scripts/blender/colisiones_de_artefactos.py
"""

import re
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.consola import configurar  # noqa: E402
from lib.artefactos_del_bano import (  # noqa: E402
    area_firmada, componentes, corte_horizontal, volumen_por_altura,
)

configurar()


def casco(puntos):
    bm = bmesh.new()
    vertices = [bm.verts.new(punto) for punto in puntos]
    resultado = bmesh.ops.convex_hull(bm, input=vertices)
    caras = [cara for cara in resultado["geom"] if isinstance(cara, bmesh.types.BMFace)]
    usados = {v for cara in caras for v in cara.verts}
    puntos = sorted(tuple(v.co) for v in usados)
    bm.free()
    return puntos


def main():
    raiz = Path(__file__).resolve().parents[3]
    bpy.ops.wm.open_mainfile(
        filepath=str(raiz / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"), load_ui=False
    )
    objeto = bpy.data.objects["inodoro-convcol"]
    volumenes = {90: [], 91: [], 92: []}
    aristas = [tuple(arista.vertices) for arista in objeto.data.edges]
    for indices in componentes(len(objeto.data.vertices), aristas):
        puntos = [objeto.data.vertices[i].co for i in indices]
        alturas = [(objeto.matrix_world @ p).z for p in puntos]
        numero = volumen_por_altura(alturas)
        if numero is None:
            continue
        # El exportador cambia el eje vertical, también en el espacio local de la malla.
        volumenes[numero].extend(Vector((p.x, p.z, -p.y)) for p in puntos)
    ruta = raiz / "src/escenas/puestos/estructura_del_almacen.tscn"
    texto = ruta.read_text(encoding="utf-8")
    for numero, puntos in volumenes.items():
        assert puntos, numero
        valor = ", ".join(f"{c:.6f}" for p in casco(puntos) for c in p)
        patron = (
            rf'(\[sub_resource type="ConvexPolygonShape3D" id="volumen_{numero}"\]\n)'
            r"points = [^\n]+"
        )
        texto, cantidad = re.subn(
            patron, lambda m: m[1] + f"points = PackedVector3Array({valor})", texto
        )
        assert cantidad == 1, numero
    padre = "bano_inodoro_2/StaticBody3D"
    if f'parent="{padre}"' not in texto:
        texto += f'\n[node name="CollisionShape3D" parent="{padre}"]\ndisabled = true\n'
        for nombre, numero in (("Volumen", 90), ("Volumen2", 91), ("Volumen3", 92)):
            texto += (
                f'\n[node name="{nombre}" type="CollisionShape3D" parent="{padre}"]\n'
                f'shape = SubResource("volumen_{numero}")\n'
            )
    ruta.write_text(texto, encoding="utf-8", newline="\n")
    print("Colisiones actualizadas: cuerpo, tapa y tanque de ambos inodoros.")

    ruta_agua = raiz / "src/escenas/puestos/agua_del_bano.tscn"
    texto = ruta_agua.read_text(encoding="utf-8")
    # Ambiente conserva un desplazamiento del escenario original. Las superficies se
    # calculan en coordenadas mundiales de Blender, igual que los artefactos de Estructura.
    almacen = (raiz / "src/escenas/almacen.tscn").read_text(encoding="utf-8")
    ambiente = re.search(
        r'\[node name="Ambiente"[^\]]*\]\ntransform = Transform3D\(([^)]+)\)', almacen
    )
    assert ambiente is not None
    desplazamiento = [float(v) for v in ambiente[1].split(",")]
    assert desplazamiento[:9] == [1, 0, 0, 0, 1, 0, 0, 0, 1]
    posicion = ", ".join(f"{-v:.9f}" for v in desplazamiento[9:])
    patron = r'(\[node name="AguaDelBano"[^\]]*\]\n)(?:position = [^\n]+\n)?'
    texto, cantidad = re.subn(
        patron, lambda m: m[1] + f"position = Vector3({posicion})\n", texto
    )
    assert cantidad == 1
    transformacion = re.search(
        r'\[node name="Lavatorio"[^\]]*\]\ntransform = Transform3D\(([^)]+)\)', texto
    )
    assert transformacion is not None
    valores = [float(v) for v in transformacion[1].split(",")]
    matriz = Matrix([
        [valores[0], valores[1], valores[2], valores[9]],
        [valores[3], valores[4], valores[5], valores[10]],
        [valores[6], valores[7], valores[8], valores[11]],
        [0, 0, 0, 1],
    ])
    lavatorio = bpy.data.objects["vanitory-convcol"]
    vertices = [tuple(lavatorio.matrix_world @ v.co) for v in lavatorio.data.vertices]
    caras = [tuple(cara.vertices) for cara in lavatorio.data.polygons]
    anillos = corte_horizontal(vertices, caras, valores[10])
    assert len(anillos) == 2, len(anillos)
    interior = min(anillos, key=lambda a: abs(area_firmada(a)))
    centro = sum((Vector(p) for p in interior), Vector((0, 0))) / len(interior)
    contorno = []
    for punto in interior:
        # Un solape de 1-2 mm dentro de la pared oculta la costura del agua transparente.
        x, y = centro + (Vector(punto) - centro) * 1.006
        local = matriz.inverted() @ Vector((x, valores[10], -y))
        contorno.append((local.x, local.z))
    if area_firmada(contorno) > 0:
        contorno.reverse()
    valor = ", ".join(f"{c:.6f}" for punto in contorno for c in punto)
    texto, cantidad = re.subn(
        r"contorno_del_lavatorio = [^\n]+",
        lambda m: f"contorno_del_lavatorio = PackedVector2Array({valor})", texto,
    )
    assert cantidad == 1
    ruta_agua.write_text(texto, encoding="utf-8", newline="\n")
    print(f"Agua del lavatorio ajustada a la cubeta: {len(contorno)} puntos.")


if __name__ == "__main__":
    main()
