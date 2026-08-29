"""El gate de la convención de specs, sobre los que estén hidratados en disco.

`specs/[0-9]*/` es caché: en un clone nuevo no hay ninguno y este archivo entero se saltea.
Eso está bien, y por eso **se declara**: un gate que mira cero specs y dice «OK» es
indistinguible de uno que los miró todos, que es la peor respuesta posible.

Para que mire todo el árbol hace falta traerlo:

    python .claude/scripts/hidratar_specs.py --todos
"""

import re
import unittest

from lib.repo import RAIZ

SPECS = RAIZ / "specs"

#: Los cuatro archivos son el **piso**, no el techo: un spec puede agregar los que necesite.
CANONICOS = ("spec.md", "research.md", "plan.md", "tasks.md")

#: `- [ ] T012 [P] Descripción`, con `[P]` opcional.
TAREA = re.compile(r"^- \[[ x]\] (T\d{3})( \[P\])? \S")

#: Una casilla que no respeta el formato: empieza como tarea y no matchea `TAREA`.
CASILLA = re.compile(r"^- \[[ x]\] ")


def hidratados() -> list[str]:
    if not SPECS.is_dir():
        return []
    return sorted(
        e.name for e in SPECS.iterdir() if e.is_dir() and re.match(r"^\d{3}-", e.name)
    )


class Convencion(unittest.TestCase):
    def setUp(self):
        self.carpetas = hidratados()
        if not self.carpetas:
            self.skipTest(
                "no hay ningún spec hidratado en disco: este gate NO miró nada. "
                "`python .claude/scripts/hidratar_specs.py --todos` los trae."
            )

    def test_cada_spec_tiene_los_cuatro_archivos(self):
        for carpeta in self.carpetas:
            for archivo in CANONICOS:
                self.assertTrue((SPECS / carpeta / archivo).is_file(), f"{carpeta}/{archivo}")

    def test_el_spec_arranca_con_su_encabezado(self):
        # De esa línea sale el título del issue: sin ella, `publicar_spec.py` no tiene qué
        # publicar.
        for carpeta in self.carpetas:
            primera = (SPECS / carpeta / "spec.md").read_text(encoding="utf-8").splitlines()[0]
            self.assertTrue(primera.startswith("# "), f"{carpeta}/spec.md: «{primera[:40]}»")

    def test_todas_las_casillas_respetan_el_formato_de_tarea(self):
        for carpeta in self.carpetas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                if CASILLA.match(linea):
                    self.assertRegex(linea, TAREA, f"{carpeta}/tasks.md:{numero}")

    def test_los_ids_de_tarea_no_se_repiten(self):
        # Los IDs son estables: no se renumeran al insertar una tarea nueva, se sigue contando.
        # Un ID libre no molesta a nadie; uno reusado rompe la referencia que otra tarea le
        # hacía, y el `spec_write` que la marca ya no sabe cuál de las dos es.
        for carpeta in self.carpetas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            ids = TAREA.findall(texto)
            solos = [i[0] for i in ids]
            self.assertEqual(len(solos), len(set(solos)), f"{carpeta}/tasks.md tiene IDs repetidos")

    def test_ninguna_tarea_pide_una_persona(self):
        # Una tarea que se cierra mirando o escuchando no la puede cerrar un agente, y en la
        # práctica no la cierra nadie: en el repo del que sale este harness eran 137 casillas
        # marcadas así en 35 specs, y sólo 6 se cerraron alguna vez. O sea que el marcador no
        # significaba «espera a una persona» sino «no se va a hacer, pero queda escrito».
        #
        # La salida son dos y anotarlo no es ninguna: o la verificación se vuelve verificable
        # —un test, una medición, un valor que un gate pueda leer— y entonces es una tarea
        # normal que bloquea como cualquier otra, o no se escribe.
        pide_persona = re.compile(r"\[M\]|a ojo|de o[ií]do|escuchar|mirar la pantalla|captura",
                                  re.IGNORECASE)
        for carpeta in self.carpetas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                if CASILLA.match(linea):
                    self.assertNotRegex(linea, pide_persona, f"{carpeta}/tasks.md:{numero}")

    def test_ningun_spec_tiene_seccion_de_seguimiento(self):
        # La deuda que aparece implementando se abre como issue, no se anota adentro del spec:
        # ahí hereda el estado de su spec, y un spec `Implementado` puede quedar con diez
        # casillas abiertas sin deberle nada a nadie. Un issue tiene estado propio.
        for carpeta in self.carpetas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            self.assertNotIn("## Seguimiento", texto, f"{carpeta}/tasks.md")


if __name__ == "__main__":
    unittest.main()
