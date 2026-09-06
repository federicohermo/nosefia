"""El gate de capas corrido de verdad: el código de salida, que es lo único que mira `verificar.py`.

Lo que el gate **decide** vive en `lib/capas.py` y ahí están sus casos, escritos a mano. Acá se
ejerce lo único que no se puede ver sin lanzar el script: que un dominio impuro en el disco lo
ponga en rojo, y que el mismo árbol sin ese archivo lo deje en verde.

## Por qué el árbol es temporal, y por qué el gate acepta una raíz

`verificar.py` corre sus seis nodos **en paralelo**. Un test que ensuciara el `src/` del repo de
verdad para fabricar el rojo pondría a `capas`, `tdd`, `lint` y `formato` —que están corriendo en
ese mismo instante— a fallar por un archivo que este test está por borrar, y el rojo aparecería
en cuatro nodos que no tienen nada que ver. De ahí el parámetro `raiz` de `main()`: existe para
que el rojo se pueda fabricar sin tocar el repo.
"""

import inspect
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import gate_de_capas
import verificar
from lib.repo import RAIZ

GATE = Path(gate_de_capas.__file__)

#: Los tres lugares donde la regla de pureza está escrita, y la marca con la que los tres nombran
#: a su verificador.
#:
#: **La marca es la misma cadena en los tres a propósito.** El modo de falla real no es olvidarse
#: de los tres: es corregir dos y que el tercero siga diciendo que no lo mira nadie. Con una sola
#: cadena, un `rg` los contesta a los tres:
#:
#:     rg -n --no-ignore --hidden "La pureza la verifica .gate_de_capas.py." <los tres archivos>
#:
#: Y nombra a **la pureza** y no sólo al gate porque `lib/repo.py` ya decía «Lo verifica
#: `gate_de_capas.py`» de la **dirección**: una marca más corta habría dado verde sobre el
#: archivo que este spec vino a corregir.
MARCA = "La pureza la verifica `gate_de_capas.py`"
DOCUMENTOS_QUE_DECLARAN_LA_PUREZA = (
    ".claude/rules/dominio.md",
    "docs/architecture/overview.md",
    ".claude/scripts/lib/repo.py",
)


def arbol(carpeta: str, archivos: dict[str, str]) -> Path:
    """Un repo de mentira con los archivos que se le pidan, y devuelve su raíz."""
    raiz = Path(carpeta)
    for ruta, texto in archivos.items():
        destino = raiz / ruta
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_text(texto, encoding="utf-8")
    return raiz


def correr(raiz: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(GATE), str(raiz)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        cwd=RAIZ,
    )


class ElVeredictoSobreUnDominioImpuro(unittest.TestCase):
    def test_un_extends_node_en_el_dominio_lo_pone_en_rojo(self):
        # 012-AC8. Y se afirma también la salida, no sólo el código: un gate que sale 1 sin decir
        # qué archivo, qué línea y qué patrón manda a buscar a mano en toda la capa.
        with tempfile.TemporaryDirectory() as carpeta:
            proceso = correr(arbol(carpeta, {"src/dominio/x.gd": "extends Node\n"}))
        self.assertEqual(proceso.returncode, 1, proceso.stdout + proceso.stderr)
        self.assertIn("src/dominio/x.gd:1", proceso.stdout)
        self.assertIn("extends Node", proceso.stdout)

    def test_el_mismo_arbol_con_el_dominio_puro_sale_en_verde(self):
        # 012-AC8, la otra dirección, y sin ella la de arriba no significa nada: un gate que
        # saliera 1 siempre la pasaría igual.
        with tempfile.TemporaryDirectory() as carpeta:
            proceso = correr(arbol(carpeta, {"src/dominio/x.gd": "extends RefCounted\n"}))
        self.assertEqual(proceso.returncode, 0, proceso.stdout + proceso.stderr)

    def test_la_direccion_de_las_dependencias_sigue_en_el_mismo_gate(self):
        # El invariante del spec: la impureza entró al gate que ya existía y no le sacó nada.
        # `violaciones()` y su tupla de cinco se reportan igual que antes.
        archivos = {
            "src/dominio/x.gd": 'const Hud = preload("res://src/ui/hud.gd")\n',
            "src/ui/hud.gd": "extends Control\n",
        }
        with tempfile.TemporaryDirectory() as carpeta:
            proceso = correr(arbol(carpeta, archivos))
        self.assertEqual(proceso.returncode, 1, proceso.stdout + proceso.stderr)
        self.assertIn("src/dominio → src/ui", proceso.stdout)


class LosSeisNodosSiguenSiendoSeis(unittest.TestCase):
    def test_verificar_no_gano_un_septimo_nodo(self):
        # 012-AC9. La pureza es la misma pregunta que la dirección y que los nombres de carpeta
        # —«¿esta capa es lo que dice ser?»—, y un nodo aparte obligaría a leer dos reportes para
        # una sola respuesta.
        self.assertEqual(len(verificar.NODOS), 6)

    def test_el_nodo_capas_es_exactamente_este_gate(self):
        # 012-AC9, y es lo que hace que «`--solo capas` sale 1» se siga del AC8 en vez de ser una
        # promesa aparte: el código de salida del nodo ES el del gate que el AC8 ejerce.
        self.assertIn("gate_de_capas.py", inspect.getsource(verificar.nodo_capas))


class LaReglaNombraASuVerificador(unittest.TestCase):
    def test_los_tres_documentos_lo_nombran(self):
        # 012-AC10. Hasta hoy la pureza estaba escrita en tres lugares y ninguno era ejecutable;
        # ahora que lo es, los tres tienen que decir quién la mira — si no, se los sigue leyendo
        # como prosa y el próximo apuro la rompe igual.
        for documento in DOCUMENTOS_QUE_DECLARAN_LA_PUREZA:
            with self.subTest(documento=documento):
                texto = (RAIZ / documento).read_text(encoding="utf-8")
                # `assertTrue` y no `assertIn`: el rojo de `assertIn` vuelca el documento
                # entero, y lo que hay que leer es cuál de los tres falta.
                self.assertTrue(MARCA in texto, f"{documento} no nombra a «{MARCA}»")


if __name__ == "__main__":
    unittest.main()
