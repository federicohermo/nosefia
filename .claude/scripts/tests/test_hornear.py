"""Lo que el editor re-serializa al guardar vuelve a lo que tenía, sobre un repo de juguete.

`reescritos_de_mas()` decide qué se devuelve; acá se prueba que el script lo devuelva de verdad:
lo limpio a lo de git, lo que ya tenía cambios a esos cambios, y las salidas del horneado quietas.
No hace falta Godot: el «editor» son escrituras con la fecha corrida.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import hornear
from lib.horneado import SALIDAS

#: Las texturas del modelo llevan acentos en el nombre, y cada una tiene su `.import` rastreado.
CON_ACENTO = "assets/models/textura portón.png.import"


class DevolverLoReescrito(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="hornear_")).resolve()
        self.addCleanup(shutil.rmtree, self.repo, True)
        for ruta in (*SALIDAS, "src/escenas/almacen.tscn", "sucio.tres", CON_ACENTO):
            self._escribir(ruta, "de git\n")
        self._git("init", "-q")
        self._git("add", ".")
        self._git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "x")
        self._escribir("sucio.tres", "cambio sin commitear\n")
        self.previos = hornear.sucios(self.repo)
        # La fecha de cada archivo la pone el caso: el reloj de los archivos tiene otra
        # resolución que `time.time()`, y uno escrito justo después puede quedar antes.
        self.desde = 1_000_000.0
        for ruta in self._git("ls-files", "-z").split("\0"):
            if ruta:
                os.utime(self.repo / ruta, (self.desde - 60, self.desde - 60))

    def _git(self, *args: str) -> str:
        return subprocess.run(
            ["git", *args], cwd=self.repo, check=True, capture_output=True, encoding="utf-8"
        ).stdout

    def _escribir(self, ruta: str, texto: str) -> None:
        (self.repo / ruta).parent.mkdir(parents=True, exist_ok=True)
        (self.repo / ruta).write_text(texto, encoding="utf-8")

    def _el_editor_escribe(self, ruta: str) -> None:
        self._escribir(ruta, "re-serializado\n")
        os.utime(self.repo / ruta, (self.desde + 60, self.desde + 60))

    def _leer(self, ruta: str) -> str:
        return (self.repo / ruta).read_text(encoding="utf-8")

    def test_lo_que_estaba_limpio_vuelve_a_lo_de_git(self) -> None:
        self._el_editor_escribe("src/escenas/almacen.tscn")
        hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(self._leer("src/escenas/almacen.tscn"), "de git\n")

    def test_lo_que_tenia_cambios_vuelve_a_esos_cambios(self) -> None:
        self._el_editor_escribe("sucio.tres")
        hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(self._leer("sucio.tres"), "cambio sin commitear\n")

    def test_las_salidas_del_horneado_quedan(self) -> None:
        for salida in SALIDAS:
            self._el_editor_escribe(salida)
        hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        for salida in SALIDAS:
            self.assertEqual(self._leer(salida), "re-serializado\n")

    def test_lo_que_no_se_escribio_durante_la_corrida_no_se_toca(self) -> None:
        devueltos = hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(devueltos, [])
        self.assertEqual(self._leer("sucio.tres"), "cambio sin commitear\n")

    def test_una_ruta_con_acento_tambien_vuelve(self) -> None:
        # Sin `-z`, git la imprime entre comillas y con escapes octales, y esa ruta no existe:
        # el archivo se quedaba re-serializado sin que nada lo dijera.
        self._el_editor_escribe(CON_ACENTO)
        devueltos = hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(devueltos, [CON_ACENTO])
        self.assertEqual(self._leer(CON_ACENTO), "de git\n")

    def test_una_ruta_con_acento_que_tenia_cambios_vuelve_a_esos_cambios(self) -> None:
        self._escribir(CON_ACENTO, "cambio sin commitear\n")
        previos = hornear.sucios(self.repo)
        self._el_editor_escribe(CON_ACENTO)
        hornear.devolver_lo_reescrito(self.repo, self.desde, previos)
        self.assertEqual(self._leer(CON_ACENTO), "cambio sin commitear\n")


if __name__ == "__main__":
    unittest.main()
