"""Los tests del mapa del sistema.

Lo que hay que cuidar de una herramienta que dibuja el grafo es que **no contradiga al gate**.
Si el mapa muestra una flecha que `gate_de_capas.py` pondría en rojo, sobre un repo con el nodo
`capas` en verde, la herramienta se deja de mirar el mismo día — y con ella el mapa.
"""

import unittest

from estructura import _referencias_entre_capas, _por_carpeta
from lib.capas import violaciones
from lib.repo import CAPAS


class ElGrafoNoContradiceAlGate(unittest.TestCase):
    def test_un_class_name_nombrado_en_un_comentario_no_es_una_referencia(self):
        # Es el defecto que tuvo la primera versión: contaba tres referencias de `dominio/` a
        # `sistemas/` que eran menciones en prosa, o sea tres violaciones inventadas.
        archivos = {
            "src/sistemas/marco/reloj.gd": "class_name Reloj\nextends Node\n",
            "src/dominio/jornada/turno.gd": "## Lo llama `Reloj` desde sistemas.\nclass_name Turno\n",
        }
        self.assertEqual(_referencias_entre_capas(archivos), {})

    def test_una_referencia_de_verdad_si_se_cuenta(self):
        archivos = {
            "src/dominio/jornada/turno.gd": "class_name Turno\nextends RefCounted\n",
            "src/sistemas/marco/reloj.gd": "class_name Reloj\nvar t: Turno\n",
        }
        self.assertEqual(
            _referencias_entre_capas(archivos), {("src/sistemas", "src/dominio"): 1}
        )

    def test_un_nombre_que_es_prefijo_de_otro_no_se_cuenta_dos_veces(self):
        # Sin el borde de palabra, `Tarea` matchea adentro de `TareaDeAtender` y el grafo
        # reporta dos referencias donde hay una.
        archivos = {
            "src/dominio/jornada/tarea.gd": "class_name Tarea\n",
            "src/sistemas/tareas/x.gd": "class_name X\nvar t: TareaDeAtender\n",
            "src/dominio/almacen/tarea_de_atender.gd": "class_name TareaDeAtender\n",
        }
        self.assertEqual(
            _referencias_entre_capas(archivos), {("src/sistemas", "src/dominio"): 1}
        )

    def test_ninguna_flecha_del_repo_va_contra_la_direccion(self):
        # El cruce de verdad: sobre el árbol real, toda flecha del grafo tiene que ser una que
        # el gate acepta. Si el gate no reporta violaciones, el grafo tampoco puede dibujar una.
        from estructura import _fuentes

        archivos = _fuentes()
        if not archivos:
            self.skipTest("no hay `.gd` en `src/`: no hay grafo que cruzar")
        permitidas = {capa: set(puede) for capa, puede in CAPAS}
        for (origen, destino) in _referencias_entre_capas(archivos):
            self.assertIn(
                destino,
                permitidas[origen],
                f"el mapa dibuja {origen} → {destino}, que el gate pone en rojo",
            )
        self.assertEqual(violaciones(archivos, CAPAS), [])


class ElAgrupadoPorCarpeta(unittest.TestCase):
    def test_la_raiz_de_una_capa_se_agrupa_aparte(self):
        agrupado = _por_carpeta(["src/dominio/reglas.gd", "src/dominio/jornada/turno.gd"])
        self.assertEqual(sorted(agrupado), ["jornada", "·"])
        self.assertEqual(agrupado["·"], ["src/dominio/reglas.gd"])


if __name__ == "__main__":
    unittest.main()
