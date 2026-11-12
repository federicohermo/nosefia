"""Qué mallas del modelo se pueden unir al exportar, y con cuáles.

Compatibility dibuja una vez por superficie de cada instancia. Dos mallas fijas con el mismo
material cuestan dos dibujos y, unidas, uno. **Lo que decide qué se une vive acá** y no en
`blender/unir_mallas_para_exportar.py`: ese archivo importa `bpy` y ningún test lo puede ejercer.

## Qué se queda afuera

- **Lo que el juego nombra.** Una malla que `src/` cita por su nombre —un override de la escena,
  un `get_node`, un grupo— se busca por ese nombre: unida, el nombre desaparece y el juego
  encuentra `null` sin un solo error de carga. Cuenta también el nombre que Godot le deja al
  nodo, que cambia `.` por `_`.
- **Lo que se mueve o cambia de luz.** Puertas, hojas, tapas y vidrios, y lo que
  `importar_modelo.gd` pasa a luz dinámica por su prefijo.
- **Lo que Godot interpreta por su sufijo**: `-col`, `-convcol`, `-colonly`, `-noimp`. Unida, la
  colisión se pierde o se multiplica.
- **Lo que cuelga de algo que se queda afuera.** Una manija sigue a su puerta.
- **Los productos.** El juego los dibuja con un `MultiMesh` desde una sola unidad.

## Y no se une a través de ambientes

Godot recorta por instancia: una malla unida se dibuja entera si se ve un pedazo. El local, el
depósito, el baño y el cuartito van separados, para que cada uno se descarte con su ambiente.
"""

import re
from dataclasses import dataclass

#: Los sufijos con los que el importador de Godot cambia lo que hace con un nodo.
SUFIJOS_DEL_IMPORTADOR = ("-col", "-convcol", "-colonly", "-convcolonly", "-noimp", "-occ")

#: Los prefijos que `assets/models/importar_modelo.gd` pasa a luz dinámica. Si cambian allá,
#: cambian acá: `test_union_de_mallas.py` compara las dos listas.
PREFIJOS_DE_LUZ_DINAMICA = (
    "puerta_heladera_",
    "exhibido_",
    "salon_silla",
    "estanteria_precios",
    "board",
)

#: Los prefijos que `importar_modelo.gd` trata aparte, con su propio material: unidos lo perderían.
PREFIJOS_CON_ALCANCE = ("deposito_esquinas_",)

#: Lo que se mueve o se ve a través: un nombre de material o de objeto que lo contiene.
CONTIENE_MOVIL = ("puerta", "hoja", "tapa", "vidrio", "ventana", "vidriera", "manija", "persiana")

#: Los materiales que el importador trata aparte: no se unen con otros.
MATERIALES_APARTE = ("TOPE | Publicidad", "local_vidrio")

#: Los ambientes, en el orden en que se prueban. Lo que no cae en ninguno es `fuera`.
AMBIENTES = ("local", "deposito", "bano", "cuartito")
FUERA = "fuera"

_CADENA = re.compile(r'"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\'')
_DOLAR = re.compile(r"\$%?([\w/]+)")
_AABB = re.compile(r"AABB\(([^)]*)\)")


def nombre_de_godot(nombre: str) -> str:
    """El nombre que Godot le pone al nodo que importa de un objeto de Blender."""
    return re.sub(r"[.:@/\"%]", "_", nombre)


def nombres_citados(textos: list[str]) -> set[str]:
    """Todo nombre que `textos` apunta como destino: una cadena entera entre comillas, o el
    último tramo de un camino `a/b/c`, entre comillas o tras un `$`.

    **Los tramos de paso no cuentan.** En `parent="deposito_techo_industrial/deposito_techo_chapa"`
    el destino es la chapa, que lleva un cuerpo de colisión colgado; el contenedor sólo se
    atraviesa, y una malla suya que se une no deja nada sin camino.

    Es conservador a propósito: un nombre corto que coincide por casualidad deja una malla
    afuera de la unión, que cuesta un dibujo. Perder un nombre rompe el juego.
    """
    citados: set[str] = set()
    for texto in textos:
        for par in _CADENA.finditer(texto):
            cadena = par.group(1) or par.group(2) or ""
            citados.add(cadena)
            ultimo = cadena.rsplit("/", 1)[-1]
            if ultimo:
                citados.add(ultimo)
        for dolar in _DOLAR.finditer(texto):
            citados.add(dolar.group(1).rsplit("/", 1)[-1])
    return citados


