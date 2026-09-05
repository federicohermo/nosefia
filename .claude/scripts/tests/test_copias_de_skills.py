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
#: El canónico es el que se edita, y **vive adentro de un skill salvo que algo de afuera lo
#: necesite**. El único que califica hoy es el limpiador de worktrees, que está en
#: `.claude/scripts/` porque se corre a mano. El resto —`sin-deuda.md`, `hallazgos.md`,
#: `diff_pr.py`, `lote.py`— tiene su canónico en el skill que lo estrenó.
#:
#: **`sin-deuda.md` estaba en `.claude/doctrina/` y se movió acá**: esa carpeta no la cargaba
#: nada. No es un directorio que Claude Code conozca —lo son `skills/`, `rules/`, `commands/`,
#: `agents/`—, así que la copia canónica no entraba a ningún contexto por sí sola y su única
#: función era ser la referencia de este gate. Un directorio entero para eso es una tercera
#: convención que hay que aprender, y la elección del skill dueño es tan arbitraria como en los
#: otros tres casos: por eso está escrita acá y no en el nombre de una carpeta.
COPIAS: dict[Path, tuple[Path, ...]] = {
    SKILLS / "spec-create" / "sin-deuda.md": tuple(
        SKILLS / s / "sin-deuda.md"
        for s in (
            "pr-review",
            "pr-review-batch",
            "spec-create-batch",
            "spec-implement",
            "spec-implement-batch",
            "spec-revise",
            "spec-revise-batch",
        )
    ),
    SKILLS / "pr-review" / "hallazgos.md": (SKILLS / "pr-review-batch" / "hallazgos.md",),
    SKILLS
    / "pr-review"
    / "scripts"
    / "diff_pr.py": (SKILLS / "pr-review-batch" / "scripts" / "diff_pr.py",),
    SKILLS
    / "spec-revise-batch"
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
