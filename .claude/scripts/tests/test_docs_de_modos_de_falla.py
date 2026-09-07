"""Los modos de falla del harness están donde alguien los va a buscar.

Los seis que se pisaron montando esto están arreglados, y hasta ahora la explicación de cada uno
vivía **sólo en el docstring del código que lo arregla**. Ése es el lugar equivocado: a quien le
pasa el primero busca «declaré `GODOT_BIN` y no la ve», no abre `lib/godot.py`.

Este módulo verifica que la mudanza no se deshaga. Es un gate de **presencia**, y hay que
decirlo: sabe que el síntoma está escrito en `docs/`, no que la explicación siga siendo correcta.
Lo que lo hace algo más que un `rg` congelado es de dónde saca lo que busca — las herramientas
del matcher salen de `.claude/settings.json`, así que agregar una al hook y no contarlo en el doc
es rojo.

El encabezado de cada entrada es **el síntoma textual**: quien llega ahí tiene un error pegado en
el portapapeles, y «Problemas con el entorno de Windows» no matchea con nada de lo que tiene.
"""

import json
import re
import unittest
from pathlib import Path

from lib.repo import RAIZ

DOCS = RAIZ / "docs"
TROUBLESHOOTING = DOCS / "guides" / "troubleshooting.md"
QUICKSTART = DOCS / "guides" / "quickstart.md"
ARBOL = DOCS / "architecture" / "directory-structure.md"
SETTINGS = RAIZ / ".claude" / "settings.json"

#: El consejo que este spec vino a corregir. Abrir una terminal nueva **no alcanza** si el host
#: es anterior al cambio, y dejarlo al lado del correcto es peor que cualquiera de los dos solo.
CONSEJO_VIEJO = "Después hay que abrir una terminal nueva."

#: Cuántas líneas puede medir una trampa de `CLAUDE.md`. Es lo que mide hoy la más larga de las
#: cinco: el techo no es una preferencia, es no dejarla crecer a prosa.
LINEAS_POR_TRAMPA = 6

#: Cómo puede decir el doc que la lista del matcher no admite nada más. Acepta «la lista **es**
#: cerrada» porque es como está escrito, y el `\s+` sale de que `plano()` ya aplanó los saltos.
CERRADA = r"(?:lista|conjunto)\s+(?:es\s+)?cerrad[ao]"


def _texto(archivo: Path) -> str:
    return archivo.read_text(encoding="utf-8")


def plano(texto: str) -> str:
    """El texto con los saltos de línea aplanados.

    Los `.md` de este repo van cortados a 100 columnas, así que una frase de dos palabras cae
    partida a la mitad tan seguido como no. Buscarla sobre las líneas crudas produce un rojo que
    dice que el doc no lo dice cuando sí lo dice.
    """
    return re.sub(r"\s+", " ", texto)


def parrafos(texto: str) -> list[str]:
    return [plano(p) for p in texto.split("\n\n")]


def encabezados(texto: str) -> list[str]:
    return [linea for linea in texto.splitlines() if linea.startswith("## ")]


def herramientas_del_matcher() -> list[str]:
    """Las herramientas que el hook mira, leídas del `settings.json` que las declara.

    Recorre **todas** las entradas de `PreToolUse` y no la primera: quedarse con la `[0]` es
    justo el agujero que este gate viene a tapar, porque una herramienta agregada en un segundo
    bloque saldría verde sin estar en el doc, que es indistinguible de estar contada.
    """
    config = json.loads(_texto(SETTINGS))
    herramientas: list[str] = []
    for entrada in config["hooks"]["PreToolUse"]:
        for herramienta in entrada["matcher"].split("|"):
            if herramienta not in herramientas:
                herramientas.append(herramienta)
    return herramientas


def items_de_la_seccion(texto: str, titulo: str) -> list[list[str]]:
    """Los ítems de la lista de una sección, cada uno con sus líneas."""
    cuerpo = texto.split(titulo, 1)[1].split("\n## ", 1)[0]
    items: list[list[str]] = []
    for linea in cuerpo.splitlines():
        if linea.startswith("- "):
            items.append([linea])
        elif items and linea.startswith("  "):
            items[-1].append(linea)
    return items


