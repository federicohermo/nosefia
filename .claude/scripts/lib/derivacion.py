"""Lo que decide `derivar_mapa.py`, separado de con quién habla.

`specs.py` tiene la derivación **pura** —`derivar_mapa`, `escribir_mapa`— y declara en su
encabezado que no toca el disco ni la red. Lo que falta para que eso sea una herramienta es
el otro tramo: pedirle las listas a `gh`, decidir si la respuesta sirve, escribir o no
escribir, y con qué código salir. Ese tramo tiene reglas propias y **son las que hay que
poder probar**, así que el entorno se inyecta — igual que en `gh.py` y en
`rutas_protegidas.py`, y por el mismo motivo: el modo de falla que importa —una lista
truncada, un mapa que ya está bien— no se puede fabricar contra el repo real.

## Las cuatro salidas, y por qué la tercera no escribe

| Situación                             | Qué hace                          | Exit |
|---------------------------------------|-----------------------------------|------|
| no hay correcciones                   | no toca el archivo, lo dice       | 0    |
| hay correcciones                      | reescribe e imprime cada una      | 0    |
| la lista de `gh` llegó al límite      | **no toca el archivo**, dice por qué | 1 |
| `--verificar` y hay correcciones      | no toca el archivo, las imprime   | 1    |

La guarda de truncado es la misma que tiene el gate del mapa, y el argumento también: en una
lista que llegó al límite, «este spec no tiene PR» y «su PR no entró en la página» **no se
distinguen**, y son respuestas opuestas. Derivar sobre eso pondría en `Propuesto` a todo spec
cuyo PR quedó afuera — o sea que el derivador, que existe para arreglar el registro, sería el
único capaz de romperlo entero de una vez. Ante la duda no escribe.
"""

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from .specs import agrupar_prs_por_spec, derivar_mapa, escribir_mapa, leer_mapa


@dataclass
class EntornoDerivacion:
    """Lo que el derivador necesita del mundo.

    Las dos consultas son funciones y no datos para que no se hagan cuando no hacen falta, y
    sobre todo para que un test declare exactamente qué contestó cada una.
    """

    #: Los issues del repo, ya parseados.
    issues: Callable[[], list[dict[str, Any]]]
    #: Los PR del repo, ya parseados.
    prs: Callable[[], list[dict[str, Any]]]
    #: El texto crudo de `specs/mapa.json`.
    leer_texto: Callable[[], str]
    #: Escribir el mapa nuevo. No se llama si no hay nada que cambiar.
    guardar: Callable[[str], None]
    #: Una línea del reporte.
    informar: Callable[[str], None]
    #: El techo que se le pidió a `gh`. Una lista que lo **alcanza** está truncada: `gh`
    #: pagina hasta el límite y no avisa que cortó.
    limite: int
    #: `--verificar`: no escribe nunca, pero sale 1 si hubiera escrito.
    verificar: bool


def derivar_y_guardar(entorno: EntornoDerivacion) -> int:
    """El código de salida del proceso. Ver la tabla del encabezado."""
    issues = entorno.issues()
    prs = entorno.prs()

    # Las dos listas se miran juntas y antes de derivar nada: alcanza con que una esté
    # truncada para que el resultado no sea confiable, y no hay media derivación.
    truncadas = [
        f"issues ({len(issues)})" if len(issues) >= entorno.limite else None,
        f"PR ({len(prs)})" if len(prs) >= entorno.limite else None,
    ]
    truncadas = [t for t in truncadas if t is not None]

    if truncadas:
        entorno.informar(
            f"la lista de {' y de '.join(truncadas)} llegó al límite de {entorno.limite}, así que "
            "está truncada.\nNo se escribe nada: en una lista cortada, «este spec no tiene PR» y "
            "«su PR no entró\nen la página» no se distinguen. Subir el límite y volver a correr."
        )
        return 1

    mapa = leer_mapa(entorno.leer_texto())
    derivado, correcciones = derivar_mapa(
        mapa,
        {i["number"]: i for i in issues},
        agrupar_prs_por_spec(prs),
    )

    if not correcciones:
        entorno.informar(
            f"el mapa ya dice lo que los {len(prs)} PR y los {len(issues)} issues dicen: "
            f"{len(mapa)} specs, sin cambios."
        )
        return 0

    for id_spec, campo, de, a in correcciones:
        entorno.informar(f'{id_spec}  {campo}: "{de}" → "{a}"')

    if entorno.verificar:
        entorno.informar(f"\n{len(correcciones)} correcciones sin aplicar (--verificar).")
        return 1

    entorno.guardar(escribir_mapa(derivado))
    entorno.informar(f"\n{len(correcciones)} correcciones escritas en specs/mapa.json.")
    return 0
