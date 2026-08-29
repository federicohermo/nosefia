"""El gate de las copias: un skill trae su implementación, y las copias no se separan.

La regla de este repo es que **un skill es autocontenido**: trae adentro todo lo que necesita
para correr, y no alcanza `../otro-skill/` ni depende de `.claude/scripts/`. Es lo que dice la
doc oficial de Agent Skills —un skill es un directorio que **empaqueta** sus archivos de apoyo, y
el path del directorio se antepone al `SKILL.md` para leerlos **por nombre**— y es lo que lo
vuelve distribuible: un skill que alcanza afuera deja de funcionar apenas viaja sin su hermano.

El precio de esa regla es la duplicación, y **el precio se paga acá**. Sin este gate, dos copias
que se separan dan el peor modo de falla de este repo: un skill corriendo el método viejo, en
verde, sin que nadie lo note. Con él, editar una copia y no propagar **no se puede mergear**.

Cada entrada declara el canónico y sus copias. Agregar una copia sin agregarla acá es el agujero
obvio, así que el último test cierra ese: descubre las copias por nombre y exige que estén
declaradas.
"""

import unittest
from pathlib import Path

from lib.repo import RAIZ

SKILLS = RAIZ / ".claude" / "skills"

#: canónico → las copias que tienen que ser idénticas byte a byte.
#:
#: El canónico es el que se edita. Es el que vive donde algo de afuera de un skill lo puede
#: necesitar: la doctrina en `.claude/doctrina/`, el limpiador en `.claude/scripts/`. Los dos
#: archivos que sólo usan skills —`hallazgos.md`, `lote.py`— tienen su canónico adentro del skill
#: que los estrenó, que es tan arbitrario como cualquiera y por eso está escrito acá.
COPIAS: dict[Path, tuple[Path, ...]] = {
    RAIZ / ".claude" / "doctrina" / "sin-deuda.md": tuple(
        SKILLS / s / "sin-deuda.md"
        for s in (
            "pr-review",
            "pr-review-batch",
            "spec-create",
            "spec-create-batch",
            "spec-implement",
            "spec-implement-batch",
            "spec-review",
            "spec-review-batch",
        )
    ),
    SKILLS / "pr-review" / "hallazgos.md": (SKILLS / "pr-review-batch" / "hallazgos.md",),
    SKILLS
    / "pr-review"
    / "scripts"
    / "diff_pr.py": (SKILLS / "pr-review-batch" / "scripts" / "diff_pr.py",),
    SKILLS
    / "spec-review-batch"
    / "scripts"
    / "lote.py": (SKILLS / "spec-implement-batch" / "scripts" / "lote.py",),
    RAIZ / ".claude" / "scripts" / "limpiar_worktrees.py": (
        SKILLS / "pr-review-batch" / "scripts" / "limpiar_worktrees.py",
        SKILLS / "spec-implement-batch" / "scripts" / "limpiar_worktrees.py",
    ),
}


def _relativa(p: Path) -> str:
    return p.relative_to(RAIZ).as_posix()


class Copias(unittest.TestCase):
    def test_cada_copia_es_identica_a_su_canonico(self):
        for canonico, copias in COPIAS.items():
            self.assertTrue(canonico.is_file(), f"falta el canónico {_relativa(canonico)}")
            esperado = canonico.read_bytes()
            for copia in copias:
                self.assertTrue(
                    copia.is_file(),
                    f"falta la copia {_relativa(copia)}: el skill no trae su implementación. "
                    f"`cp {_relativa(canonico)} {_relativa(copia)}`",
                )
                self.assertEqual(
                    copia.read_bytes(),
                    esperado,
                    f"{_relativa(copia)} se separó de {_relativa(canonico)}. Se edita el "
                    f"canónico y se propaga: `cp {_relativa(canonico)} {_relativa(copia)}`",
                )

    def test_ningun_skill_alcanza_a_otro_skill(self):
        # El gate de la regla, y el que atrapa la recaída: un `../otro-skill/` adentro de un
        # SKILL.md vuelve al diseño que esto reemplaza. `../../../specs/` no cuenta —es el repo,
        # no otro skill— y por eso el patrón nombra el directorio de skills, no cualquier `../`.
        hermanos = [d.name for d in SKILLS.iterdir() if d.is_dir()]
        for md in SKILLS.rglob("*.md"):
            texto = md.read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                for hermano in hermanos:
                    if hermano == md.relative_to(SKILLS).parts[0]:
                        continue
                    self.assertNotIn(
                        f"../{hermano}/",
                        linea,
                        f"{_relativa(md)}:{numero} alcanza a otro skill. Un skill trae su "
                        "implementación adentro: copiala y declarala en COPIAS.",
                    )

    def test_toda_copia_en_disco_esta_declarada(self):
        # Sin esto, agregar un archivo a un skill sin declararlo lo deja fuera del gate y la
        # regla se afloja en silencio, que es exactamente lo que el gate existe para impedir.
        declaradas = {c for copias in COPIAS.values() for c in copias}
        canonicos = {c.name: c for c in COPIAS}
        for archivo in SKILLS.rglob("*"):
            if not archivo.is_file() or archivo.name not in canonicos:
                continue
            if archivo == canonicos[archivo.name] or archivo in declaradas:
                continue
            self.fail(
                f"{_relativa(archivo)} tiene el nombre de un archivo con canónico y no está en "
                "COPIAS: o se declara ahí, o no debería existir."
            )


if __name__ == "__main__":
    unittest.main()
