"""El gate de los specs de capacidad: forma, IDs y el ancla AC↔test.

    python .claude/scripts/gate_de_specs.py

Corre como el nodo `specs` de `verificar.py`. Verifica cuatro cosas, y ninguna de las cuatro
la puede ver una revisión sin abrir los nueve archivos a la vez:

1. **La forma.** Frontmatter con `capability_id` y `status` de un conjunto cerrado, y un
   archivo por capacidad con el nombre de su carpeta.
2. **Los IDs.** El código de tres letras es único en el repo, ningún ID está dos veces, y cada
   criterio nombra una regla **que existe** en su propio spec. Un `verifica BR-CHK-009` que no
   existe es una cita rota, y es lo que pasa cuando una regla se retira y el criterio se queda.
3. **Los archivos del régimen viejo.** `spec.md`, `research.md`, `plan.md` y `tasks.md` no se
   escriben más. El día que alguien copie uno de otro repo, el rojo dice por qué.
4. **El ancla AC↔test**, que es la única que muerde de verdad.

## Qué cobra el ancla, y qué sólo informa

Un spec `ratified` afirma que **todos** sus criterios tienen un test que los nombra. Eso es
rojo si falla. Un `draft` no afirma nada: el gate cuenta cuántos criterios no tiene nombrados
y lo imprime, para que el número no viva en la cabeza de nadie.

Es deliberado que el estado sea la frontera. La alternativa —cobrarle a todo spec escrito—
convierte escribir el contrato de una capacidad que todavía no existe en un rojo inmediato, y
lo que eso produce no es más tests: es que nadie escriba el spec.

**Verifica la cita, no que el test ejerza el criterio.** Es el mismo piso que todo lo que este
repo verifica sin cobertura, y decirlo es parte del gate.
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.repo import RAIZ, TESTS  # noqa: E402
from lib.specs import PROHIBIDOS, SPECS, ids_citados, specs_del_repo  # noqa: E402

#: Dónde se busca la cita de un criterio: las dos suites del repo.
ARBOLES_DE_TEST = (RAIZ / TESTS, RAIZ / ".claude" / "scripts" / "tests")


def _relativa(ruta: Path) -> str:
    try:
        return ruta.relative_to(RAIZ).as_posix()
    except ValueError:
        return ruta.as_posix()


def problemas_de_forma() -> list[str]:
    hallazgos: list[str] = []
    for prohibido in PROHIBIDOS:
        for archivo in SPECS.rglob(prohibido):
            hallazgos.append(
                f"{_relativa(archivo)}: el régimen viejo. El plan es el issue, y su forma es "
                "`specs/_template/task-brief.md`"
            )
    for carpeta in sorted(p for p in SPECS.glob("*") if p.is_dir()):
        if carpeta.name.startswith("_"):
            continue
        archivo = carpeta / f"{carpeta.name}.md"
        if not archivo.is_file():
            hallazgos.append(
                f"{_relativa(carpeta)}: una capacidad es `<nombre>/<nombre>.md`, y falta "
                f"`{carpeta.name}.md`"
            )
    return hallazgos


def problemas_de_los_ids(specs: list) -> list[str]:
    hallazgos: list[str] = []
    codigos: dict[str, str] = {}
    for spec in specs:
        hallazgos.extend(spec.problemas)
        if spec.codigo:
            if spec.codigo in codigos:
                hallazgos.append(
                    f"{_relativa(spec.ruta)}: el código `{spec.codigo}` ya es de "
                    f"`{codigos[spec.codigo]}`. Un código identifica a una sola capacidad"
                )
            else:
                codigos[spec.codigo] = spec.nombre
        if not spec.criterios:
            hallazgos.append(f"{_relativa(spec.ruta)}: no declara un solo criterio")
        for criterio, reglas in spec.criterios.items():
            if not reglas:
                hallazgos.append(
                    f"{_relativa(spec.ruta)}: `{criterio}` no nombra qué regla verifica"
                )
            for regla in reglas:
                if regla not in spec.reglas:
                    hallazgos.append(
                        f"{_relativa(spec.ruta)}: `{criterio}` verifica `{regla}`, que este "
                        "spec no declara"
                    )
    return hallazgos


def problemas_del_ancla(specs: list, citados: set[str]) -> tuple[list[str], list[str]]:
    """Los rojos de los `ratified`, y el informe de los `draft`."""
    hallazgos: list[str] = []
    informe: list[str] = []
    for spec in specs:
        sin_test = [c for c in spec.criterios if c not in citados]
        if spec.estado == "ratified" and sin_test:
            hallazgos.append(
                f"{_relativa(spec.ruta)}: está `ratified` y ningún test nombra "
                f"{', '.join(sorted(sin_test))}. O el test lo cita, o el spec vuelve a `draft`"
            )
        if spec.estado == "draft":
            cubiertos = len(spec.criterios) - len(sin_test)
            informe.append(
                f"  {spec.nombre}: {cubiertos}/{len(spec.criterios)} criterios con test"
                + (" — ratificable" if not sin_test else "")
            )
    return hallazgos, informe


def main() -> int:
    if not SPECS.is_dir():
        print("OK — no hay `specs/` todavía: nada que verificar.")
        return 0
    specs = specs_del_repo()
    citados = ids_citados(ARBOLES_DE_TEST)
    hallazgos = problemas_de_forma() + problemas_de_los_ids(specs)
    del_ancla, informe = problemas_del_ancla(specs, citados)
    hallazgos += del_ancla

    if hallazgos:
        for hallazgo in hallazgos:
            print(f"- {hallazgo}")
        return 1

    ratificados = sum(1 for s in specs if s.estado == "ratified")
    criterios = sum(len(s.criterios) for s in specs)
    print(f"OK — {len(specs)} capacidades, {criterios} criterios, {ratificados} ratificadas.")
    if informe:
        print("Borradores, y cuánto les falta para ratificar:")
        print("\n".join(informe))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
