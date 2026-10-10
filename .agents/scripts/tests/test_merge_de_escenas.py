"""Un `.tscn` no se mergea: dos ramas que lo cambian dan conflicto, y el diff sigue en texto.

Se prueba con un `git merge` de verdad en un repo temporal que usa el `.gitattributes` del
repo. Mirar el atributo con `git check-attr` diría qué está escrito, no qué hace git con él.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from lib.repo import RAIZ

ESCENA = "\n".join(
    [
        '[gd_scene format=3 uid="uid://prueba"]',
        "",
        '[node name="Raiz" type="Node3D"]',
        "",
        '[node name="Luz" type="OmniLight3D" parent="."]',
        "light_energy = 1.0",
        "",
        '[node name="Camara" type="Camera3D" parent="."]',
        "fov = 70.0",
        "",
    ]
)


class MergeDeEscenas(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        # La configuración de la máquina no entra: un `autocrlf` o un driver de merge global
        # cambiarían el resultado del merge sin que el `.gitattributes` tenga nada que ver.
        self.entorno = {
            **os.environ,
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
        }
        self._git("init", "-q", "-b", "base")
        shutil.copy(RAIZ / ".gitattributes", self.repo / ".gitattributes")
        self._escribir(ESCENA)
        self._git("add", ".")
        self._git("commit", "-q", "-m", "base")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _git(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@t", *args],
            cwd=self.repo,
            env=self.entorno,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

    def _escribir(self, texto: str) -> None:
        (self.repo / "escena.tscn").write_bytes(texto.encode("utf-8"))

    def _rama_que_cambia(self, rama: str, viejo: str, nuevo: str) -> None:
        self._git("checkout", "-q", "-b", rama, "base")
        self._escribir(ESCENA.replace(viejo, nuevo))
        self._git("commit", "-q", "-am", rama)

    def test_dos_ramas_que_cambian_lineas_distintas_dan_conflicto(self) -> None:
        # Sin el atributo, git mezcla las dos líneas sin avisar: son lejanas y no se pisan.
        self._rama_que_cambia("luz", "light_energy = 1.0", "light_energy = 2.0")
        self._rama_que_cambia("camara", "fov = 70.0", "fov = 90.0")
        merge = self._git("merge", "--no-edit", "luz")
        self.assertNotEqual(merge.returncode, 0, merge.stdout)
        sin_mergear = self._git("diff", "--name-only", "--diff-filter=U").stdout.split()
        self.assertEqual(sin_mergear, ["escena.tscn"])

    def test_una_escena_que_cambia_en_una_sola_rama_no_da_conflicto(self) -> None:
        self._rama_que_cambia("luz", "light_energy = 1.0", "light_energy = 2.0")
        self._git("checkout", "-q", "-b", "otra", "base")
        (self.repo / "otro.txt").write_bytes(b"algo\n")
        self._git("add", ".")
        self._git("commit", "-q", "-m", "otra")
        merge = self._git("merge", "--no-edit", "luz")
        self.assertEqual(merge.returncode, 0, merge.stdout + merge.stderr)
        self.assertIn("light_energy = 2.0", (self.repo / "escena.tscn").read_text(encoding="utf-8"))

    def test_el_diff_de_una_escena_se_ve_como_texto(self) -> None:
        self._escribir(ESCENA.replace("fov = 70.0", "fov = 90.0"))
        diff = self._git("diff").stdout
        self.assertNotIn("Binary files", diff)
        self.assertIn("+fov = 90.0", diff)


if __name__ == "__main__":
    unittest.main()
