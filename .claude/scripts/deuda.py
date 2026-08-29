"""El censo de deuda: qué issues abiertos no son de ningún spec.

La deuda vive en GitHub Issues y los skills la abren solos. Lo que falta es la pregunta de
vuelta: **qué hay para promover.** El triage no se automatiza —cuál se promueve y en qué
orden es una decisión, y una máquina que la tome inventa prioridades— pero **mirarlo no puede
costar quince minutos o no se mira**.

## Qué se lista y qué no

Se listan los **abiertos** sin reclamar, ordenados del más viejo al más nuevo. Los cerrados
sin reclamar se cuentan pero no se listan: son los que se arreglaron por el carril
`fix/`/`chore/` sin spec, y no hay nada que promover en ellos — pero que el número aparezca
es lo que distingue «no hay» de «no se pidieron».

Uso:
    python .claude/scripts/deuda.py
"""

import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.gh import gh_json  # noqa: E402
from lib.repo import RAIZ, REPO  # noqa: E402
from lib.specs import LIMITE_DE_LISTA, deuda_del_censo, leer_mapa  # noqa: E402

MAPA_JSON = RAIZ / "specs" / "mapa.json"

UN_DIA = 24 * 60 * 60


def main() -> None:
    mapa = leer_mapa(MAPA_JSON.read_text(encoding="utf-8"))

    issues = gh_json(
        ["issue", "list", "--repo", REPO, "--state", "all", "--limit", str(LIMITE_DE_LISTA),
         "--json", "number,state,title,labels,createdAt"]
    )

    # Una lista truncada no distingue «este issue no existe» de «no entró en la página», y las
    # dos respuestas son opuestas. Es la misma guarda que el gate del mapa y el derivador, y
    # por eso el techo sale de la misma constante.
    if len(issues) >= LIMITE_DE_LISTA:
        print(
            f"\ngh devolvió {len(issues)} issues, o sea el límite: la lista puede estar cortada y "
            "el censo saldría corto sin decirlo. Subí `LIMITE_DE_LISTA` en "
            "`.claude/scripts/lib/specs.py`.\n",
            file=sys.stderr,
        )
        sys.exit(1)

    sin_reclamar = deuda_del_censo(issues, mapa)
    abiertos = sorted(
        (i for i in sin_reclamar if i["state"] == "OPEN"), key=lambda i: i["createdAt"]
    )
    cerrados = len(sin_reclamar) - len(abiertos)
    # Los que YA tienen dueño, contados por resta y no por `len(mapa)`: un spec reclama por su
    # `issue` y además por cada `origen`, así que contar filas del mapa deja afuera justo a los
    # issues de deuda que un spec tomó — el dato que este script existe para mostrar. Con la
    # resta las tres cifras cierran contra el total, y que cierren es lo que distingue «no hay»
    # de «no se contaron».
    reclamados = len(issues) - len(sin_reclamar)

    ahora = datetime.now(timezone.utc)
    for issue in abiertos:
        etiquetas = ", ".join(e["name"] for e in issue["labels"]) or "—"
        creado = datetime.fromisoformat(issue["createdAt"].replace("Z", "+00:00"))
        dias = (ahora - creado).total_seconds() / UN_DIA
        print(f"#{str(issue['number']):<5}{etiquetas:<14}{dias:>6.1f} d  {issue['title']}")

    print(f"\n{len(abiertos)} issues abiertos sin entrada en el mapa, de {len(issues)} en el repo.")
    print(
        f"{reclamados} ya tienen dueño —el issue de un spec, o el `origen` de uno— y {cerrados} "
        "cerrados sin reclamar no se listan."
    )
    # El triage NO se automatiza, y decirlo acá es parte del instrumento: un listado ordenado
    # por antigüedad se lee como una cola, y no lo es.
    print("El orden es por antigüedad y NO es una prioridad: cuál se promueve es una decisión.")


if __name__ == "__main__":
    main()