def esta_citado(nombre: str, citados: set[str]) -> bool:
    return nombre in citados or nombre_de_godot(nombre) in citados


def es_fijo(nombre: str) -> bool:
    """Si el nombre de un objeto no lo marca como algo que se mueve o que Godot interpreta."""
    minuscula = nombre.lower()
    if minuscula.endswith(SUFIJOS_DEL_IMPORTADOR) or any(
        sufijo + "." in minuscula for sufijo in SUFIJOS_DEL_IMPORTADOR
    ):
        return False
    if minuscula.startswith(PREFIJOS_DE_LUZ_DINAMICA + PREFIJOS_CON_ALCANCE):
        return False
    return not any(palabra in minuscula for palabra in CONTIENE_MOVIL)


def material_es_fijo(nombre: str) -> bool:
    minuscula = nombre.lower()
    return nombre not in MATERIALES_APARTE and not any(
        palabra in minuscula for palabra in ("vidrio", "cristal")
    )


Caja = tuple[float, float, float, float, float, float]


def leer_ambientes(texto_de_escena: str) -> dict[str, list[Caja]]:
    """Las cajas de cada ambiente, tal como las declara la escena de la estructura.

    Devuelven `(x, y, z, ancho, alto, largo)` en el espacio del modelo. Falla si falta alguna:
    una unión que clasifica con cajas viejas une a través de ambientes sin avisar.
    """
    cajas: dict[str, list[Caja]] = {}
    for ambiente in AMBIENTES:
        linea = re.search(rf"^{ambiente} = Array\[AABB\]\((.*)\)$", texto_de_escena, re.M)
        if linea is None:
            raise ValueError(f"la escena no declara las cajas de `{ambiente}`")
        cajas[ambiente] = [
            tuple(float(valor) for valor in caja.group(1).split(","))  # type: ignore[misc]
            for caja in _AABB.finditer(linea.group(1))
        ]
    return cajas


def ambiente_de(punto: tuple[float, float, float], cajas: dict[str, list[Caja]]) -> str:
    """El ambiente que contiene a `punto` (espacio de Godot), o `fuera`."""
    x, y, z = punto
    for ambiente in AMBIENTES:
        for cx, cy, cz, ancho, alto, largo in cajas[ambiente]:
            if cx <= x <= cx + ancho and cy <= y <= cy + alto and cz <= z <= cz + largo:
                return ambiente
    return FUERA


def de_blender_a_godot(punto: tuple[float, float, float]) -> tuple[float, float, float]:
    """Blender es Z arriba; glTF y Godot, Y arriba con el eje de profundidad invertido."""
    x, y, z = punto
    return (x, z, -y)


@dataclass(frozen=True)
class Candidata:
    """Un objeto que podría unirse: lo que hace falta saber de él para decidirlo."""

    nombre: str
    centro: tuple[float, float, float]
    material: str
    ancestros: tuple[str, ...] = ()
    #: Las capas de UV y de color que lleva. Unir dos con capas distintas rellena de ceros las
    #: que le faltan a una, y un segundo juego de UV en cero hornea toda la pieza en un punto.
    capas: str = ""


def agrupar(
    candidatas: list[Candidata],
    citados: set[str],
    cajas: dict[str, list[Caja]],
    minimo: int = 2,
) -> dict[tuple[str, str, str], list[str]]:
    """Qué objetos se unen: `(ambiente, material, capas)` → nombres, con al menos `minimo`.

    Una candidata queda afuera si ella o cualquiera de sus ancestros está citada o no es fija.
    """
    grupos: dict[tuple[str, str, str], list[str]] = {}
    for candidata in candidatas:
        cadena = (candidata.nombre, *candidata.ancestros)
        if any(esta_citado(nombre, citados) or not es_fijo(nombre) for nombre in cadena):
            continue
        if not material_es_fijo(candidata.material):
            continue
        ambiente = ambiente_de(de_blender_a_godot(candidata.centro), cajas)
        grupos.setdefault((ambiente, candidata.material, candidata.capas), []).append(
            candidata.nombre
        )
    return {clave: nombres for clave, nombres in grupos.items() if len(nombres) >= minimo}


def nombre_de_la_union(ambiente: str, material: str) -> str:
    """El nombre del objeto unido: legible, y sin nada que el importador interprete."""
    limpio = re.sub(r"[^0-9A-Za-z_]+", "_", f"{ambiente}_{material}").strip("_")
    return f"unido_{limpio}"
