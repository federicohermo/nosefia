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
from unittest import mock

import hornear
from lib.horneado import INTERMEDIOS_DEL_APOYO, SALIDAS, SALIDAS_QUE_SE_DEVUELVEN

#: Las texturas del modelo llevan acentos en el nombre, y cada una tiene su `.import` rastreado.
CON_ACENTO = "assets/models/textura portón.png.import"


class DevolverLoReescrito(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="hornear_")).resolve()
        self.addCleanup(shutil.rmtree, self.repo, True)
        for ruta in (
            *SALIDAS,
            "src/escenas/almacen.exr.import",
            "src/escenas/almacen.tscn",
            "sucio.tres",
            CON_ACENTO,
        ):
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

    def test_el_numero_de_capas_del_atlas_no_vuelve_al_horneado_anterior(self) -> None:
        ruta = "src/escenas/almacen.exr.import"
        self._escribir(ruta, "slices/vertical=16\n")
        os.utime(self.repo / ruta, (self.desde + 60, self.desde + 60))
        hornear.devolver_lo_reescrito(self.repo, self.desde, self.previos)
        self.assertEqual(self._leer(ruta), "slices/vertical=16\n")

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


class HorneadoConLuz(unittest.TestCase):
    # El horneado con luz son varios pasos, y cada uno lo hace otro programa: acá se prueba el
    # orden y qué pasa si uno falla, con los programas reemplazados por registros.
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="hornear_")).resolve()
        self.addCleanup(shutil.rmtree, self.repo, True)
        for ruta in (*SALIDAS_QUE_SE_DEVUELVEN, "sucio.tres"):
            self._escribir(ruta, "de git\n")
        subprocess.run(["git", "init", "-q"], cwd=self.repo, check=True)
        subprocess.run(["git", "add", "."], cwd=self.repo, check=True)
        subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "x"],
            cwd=self.repo,
            check=True,
        )
        self.pasos: list[str] = []

    def _escribir(self, ruta: str, texto: str) -> None:
        (self.repo / ruta).parent.mkdir(parents=True, exist_ok=True)
        (self.repo / ruta).write_text(texto, encoding="utf-8")

    def _leer(self, ruta: str) -> str:
        return (self.repo / ruta).read_text(encoding="utf-8")

    def _sesion(self, godot: str, variante: str, salidas: tuple[str, ...]) -> None:
        self.pasos.append("editor:" + (variante or "siempre"))

    def _reparar(self, blender: str, atlas: list[str]) -> None:
        self.pasos.append("reparar:" + ",".join(Path(a).name for a in atlas))

    def _mezclar(self, godot: str, nivel: float) -> None:
        self.pasos.append("mezclar")

    def _correr(self, nivel: float) -> None:
        with (
            mock.patch.object(hornear, "sesion_del_editor", self._sesion),
            mock.patch.object(hornear, "reparar_lineas", self._reparar),
            mock.patch.object(hornear, "mezclar_atlas", self._mezclar),
            mock.patch.object(hornear, "NIVEL_DE_APOYO", nivel),
        ):
            hornear.hornear_con_luz("godot", "blender")

    def test_hornea_repara_hornea_con_obstaculos_repara_mezcla_y_repara_el_resultado(self) -> None:
        self._correr(0.5)
        atlas = Path(SALIDAS[1]).name
        apoyo = Path(INTERMEDIOS_DEL_APOYO[1]).name
        self.assertEqual(
            self.pasos,
            [
                "editor:siempre",
                f"reparar:{atlas}",
                "editor:con_apoyo",
                f"reparar:{apoyo}",
                "mezclar",
                f"reparar:{atlas}",
            ],
        )

    def test_con_nivel_cero_el_atlas_de_siempre_es_el_final(self) -> None:
        self._correr(0.0)
        self.assertEqual(self.pasos, ["editor:siempre", "reparar:" + Path(SALIDAS[1]).name])

    def _main_con_un_paso_que_falla(self) -> int:
        def hornear_a_medias(godot: str, blender: str) -> None:
            for ruta in (*SALIDAS_QUE_SE_DEVUELVEN, *INTERMEDIOS_DEL_APOYO):
                self._escribir(ruta, "a medias\n")
            raise hornear.Fallo("el editor se cayó")

        with (
            mock.patch.object(hornear, "RAIZ", str(self.repo)),
            mock.patch.object(hornear, "resolver", lambda entorno: ("godot", None)),
            mock.patch.object(hornear.lib_blender, "resolver", lambda entorno: ("blender", None)),
            mock.patch.object(hornear, "sesion_bloqueada", lambda procesos: False),
            mock.patch.object(hornear, "hornear_con_luz", hornear_a_medias),
        ):
            return hornear.main([])

    def test_si_un_paso_falla_las_salidas_quedan_como_estaban_y_sale_con_error(self) -> None:
        self.assertNotEqual(self._main_con_un_paso_que_falla(), 0)
        for ruta in SALIDAS_QUE_SE_DEVUELVEN:
            self.assertEqual(self._leer(ruta), "de git\n")

    def test_si_un_paso_falla_no_quedan_archivos_intermedios(self) -> None:
        self._main_con_un_paso_que_falla()
        for ruta in INTERMEDIOS_DEL_APOYO:
            self.assertFalse((self.repo / ruta).exists())

    def test_si_sale_bien_tampoco_quedan_archivos_intermedios(self) -> None:
        def hornear_bien(godot: str, blender: str) -> None:
            for ruta in INTERMEDIOS_DEL_APOYO:
                self._escribir(ruta, "de paso\n")
            self._escribir(SALIDAS[1], "horneado\n")

        with (
            mock.patch.object(hornear, "RAIZ", str(self.repo)),
            mock.patch.object(hornear, "resolver", lambda entorno: ("godot", None)),
            mock.patch.object(hornear.lib_blender, "resolver", lambda entorno: ("blender", None)),
            mock.patch.object(hornear, "sesion_bloqueada", lambda procesos: False),
            mock.patch.object(hornear, "hornear_con_luz", hornear_bien),
        ):
            self.assertEqual(hornear.main([]), 0)
        for ruta in INTERMEDIOS_DEL_APOYO:
            self.assertFalse((self.repo / ruta).exists())
        self.assertEqual(self._leer(SALIDAS[1]), "horneado\n")

    def test_una_salida_que_no_existia_se_borra_si_el_horneado_falla(self) -> None:
        respaldo = hornear.guardar_salidas(self.repo, ("src/escenas/nueva.exr",))
        self._escribir("src/escenas/nueva.exr", "a medias\n")
        hornear.devolver_salidas(self.repo, respaldo)
        self.assertFalse((self.repo / "src/escenas/nueva.exr").exists())


if __name__ == "__main__":
    unittest.main()
