"""La matriz de `lote.py`: qué archivo tocan dos specs del mismo lote.

La matriz es el insumo del Paso 2 de `spec-revise-batch` y del reparto de carriles de
`spec-implement-batch`. Ahí es donde importa, y por eso esto tiene test: un archivo que la
matriz no ve es, en el segundo skill, **dos specs que escriben el mismo archivo mandados a
worktrees paralelos**. El conflicto no aparece al repartir: aparece al mergear.

Las tres cegueras que este archivo cierra se midieron el 2026-09-02 sobre el lote 026 + 027,
donde las tres se dispararon a la vez y las tres tapaban aristas reales:

1. **`.yml` no estaba entre las extensiones.** Los dos specs escriben
   `.github/workflows/verify.yml` —uno le fija la versión de Godot, el otro le saca la
   variable entera— y la matriz no lo listó. Era la arista dura del lote.
2. **Una cita con número de línea no matcheaba.** `` `CLAUDE.md:28` `` no entraba, así que
   `CLAUDE.md` figuró como tocado por un solo spec cuando lo tocaban los dos.
3. **`README.md` se filtraba por basename.** El filtro existe para no contar los cuatro
   archivos que todo spec tiene adentro de su carpeta, pero comparaba el nombre pelado, así
   que se llevaba puesto `docs/README.md` — que los dos specs editan.

El criterio de las tres: **la matriz dice dónde mirar y equivocarse de más cuesta una mirada;
equivocarse de menos cuesta un merge.**
"""

import importlib.util
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
LOTE = RAIZ / ".claude" / "skills" / "spec-revise-batch" / "scripts" / "lote.py"


def _cargar():
    spec = importlib.util.spec_from_file_location("lote_bajo_prueba", LOTE)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


lote = _cargar()


def citados(linea: str) -> list[str]:
    """Lo que la matriz sacaría de una línea de tarea: las citas que no son del propio spec."""
    return [c for c in lote.CITA.findall(linea) if not lote.es_propio(c)]


class LaMatrizVeLosWorkflows(unittest.TestCase):
    def test_un_yml_de_github_entra(self):
        # El caso medido: el 026 le fija la versión y el 027 le saca la variable.
        linea = "- [ ] T009 [P] `.github/workflows/verify.yml`: `GODOT_VERSION: 4.7.2-stable`."
        self.assertIn(".github/workflows/verify.yml", citados(linea))

    def test_un_yaml_tambien(self):
        self.assertIn("ci.yaml", citados("- [ ] T001 tocar `ci.yaml`"))


class LaMatrizVeLasCitasConLinea(unittest.TestCase):
    def test_una_cita_con_numero_de_linea_entra(self):
        linea = "- [ ] T012 [P] `CLAUDE.md:28`: la línea **Stack:** pasa a Godot 4.7.2"
        self.assertIn("CLAUDE.md", citados(linea))

    def test_una_cita_con_rango_de_lineas_entra(self):
        linea = "- [ ] T010 `.claude/scripts/lib/godot.py:135-136`: la ruta de ejemplo"
        self.assertIn(".claude/scripts/lib/godot.py", citados(linea))

    def test_la_linea_no_queda_pegada_al_nombre(self):
        # Si `CLAUDE.md:28` entrara como tal, el mismo archivo citado en dos líneas distintas
        # serían dos filas de la matriz y ninguna saldría marcada como compartida.
        self.assertNotIn("CLAUDE.md:28", citados("`CLAUDE.md:28`"))


class ElFiltroDeLoPropioNoSeLlevaLoAjeno(unittest.TestCase):
    def test_los_archivos_del_spec_se_filtran(self):
        # Los de los dos regímenes: los cuatro de un spec ≤ 029 y los tres de uno ≥ 030.
        for nombre in ("spec.md", "research.md", "plan.md", "tasks.md", "estrategia.md"):
            self.assertEqual([], citados(f"- [ ] T001 ver `{nombre}`"), nombre)

    def test_el_readme_pelado_se_filtra(self):
        self.assertEqual([], citados("- [ ] T001 ver `README.md`"))

    def test_un_readme_con_ruta_no_se_filtra(self):
        # El caso medido: el 026 reescribe una sección y el 027 inserta en otra.
        self.assertIn("docs/README.md", citados("- [ ] T014 `docs/README.md`: la línea 4"))

    def test_un_tasks_con_ruta_tampoco_se_filtra(self):
        self.assertIn("docs/tasks.md", citados("- [ ] T001 `docs/tasks.md`"))


class LoQueYaAndabaSigueAndando(unittest.TestCase):
    def test_una_extension_suelta_no_es_un_archivo(self):
        # `los `.gd` de la capa` no es un archivo llamado «.gd».
        self.assertEqual([], citados("- [ ] T001 los `.gd` de `dominio/`"))

    def test_las_extensiones_de_siempre_siguen_entrando(self):
        for nombre in ("turno.gd", "almacen.tscn", "verificar.py", "mapa.json", "plugin.cfg"):
            self.assertIn(nombre, citados(f"- [ ] T001 `{nombre}`"), nombre)

    def test_una_escena_compartida_conserva_su_extension(self):
        # La marca `<- ESCENA COMPARTIDA` sale de un `endswith('.tscn')`: si el `:línea` se
        # colara en el nombre, la marca no saldría y la conclusión del skill se perdería.
        self.assertTrue(citados("`src/escenas/almacen.tscn:12`")[0].endswith(".tscn"))


if __name__ == "__main__":
    unittest.main()
