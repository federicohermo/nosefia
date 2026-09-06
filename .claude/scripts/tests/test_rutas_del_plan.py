"""El cruce del `### Rutas` del plan contra lo que la rama efectivamente toca.

**Es la mitad verificable de `## Qué NO se toca`.** La otra —`### Invariantes`— es prosa y lo
dice: ningún gate puede decidir si «ningún autoload» se cumplió. Ésta sí, y por eso la
partición existe.

## Por qué una lista NEGATIVA sí y el `tasks.md` no

El `tasks.md` predecía qué se **va** a tocar: lista positiva y abierta, medida en 43 % de rutas
nunca tocadas y 39 % de imprevistos. Una lista de rutas prohibidas es negativa y cerrada, así
que esa medición no le aplica — mide aciertos de una lista positiva, y una prohibición no se
equivoca por omisión. Lo peor que puede pasar con una ruta que faltó declarar es que el gate no
diga nada, que es exactamente lo que pasa hoy con las 24.

## Los cuatro salteos, y por qué cada uno se declara

Se saltea si la rama no nombra un spec, si no se puede leer su `plan.md`, si no se pudo medir
el diff contra la base, y si el plan no declara ninguna ruta —11 de los 24 specs abiertos sólo
restringen invariantes—. Los cuatro son estados normales; el que no lo es sería un gate que no
pudo mirar y sale igual que uno que miró.
"""

import unittest

from lib.rama import (
    archivo_del_spec,
    archivos_de_la_rama,
    rama_actual,
    rutas_violadas,
    spec_de_la_rama,
)
from lib.specs import rutas_intocables


class RutasDelPlan(unittest.TestCase):
    def setUp(self):
        self.numero = spec_de_la_rama()
        if self.numero is None:
            self.skipTest(
                f"la rama `{rama_actual()}` no nombra un spec: este gate NO miró nada. "
                "Corre sobre una rama `<prefijo>/<NNN>-<kebab>`."
            )
        leido = archivo_del_spec(self.numero, "plan.md")
        if leido is None:
            self.skipTest(
                f"no se pudo leer el plan.md del {self.numero}: no está hidratado y `gh` no "
                f"contestó. Este gate NO miró nada. `hidratar_specs.py {self.numero}` lo trae."
            )
        self.plan, self.origen = leido
        self.rutas = rutas_intocables(self.plan)
        if not self.rutas:
            self.skipTest(
                f"el plan del {self.numero} ({self.origen}) no declara ninguna ruta en su "
                "`### Rutas`: este gate NO miró nada. Es un estado normal —11 de los 24 specs "
                "abiertos sólo restringen invariantes—, no un spec mal escrito."
            )
        self.archivos = archivos_de_la_rama()
        if self.archivos is None:
            self.skipTest(
                "no se pudo medir qué archivos cambia la rama contra su base: este gate NO "
                "miró nada. Suele ser que falte `git fetch origin`."
            )

    def test_la_rama_no_toca_lo_que_su_plan_declaro_intocable(self):
        violadas = rutas_violadas(self.rutas, self.archivos)
        detalle = "; ".join(f"`{a}` lo prohíbe `{r}`" for a, r in violadas)
        self.assertEqual(
            violadas,
            [],
            f"la rama del spec {self.numero} toca {len(violadas)} archivo(s) que su propio "
            f"plan ({self.origen}) declara intocables: {detalle}. O el archivo no había que "
            "tocarlo, o la restricción del plan estaba mal y se corrige ahí —en `### Rutas`— "
            "antes de seguir. Un archivo citado como fuente de algo no va en ese rubro.",
        )
