"""Dónde está Blender, y qué decir cuando no está.

Mismo diseño que `godot.py`, y por el mismo motivo: el entorno se **inyecta** en vez de leerse,
así que se puede probar «no está declarada» en una máquina que sí la tiene.

**La versión importa y no es un detalle.** El par `.blend` ↔ `.glb` se midió con Blender 5.2.1:
dos versiones del exportador devuelven datos de vértice distintos para la misma malla, así que
exportar con otra deja un diff binario enorme que no corresponde a ningún cambio del modelo.
"""

import os
from collections.abc import Callable

#: La variable donde vive la ruta, cuando el ejecutable no está en el PATH.
VARIABLE = "BLENDER_BIN"

#: La serie con la que se midió el par. Ver el encabezado.
SERIE = "5.2"

#: Dónde lo deja el instalador de Windows. Se prueban en orden y gana la primera que existe.
UBICACIONES_WINDOWS = (
    rf"C:\Program Files\Blender Foundation\Blender {SERIE}\blender.exe",
    rf"C:\Program Files\Blender Foundation\Blender {SERIE}\blender-launcher.exe",
)


def resolver(
    entorno: dict[str, str],
    existe: Callable[[str], bool] = os.path.isfile,
    ubicaciones: tuple[str, ...] = UBICACIONES_WINDOWS,
) -> tuple[str | None, str | None]:
    """El ejecutable y de dónde salió, o `(None, None)`.

    El orden es deliberado: **la variable gana**. Quien la declaró eligió una versión, y que el
    instalador haya dejado otra en su lugar de siempre no puede pisar esa elección.
    """
    declarado = entorno.get(VARIABLE, "").strip().strip('"')
    if declarado and existe(declarado):
        return declarado, VARIABLE
    for ruta in ubicaciones:
        if existe(ruta):
            return ruta, "instalación"
    return None, None


def como_declararlo(entorno: dict[str, str]) -> str:
    """El mensaje de un Blender que no se encontró, con la salida escrita.

    Bloquear sin decir cómo salir produce el reflejo de saltear el bloqueo.
    """
    declarado = entorno.get(VARIABLE, "").strip().strip('"')
    if declarado:
        return (
            f"`{VARIABLE}` está declarada y apunta a un archivo que no existe:\n  {declarado}\n"
            "Corregila, o borrala para que se busque en la instalación."
        )
    return (
        f"No se encontró Blender {SERIE}. Declaralo una vez en `{VARIABLE}`:\n\n"
        f'  setx {VARIABLE} "C:\\Program Files\\Blender Foundation\\Blender {SERIE}\\blender.exe"\n\n'
        "Y abrí una terminal nueva: un proceso hereda el entorno de su padre y no lo relee."
    )

#: El modificador que se apaga al exportar. Es un **nombre**, no un tipo: son Geometry Nodes
#: llamados así, y apagar por tipo `ARRAY` no apaga ninguno.
MODIFICADOR = "Array"


def es_un_array(nombre: str) -> bool:
    """Si un modificador es uno de los que llenan el estante, y por lo tanto hay que apagarlo.

    **Cuenta el sufijo de Blender.** Al duplicar un objeto, Blender numera el modificador
    copiado: `Array.001`, `Array.002`. Comparar el nombre exacto contra `Array` deja pasar todos
    los duplicados, y el producto sale multiplicado igual — que es justo la falla que apagar por
    nombre venía a evitar.

    Medido el 2026-09-18 sobre el `.blend` del almacén: **36 `Array` y 34 `Array.001`**. Con la
    comparación exacta, 34 productos salían al doble o al cuádruple de vértices, y el `.glb`
    dejaba de corresponder a su fuente sin que el comando de exportar dijera nada.
    """
    return nombre == MODIFICADOR or nombre.startswith(MODIFICADOR + ".")
