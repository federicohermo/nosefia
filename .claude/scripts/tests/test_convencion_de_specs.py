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
from lib.specs import leer_mapa

SPECS = RAIZ / "specs"

#: Los cuatro archivos son el **piso**, no el techo: un spec puede agregar los que necesite.
CANONICOS = ("spec.md", "research.md", "plan.md", "tasks.md")

#: `- [ ] T012 [P] Descripción`, con `[P]` opcional.
TAREA = re.compile(r"^- \[[ x]\] (T\d{3})( \[P\])? \S")

#: Una casilla que no respeta el formato: empieza como tarea y no matchea `TAREA`.
CASILLA = re.compile(r"^- \[[ x]\] ")

#: Una casilla sin marcar.
ABIERTA = re.compile(r"^- \[ \] ")

#: Un encabezado markdown, con su texto.
ENCABEZADO = re.compile(r"^#{1,6}\s+(.*?)\s*$")

#: Las secciones que aplazan trabajo, y por eso no existen acá.
#:
#: **`Fuera de alcance` no está en la lista y es deliberado**: declara una frontera —qué NO hace
#: este spec— y es lo que lo vuelve revisable. Se convierte en deuda sólo cuando algún AC del
#: propio spec depende de lo excluido, y eso ningún gate lo puede ver: lo mira el review. Lo
#: mismo con `Riesgos`, que analiza y no promete.
SECCION_QUE_APLAZA = re.compile(
    r"^(seguimiento|pendientes?|deuda|backlog|to-?do|futuro|a futuro|"
    r"pr[oó]ximos pasos|queda pendiente|para (m[aá]s adelante|despu[eé]s))\b",
    re.IGNORECASE,
)

#: Aplazar por texto adentro de una tarea. Una casilla que dice «por ahora» no es una tarea:
#: es una intención con formato de checklist, y se cierra marcándola sin haber hecho nada.
#:
#: **Son dos y no una porque el repo escribe en español.** Los marcadores de código van SIN
#: `IGNORECASE`: con él, `\bTODO\b` matchea la palabra «todo», y la primera corrida de este
#: gate se cazó a sí misma contra `T001 … todo tipo del enum tiene costo declarado`. Un gate
#: que da rojo sobre una tarea correcta se apaga en una semana, y ahí no queda gate.
MARCADOR_DE_CODIGO = re.compile(r"\bTODO\b|\bFIXME\b|\bXXX\b|\bHACK\b")

TAREA_QUE_APLAZA = re.compile(
    r"pendiente|m[aá]s adelante|a futuro|en el futuro|queda para|por ahora|provisori|"
    r"si (hay|sobra) tiempo|eventualmente|idealmente",
    re.IGNORECASE,
)

#: Una medición declarada como no hecha. El `research.md` sale de correr algo: una medición
#: aplazada es la deuda más cara del flujo, porque el plan entero se apoya en un número que
#: nadie midió y el spec igual se publica.
MEDICION_APLAZADA = re.compile(
    r"medici[oó]n pendiente|queda por medir|sin medir|no se pudo medir|falta medir|"
    r"pendiente de medir|habr[ií]a que medirlo",
    re.IGNORECASE,
)

