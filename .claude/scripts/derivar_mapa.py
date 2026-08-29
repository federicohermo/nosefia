"""Deriva `specs/mapa.json` desde los PR y los issues, en vez de recordarlo.

**El estado de un spec no es un dato que alguien escribe: es una consecuencia.** Su PR
aterrizó o no, y eso no lo escribe nadie a mano.

Que sea una consecuencia y no una tarea importa porque el gate del mapa tiene dos tests que
se miran en espejo —un PR aterrizado con el mapa en `Propuesto` es mentira, y un
`Implementado` sin PR aterrizado es la mentira al revés— y juntos **prohíben actualizar el
mapa adentro del PR que lo justifica**: mientras ese PR está abierto el mapa tiene que decir
`Propuesto`, y en cuanto se mergea tiene que decir otra cosa. No hay ningún commit del propio
PR que deje las dos cosas ciertas, así que el paso quedaría para un commit posterior escrito
a mano — que es exactamente el que se olvida. En el repo del que sale este harness eso pasó
cinco veces seguidas.

De ahí que esto exista y que lo corra una Action en el push a `staging`
(`.github/workflows/mapa.yml`). El gate queda como confirmación de un cálculo, no como
recordatorio de una tarea.

## Lo que NO hace

**No cierra issues.** El `Closes #N` del cuerpo del PR ya los cierra solo, en el segundo
siguiente al merge. Por eso el workflow no pide `issues: write`.

Y si un issue igual queda abierto —un PR sin `Closes #N`—, este script pone `Implementado` y
**el gate se pone en rojo**, que es lo correcto: ahí hay una pregunta real —¿ese PR
implementó el spec?— que ninguna máquina puede contestar.

Uso:
    python .claude/scripts/derivar_mapa.py              # deriva y escribe si cambia algo
    python .claude/scripts/derivar_mapa.py --verificar  # no escribe; sale 1 si escribiría
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.derivacion import EntornoDerivacion, derivar_y_guardar  # noqa: E402
from lib.gh import gh_json  # noqa: E402
from lib.repo import RAIZ, REPO  # noqa: E402
from lib.specs import LIMITE_DE_LISTA  # noqa: E402

MAPA_JSON = RAIZ / "specs" / "mapa.json"


def main() -> None:
    verificar = "--verificar" in sys.argv

    codigo = derivar_y_guardar(
        EntornoDerivacion(
            issues=lambda: gh_json(
                ["issue", "list", "--repo", REPO, "--state", "all",
                 "--limit", str(LIMITE_DE_LISTA), "--json", "number,state,title"]
            ),
            prs=lambda: gh_json(
                ["pr", "list", "--repo", REPO, "--state", "all",
                 "--limit", str(LIMITE_DE_LISTA), "--json", "number,headRefName,state"]
            ),
            leer_texto=lambda: MAPA_JSON.read_text(encoding="utf-8"),
            guardar=lambda texto: MAPA_JSON.write_text(texto, encoding="utf-8"),
            informar=print,
            # El techo lo comparte con el gate del mapa, que es quien confirma lo que este
            # script escribe.
            limite=LIMITE_DE_LISTA,
            verificar=verificar,
        )
    )
    sys.exit(codigo)


if __name__ == "__main__":
    main()