class ModosDeFallaDocumentados(unittest.TestCase):
    def test_el_hook_encerrado_esta_en_troubleshooting(self):  # 003-AC1
        self.assertIn(
            "can't open file",
            _texto(TROUBLESHOOTING),
            "el síntoma del hook que falla cerrado no está escrito con las palabras con las que "
            "aparece: es lo único que quien lo sufre tiene para buscar.",
        )

    def test_el_quickstart_corrige_el_consejo_que_no_alcanza(self):  # 003-AC2
        texto = _texto(QUICKSTART)
        self.assertNotIn(
            CONSEJO_VIEJO,
            texto,
            "el consejo viejo sigue ahí. Se corrige, no se complementa: dejarlo al lado del "
            "correcto es peor que cualquiera de los dos solo.",
        )
        # En minúsculas porque el doc grita el «NO alcanza», que es el punto de la corrección.
        for palabra in ("no alcanza", "host", "cerrar sesión"):
            self.assertIn(
                palabra, plano(texto).lower(), f"el consejo correcto no dice «{palabra}»"
            )

    def test_el_arbol_nombra_a_powershell_como_herramienta_del_gate(self):  # 003-AC3
        # El otro hallazgo de `PowerShell` en `docs/` es el shell donde se declara una variable,
        # que no es lo mismo: acá se nombra la herramienta que el hook mira, y que faltaba.
        juntos = [p for p in parrafos(_texto(ARBOL)) if "PowerShell" in p and "matcher" in p]
        self.assertTrue(juntos, "el árbol no nombra a PowerShell como parte del matcher del hook")

    def test_el_arbol_nombra_todas_las_herramientas_del_matcher(self):  # 003-AC4
        # Las herramientas salen del `settings.json` que las declara, no de una lista escrita
        # acá: así, agregar una al hook y no contarla en el doc sale rojo. Ése es exactamente el
        # agujero que abrió el modo de falla — `PowerShell` no estaba en el matcher, y el gate se
        # salteaba solo con cambiar de herramienta.
        texto = _texto(ARBOL)
        for herramienta in herramientas_del_matcher():
            self.assertIn(
                herramienta,
                texto,
                f"el hook mira `{herramienta}` y el doc no lo dice: la lista es cerrada, y una "
                "lista cerrada que no está completa se lee como si lo estuviera.",
            )
        # Y la cerradura se busca **en el párrafo del matcher**, no en el documento entero: el
        # árbol ya decía «un conjunto cerrado de nombres» de `CARPETAS_POR_CAPA` desde antes de
        # este spec, así que un `assertRegex` sobre todo el texto pasaba con la sección del
        # matcher ausente. Un gate que no puede fallar es un gate apagado que parece encendido.
        cerrada = [p for p in parrafos(texto) if "matcher" in p and re.search(CERRADA, p)]
        self.assertTrue(
            cerrada,
            "el párrafo del matcher no dice que la lista sea cerrada, que es la mitad del dato: "
            "lo que no está declarado no lo mira nadie.",
        )

    def test_cada_trampa_de_claude_md_sigue_siendo_una_sola(self):  # 003-AC5
        items = items_de_la_seccion(_texto(RAIZ / "CLAUDE.md"), "## Las trampas de este repo")
        self.assertTrue(items, "la sección de trampas no tiene ítems")
        for item in items:
            self.assertLessEqual(
                len(item),
                LINEAS_POR_TRAMPA,
                f"esta trampa creció a prosa larga:\n{item[0]}\n"
                "El detalle vive en el doc que la explica; acá va la línea que la nombra.",
            )

    def test_la_suite_que_no_parsea_esta_en_troubleshooting(self):  # 003-AC8
        self.assertIn(
            "Executed test suites",
            _texto(TROUBLESHOOTING),
            "falta el número que vale: un verde de gdUnit4 puede ser una suite que no corrió.",
        )

    def test_el_export_en_null_esta_en_troubleshooting(self):  # 003-AC9
        self.assertIn(
            "node_paths",
            _texto(TROUBLESHOOTING),
            "falta la entrada del `@export` que llega en `null`: sin `node_paths` en el `.tscn` "
            "la escena carga sin un solo error y el juego muere en el primer cuadro.",
        )

    def test_el_worktree_sin_cache_esta_en_troubleshooting_con_su_cura(self):  # 003-AC10
        texto = _texto(TROUBLESHOOTING)
        self.assertIn(
            "GdUnitTestCIRunner",
            texto,
            "falta la entrada del worktree sin `.godot/`: el síntoma no nombra ni la caché ni el "
            "worktree, así que sin esto se busca en el addon.",
        )
        self.assertIn(
            "--import --quit",
            texto,
            "la entrada está pero no trae la cura, que es una línea: sin el comando, quien la "
            "encuentra sabe qué le pasa y no cómo salir.",
        )

    def test_cada_entrada_abre_con_el_sintoma_y_la_de_godot_va_primera(self):
        # Del `plan.md`: la de `GODOT_BIN` es la que le va a pasar a las cinco personas del
        # equipo la primera vez que configuren la máquina, así que es la primera que se ve.
        titulos = encabezados(_texto(TROUBLESHOOTING))
        self.assertTrue(titulos, "el troubleshooting no tiene una sola entrada")
        self.assertIn("GODOT_BIN", titulos[0])

    def test_ninguna_entrada_repite_su_sintoma(self):
        # Dos entradas con el mismo encabezado son una entrada que quedó duplicada al mover la
        # explicación desde el docstring, y el lector lee la primera.
        titulos = [re.sub(r"\s+", " ", t) for t in encabezados(_texto(TROUBLESHOOTING))]
        self.assertEqual(len(titulos), len(set(titulos)))


# 003-AC6 — `verificar.py` en verde: ningún nodo mira `docs/`, así que lo único que verifica es
# que el cambio no rompió otra cosa. Se corre, no se testea desde acá.
# 003-AC7 — los dos `Closes` del PR —el del issue de este spec y el `#2` del origen— se
# verifican leyendo el cuerpo del PR abierto: no hay nada en el árbol que los contenga.

if __name__ == "__main__":
    unittest.main()