#: El único estado en el que una casilla abierta es una contradicción. `Descartado` y `Superado`
#: son terminales —son historia y no se corrigen—, y `Propuesto` es la cola.
CERRADO = "Implementado"


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

    def test_ningun_spec_tiene_una_seccion_que_aplaza(self):
        # `## Seguimiento` era la puerta de atrás: un lugar adentro del spec donde escribir
        # trabajo que no se iba a hacer. Cerrarla por nombre no alcanzaba —la sección vuelve
        # llamándose `## Pendientes` o `## Próximos pasos` y hace exactamente lo mismo—, así
        # que lo que se prohíbe es la operación, no el título.
        #
        # Mira los cuatro archivos y no sólo `tasks.md`: un `## Deuda` en el `plan.md` aplaza
        # igual, y era donde no miraba nadie.
        for carpeta in self.carpetas:
            for archivo in CANONICOS:
                texto = (SPECS / carpeta / archivo).read_text(encoding="utf-8")
                for numero, linea in enumerate(texto.splitlines(), 1):
                    encabezado = ENCABEZADO.match(linea)
                    if encabezado:
                        self.assertNotRegex(
                            encabezado.group(1),
                            SECCION_QUE_APLAZA,
                            f"{carpeta}/{archivo}:{numero} aplaza trabajo en una sección. "
                            "La descarga no es anotarlo: ver .claude/skills/sin-deuda.md",
                        )

    def test_ninguna_tarea_aplaza_por_texto(self):
        # Una casilla que dice «por ahora» o «TODO» se cierra marcándola sin haber hecho nada,
        # y encima cuenta como tarea cumplida en el conteo del cierre. El `[M]` de
        # `test_ninguna_tarea_pide_una_persona` era el mismo agujero con otra sintaxis.
        for carpeta in self.carpetas:
            texto = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                if CASILLA.match(linea):
                    self.assertNotRegex(linea, TAREA_QUE_APLAZA, f"{carpeta}/tasks.md:{numero}")
                    self.assertNotRegex(linea, MARCADOR_DE_CODIGO, f"{carpeta}/tasks.md:{numero}")

    def test_ningun_research_deja_una_medicion_sin_hacer(self):
        # El `research.md` sale de correr algo: es la regla que hace estimable al spec. Una
        # medición declarada como pendiente es la deuda más cara del flujo, porque el plan
        # entero se apoya en un número que nadie midió y el spec **igual se publica** — o sea
        # que el agujero viaja hasta la implementación disfrazado de decisión tomada.
        for carpeta in self.carpetas:
            texto = (SPECS / carpeta / "research.md").read_text(encoding="utf-8")
            for numero, linea in enumerate(texto.splitlines(), 1):
                self.assertNotRegex(
                    linea,
                    MEDICION_APLAZADA,
                    f"{carpeta}/research.md:{numero}: una medición declarada como no hecha. "
                    "O se corre, o el spec no la necesitaba.",
                )

    def test_un_spec_implementado_no_tiene_casillas_abiertas(self):
        # El corazón de la doctrina, y la única de estas reglas que mira el registro además
        # del archivo: un spec `Implementado` con una casilla abierta ES la deuda invisible,
        # porque el ítem hereda el estado del spec y el spec dice que ya está.
        #
        # Los terminales (`Descartado`, `Superado`) no se miran: son historia. `Propuesto` es
        # la cola, y una casilla abierta ahí es lo normal.
        #
        # Falla también si el disco quedó atrás del issue, y eso es una feature: `specs/` es
        # caché, así que un `tasks.md` viejo es indistinguible de un spec que mintió. Las dos
        # salidas están en el mensaje.
        mapa = leer_mapa((SPECS / "mapa.json").read_text(encoding="utf-8"))
        for numero, fila in mapa.items():
            if fila.get("estado") != CERRADO:
                continue
            carpeta = fila.get("carpeta")
            if carpeta not in self.carpetas:
                continue  # no está hidratado: este gate no puede mirarlo, y el setUp ya lo dijo
            tareas = (SPECS / carpeta / "tasks.md").read_text(encoding="utf-8")
            abiertas = [
                linea for linea in tareas.splitlines() if ABIERTA.match(linea)
            ]
            self.assertEqual(
                abiertas,
                [],
                f"el spec {numero} está `{CERRADO}` y su tasks.md tiene "
                f"{len(abiertas)} casilla(s) abierta(s): {abiertas[:3]}. "
                "O falta implementarlas, o falta devolver las marcas al issue con "
                "`publicar_spec.py publicar` y rehidratar.",
            )


if __name__ == "__main__":
    unittest.main()
