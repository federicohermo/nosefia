"""El `estado` de un spec no se escribe a mano, y hasta hoy eso era sólo una frase.

`CLAUDE.md`, `specs/README.md` y el encabezado de `test_convencion_de_specs.py` afirmaban los
tres que «el gate del mapa prohíbe tocarlo adentro del PR que lo justifica». No existía. Y no
era una imprecisión de redacción: el gate de la convención **apoya su diseño** en esa frase
—decide a quién mirar por el `estado` en vez de por el número, y el argumento para preferirlo
es justamente que el estado no se puede escribir—.

Sin el gate, la evasión es de una línea: a un spec en vuelo que no pasa los techos se le
escribe `Implementado` en `specs/mapa.json`, `es_adr()` lo saltea por ADR y el gate de la
convención deja de mirarlo. En verde, y sin que ninguna herramienta lo nombre.

## Qué se prohíbe, y qué no

Sólo el `estado` de una fila **que ya estaba en la base**. Una fila nueva es un spec recién
abierto —`publicar_spec.py crear` escribe el mapa, y el flujo manda commitearlo—, así que
prohibir todo cambio prohibiría abrir specs. Los otros campos tampoco: renombrar una carpeta o
corregir un título no evade ninguna regla.

## Los dos salteos, y por qué cada uno se declara

Se saltea si no hay `specs/mapa.json` en disco y si no se pudo leer el de la base —sin
`git fetch origin` no hay contra qué comparar—. Los dos son estados normales; el que no lo es
sería un gate que no pudo mirar y sale igual que uno que miró.
"""

import unittest

from lib.rama import archivo_en_la_base
from lib.repo import RAIZ
from lib.specs import estados_reescritos, leer_mapa

MAPA = "specs/mapa.json"


class EstadoDelMapa(unittest.TestCase):
    def setUp(self):
        en_disco = RAIZ / MAPA
        if not en_disco.is_file():
            self.skipTest(f"no hay {MAPA}: este gate NO miró nada.")
        self.rama = leer_mapa(en_disco.read_text(encoding="utf-8"))
        crudo = archivo_en_la_base(MAPA)
        if crudo is None:
            self.skipTest(
                f"no se pudo leer {MAPA} en la base de esta rama: este gate NO miró nada. "
                "Suele ser que falte `git fetch origin`."
            )
        self.base = leer_mapa(crudo)

    def test_ninguna_fila_que_ya_estaba_cambia_de_estado(self):
        reescritos = estados_reescritos(self.base, self.rama)
        self.assertEqual(
            reescritos,
            [],
            f"{len(reescritos)} spec(s) cambian de estado adentro de la rama: "
            f"{'; '.join(reescritos)}. El estado no se escribe a mano: lo deriva "
            "`.github/workflows/mapa.yml` del PR que aterrizó. Escribirlo acá apaga el gate "
            "de la convención sobre ese spec —`es_adr()` lo saltea— sin que nada lo diga. "
            "Revertí el campo `estado` y dejá que la Action lo derive.",
        )


class Sondas(unittest.TestCase):
    def test_una_fila_nueva_no_es_una_reescritura(self):
        # Abrir un spec escribe el mapa: prohibirlo prohibiría el flujo entero.
        base = {"030": {"estado": "Propuesto"}}
        rama = {"030": {"estado": "Propuesto"}, "031": {"estado": "Propuesto"}}
        self.assertEqual(estados_reescritos(base, rama), [])

    def test_un_estado_cambiado_se_nombra_con_las_dos_puntas(self):
        # «030 cambia de estado» manda a buscarlo; «`Propuesto` → `Implementado`» se lee y se
        # revierte sin abrir el archivo.
        base = {"030": {"estado": "Propuesto"}}
        rama = {"030": {"estado": "Implementado"}}
        self.assertEqual(
            estados_reescritos(base, rama), ["030: `Propuesto` → `Implementado`"]
        )

    def test_cambiar_otro_campo_no_es_hallazgo(self):
        # Renombrar una carpeta o corregir un título no evade ninguna regla.
        base = {"030": {"estado": "Propuesto", "carpeta": "030-viejo"}}
        rama = {"030": {"estado": "Propuesto", "carpeta": "030-nuevo"}}
        self.assertEqual(estados_reescritos(base, rama), [])

    def test_una_fila_que_desaparece_no_rompe_el_gate(self):
        # El barrido va sobre la rama, así que una fila borrada no entra. Borrar una fila es
        # otro defecto y lo caza `derivar_mapa.py`, que la vuelve a escribir.
        self.assertEqual(estados_reescritos({"030": {"estado": "Propuesto"}}, {}), [])
