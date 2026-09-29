"""Lee la góndola del `.blend` y escribe dónde va cada unidad. Corre adentro de Blender.

    blender <fuente>.blend --background --python .claude/scripts/blender/disponer.py

**No cambia el `.blend`.** Escribe tres archivos y reescribe un bloque de un cuarto, y sobre el
`.blend` commiteado los deja sin un byte de diferencia: es la prueba de que la disposición del
repo salió de ese `.blend`.

- `disposicion_de_la_gondola.tres`: una tanda por producto, en el orden de `Producto.Id`, con la
  fila de atrás primero y la de adelante al final; las tandas fijas; y cuántas copias forman la
  fila de adelante de cada producto.
- `contenido_del_estante.tscn`: la unidad de cada producto, con la vuelta que le da el modelo.
- `guia_del_estante.tscn`: una malla por tanda fija, con la vuelta de la unidad de su producto.
- `estructura_del_almacen.tscn`, sólo las unidades apagadas: el `.glb` trae la unidad de cada
  producto y la escena la apaga, porque la dibuja su tanda. Cuelga del mueble de su tanda, y si
  la tanda cambia de mueble cambia su ruta.

Cada unidad y cada copia llegan rotuladas por `acomodar.py`: de qué tanda son, en qué fila y en
qué orden. Lo que no tiene rótulo no es de la góndola.
"""

import re
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.gondola import (  # noqa: E402
    SUFIJOS_DE_IMPORTACION,
    NodoDeMalla,
    apagar_las_unidades,
    base_en_godot,
    copia_relativa,
    escribir_disposicion,
    escribir_escena_de_mallas,
    flotantes_de_la_copia,
    nombre_en_godot,
    punto_en_godot,
    ruta_de_la_malla,
)
from lib.reparto import PRODUCTOS  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
PUESTOS = RAIZ / "src" / "escenas" / "puestos"
DISPOSICION = PUESTOS / "disposicion_de_la_gondola.tres"
CONTENIDO = PUESTOS / "contenido_del_estante.tscn"
GUIA = PUESTOS / "guia_del_estante.tscn"
ESTRUCTURA = PUESTOS / "estructura_del_almacen.tscn"


def en_godot(objeto):
    """La base y el origen de un objeto del `.blend`, como los importa Godot."""
    mundo = objeto.matrix_world
    base = tuple(tuple(mundo[i][j] for j in range(3)) for i in range(3))
    origen = (mundo[0][3], mundo[1][3], mundo[2][3])
    return base_en_godot(base), punto_en_godot(origen)


def tandas_del_blend():
    """Las copias rotuladas, por tanda y en su orden."""
    tandas = {}
    for objeto in bpy.data.objects:
        if "tanda" not in objeto:
            continue
        tandas.setdefault(str(objeto["tanda"]), []).append(objeto)
    for copias in tandas.values():
        copias.sort(key=lambda o: int(o["orden"]))
    return tandas


def ruta_en_godot(objeto):
    """La ruta del nodo de un objeto adentro del modelo importado, del mueble a la unidad."""
    nombres = []
    while objeto is not None:
        nombres.append(nombre_en_godot(objeto.name))
        objeto = objeto.parent
    return "/".join(reversed(nombres))


def uids(texto):
    """Los `uid` del recurso y de su script, que se conservan: otras escenas lo nombran por uid."""
    propio = re.search(r'\[gd_resource [^\]]*uid="([^"]+)"', texto)
    script = re.search(r'\[ext_resource type="Script" uid="([^"]+)"', texto)
    if propio is None or script is None:
        raise SystemExit(f"{DISPOSICION.name} no trae sus uid: no se reescribe")
    return propio.group(1), script.group(1)


def bloque(copias, base_del_modelo):
    flotantes = []
    for copia in copias:
        base, origen = en_godot(copia)
        flotantes += flotantes_de_la_copia(copia_relativa(base, base_del_modelo), origen)
    return flotantes


def principal():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    tandas = tandas_del_blend()
    por_producto = {p.clave: [] for p in PRODUCTOS}
    fijas = []
    for clave, copias in sorted(tandas.items()):
        producto = str(copias[0]["producto"])
        if bool(copias[0]["fija"]):
            fijas.append((clave, producto, copias))
        else:
            por_producto[producto].append((clave, copias))
    principales = []
    filas_de_adelante = []
    contenido = []
    apagadas = []
    bases = {}
    for p in PRODUCTOS:
        if len(por_producto[p.clave]) != 1:
            raise SystemExit(f"{p.nombre} tiene {len(por_producto[p.clave])} tandas con casilleros")
        _, copias = por_producto[p.clave][0]
        unidad = bpy.data.objects[p.objeto]
        if copias[0] != unidad:
            raise SystemExit(f"la tanda de {p.nombre} no arranca en su unidad")
        if not any(sufijo in unidad.name for sufijo in SUFIJOS_DE_IMPORTACION):
            raise SystemExit(f"{unidad.name} no tiene colisión: la escena no sabe qué apagar")
        apagadas.append(ruta_en_godot(unidad))
        base, origen = en_godot(unidad)
        bases[p.clave] = base
        principales.append(bloque(copias, base))
        filas_de_adelante.append(sum(1 for c in copias if str(c["fila"]) == "adelante"))
        contenido.append(NodoDeMalla(p.nombre, ruta_de_la_malla(p.nombre), base, origen))
    guias = []
    nodos_de_guia = []
    nombres = {p.clave: p.nombre for p in PRODUCTOS}
    for numero, (_, producto, copias) in enumerate(fijas):
        base = bases[producto]
        guias.append(bloque(copias, base))
        _, origen = en_godot(copias[0])
        nodos_de_guia.append(
            NodoDeMalla(f"Guia{numero:02d}", ruta_de_la_malla(nombres[producto]), base, origen)
        )
    propio, script = uids(DISPOSICION.read_text(encoding="utf-8"))
    escribir(
        DISPOSICION, escribir_disposicion(principales, guias, filas_de_adelante, propio, script)
    )
    escribir(CONTENIDO, escribir_escena_de_mallas("Contenido", contenido))
    escribir(GUIA, escribir_escena_de_mallas("Guia", nodos_de_guia))
    escribir(ESTRUCTURA, apagar_las_unidades(ESTRUCTURA.read_text(encoding="utf-8"), apagadas))
    unidades = sum(len(c) for c in tandas.values())
    print(
        f"tandas con casilleros: {len(principales)}, fijas: {len(guias)}, unidades: {unidades}"
    )


def escribir(ruta, texto):
    ruta.write_text(texto, encoding="utf-8", newline="\n")
    print(f"escrito: {ruta.relative_to(RAIZ)}")


if __name__ == "__main__":
    principal()
