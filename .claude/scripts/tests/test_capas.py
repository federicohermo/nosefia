"""Los tests de `lib/capas.py`: qué es cada capa de `src/` y a quién puede referenciar.

Los archivos se escriben a mano acá adentro. Recibir `ruta → texto` en vez de leer el disco
es lo que permite que los casos que importan —una referencia adentro de un comentario, un
`class_name` que además es una palabra común— entren en cuatro líneas.
"""

import ntpath
import unittest

import lib.capas
from lib.capas import (
    capa_de,
    carpetas_no_declaradas,
    impurezas,
    indice_de_class_names,
    violaciones,
)
from lib.repo import CAPAS as CAPAS_DEL_REPO
from lib.repo import CARPETAS_POR_CAPA, RAIZ

CAPAS = (
    ("src/dominio", ()),
    ("src/sistemas", ("src/dominio",)),
    ("src/ui", ("src/dominio", "src/sistemas")),
    ("src/escenas", ("src/dominio", "src/sistemas", "src/ui")),
)

#: Los nombres de subcarpeta que cada capa del fixture admite.
#:
#: Es de mentira a propósito, igual que `CAPAS`: el gate real lee `CARPETAS_POR_CAPA` de
#: `lib/repo.py`, y un test que importe la constante de producción deja de verificar la función y
#: pasa a verificar el dato — con lo cual el día que alguien agregue una carpeta al repo, el test
#: la acepta sin que nadie lo haya decidido. Ese agujero lo cierra aparte
#: `CarpetasQueElDominioAdmite`, al final del archivo: importa `CARPETAS_POR_CAPA` a propósito
#: porque lo que ejerce es el dato, y por eso cubre sólo a `src/dominio`.
CARPETAS = {
    "src/dominio": frozenset({"jugador", "jornada", "empleo"}),
    "src/sistemas": frozenset({"marco", "tareas", "investigacion"}),
    "src/ui": frozenset({"diegetica", "interrupciones"}),
}


class CapaDe(unittest.TestCase):
    def test_reconoce_la_capa(self):
        self.assertEqual(capa_de("src/dominio/turno.gd", CAPAS), "src/dominio")

    def test_lo_que_no_esta_en_ninguna_capa_es_none(self):
        self.assertIsNone(capa_de("addons/gdUnit4/plugin.gd", CAPAS))

    def test_normaliza_las_barras_de_windows(self):
        # Sin normalizar, en Windows NINGUNA ruta cae en ninguna capa y el gate pasa siempre,
        # en verde. Es el bug más caro que puede tener un gate: el que no se ve.
        self.assertEqual(capa_de(ntpath.join("src", "dominio", "turno.gd"), CAPAS), "src/dominio")


class PorRuta(unittest.TestCase):
    def test_el_dominio_no_puede_preloadear_la_ui(self):
        archivos = {
            "src/dominio/turno.gd": 'const Hud = preload("res://src/ui/hud.gd")\n',
            "src/ui/hud.gd": "extends Control\n",
        }
        hallazgos = violaciones(archivos, CAPAS)
        self.assertEqual(len(hallazgos), 1)
        ruta, linea, origen, destino, _ = hallazgos[0]
        self.assertEqual((ruta, linea, origen, destino), ("src/dominio/turno.gd", 1, "src/dominio",
                                                          "src/ui"))

    def test_la_ui_si_puede_preloadear_el_dominio(self):
        archivos = {
            "src/ui/hud.gd": 'const Turno = preload("res://src/dominio/turno.gd")\n',
            "src/dominio/turno.gd": "extends RefCounted\n",
        }
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_tambien_mira_load(self):
        archivos = {"src/dominio/turno.gd": 'var h = load("res://src/ui/hud.gd")\n'}
        self.assertEqual(len(violaciones(archivos, CAPAS)), 1)

    def test_tambien_mira_extends_por_ruta(self):
        archivos = {"src/dominio/turno.gd": 'extends "res://src/ui/hud.gd"\n'}
        self.assertEqual(len(violaciones(archivos, CAPAS)), 1)

    def test_una_referencia_dentro_de_la_misma_capa_no_es_violacion(self):
        archivos = {"src/dominio/turno.gd": 'const T = preload("res://src/dominio/tarea.gd")\n'}
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_una_referencia_a_algo_que_no_es_capa_se_ignora(self):
        # `addons/` y los recursos no participan de la regla.
        archivos = {"src/dominio/turno.gd": 'const X = preload("res://addons/gdUnit4/src/X.gd")\n'}
        self.assertEqual(violaciones(archivos, CAPAS), [])


class PorClassName(unittest.TestCase):
    def test_indexa_los_class_name_de_src(self):
        archivos = {"src/ui/hud.gd": "class_name Hud\nextends Control\n"}
        self.assertEqual(indice_de_class_names(archivos, CAPAS), {"Hud": "src/ui"})

    def test_no_indexa_los_de_afuera_de_src(self):
        archivos = {"test/dominio/turno_test.gd": "class_name TurnoTest\n"}
        self.assertEqual(indice_de_class_names(archivos, CAPAS), {})

    def test_el_dominio_no_puede_nombrar_una_clase_de_la_ui(self):
        # Ésta es la puerta que ningún análisis de imports encuentra: no hay una sola ruta
        # escrita, y en Godot es la forma NORMAL de escribir código.
        archivos = {
            "src/ui/hud.gd": "class_name Hud\nextends Control\n",
            "src/dominio/turno.gd": "extends RefCounted\n\nfunc pintar(h: Hud) -> void:\n\tpass\n",
        }
        hallazgos = violaciones(archivos, CAPAS)
        self.assertEqual(len(hallazgos), 1)
        self.assertEqual(hallazgos[0][3], "src/ui")

    def test_un_class_name_nombrado_en_un_comentario_no_cuenta(self):
        # Un gate con falsos positivos se apaga: la única salida que le queda a quien lo sufre
        # es sacarlo del `verify`.
        archivos = {
            "src/ui/hud.gd": "class_name Hud\n",
            "src/dominio/turno.gd": "# esto lo va a pintar Hud, algún día\nextends RefCounted\n",
        }
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_un_class_name_adentro_de_un_string_no_cuenta(self):
        archivos = {
            "src/ui/hud.gd": "class_name Hud\n",
            "src/dominio/turno.gd": 'var etiqueta := "Hud"\n',
        }
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_un_nombre_que_es_prefijo_de_otro_no_cuenta(self):
        # `\\b` de los dos lados: `Hud` no matchea adentro de `HudViejo`.
        archivos = {
            "src/ui/hud.gd": "class_name Hud\n",
            "src/dominio/turno.gd": "var x := HudViejo.new()\n",
        }
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_declarar_el_propio_class_name_no_es_referenciarse(self):
        archivos = {"src/dominio/turno.gd": "class_name Turno\nextends RefCounted\n"}
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_la_linea_del_hallazgo_es_la_del_archivo(self):
        # Los strings y comentarios se reemplazan por espacios y no se borran, justamente para
        # que el número de línea siga siendo el de verdad.
        archivos = {
            "src/ui/hud.gd": "class_name Hud\n",
            "src/dominio/turno.gd": '# comentario\nvar s := "texto"\n\nvar h: Hud\n',
        }
        self.assertEqual(violaciones(archivos, CAPAS)[0][1], 4)


class CarpetasNoDeclaradas(unittest.TestCase):
    """Los nombres de subcarpeta que cada capa admite.

    Lo que este chequeo cierra es la puerta de atrás —inventar `ui/pantallas/` en vez de usar el
    criterio— y el archivo tirado en la raíz que nadie clasificó. Lo que **no** contesta es si un
    archivo está en la carpeta *correcta*: eso es semántica, ninguna herramienta lo puede decidir,
    y lo mira la revisión.
    """

    def test_una_carpeta_inventada_es_un_hallazgo(self):
        # La tupla entera y no sólo el largo de la lista: si la carpeta no está en el hallazgo, el
        # reporte del gate no la puede nombrar y quien lo sufre no sabe qué renombrar.
        self.assertEqual(
            carpetas_no_declaradas({"src/ui/pantallas/x.gd": ""}, CAPAS, CARPETAS),
            [("src/ui/pantallas/x.gd", "src/ui", "pantallas")],
        )

    def test_una_subcarpeta_declarada_no_es_un_hallazgo(self):
        self.assertEqual(carpetas_no_declaradas({"src/ui/diegetica/x.gd": ""}, CAPAS, CARPETAS), [])

    def test_la_raiz_de_una_capa_es_valida_a_proposito(self):
        # `hud.gd`, `reglas.gd`, `almacen.tscn`: los que cruzan dos carpetas, o los que son la
        # raíz. El gate los admite, y por eso NO frena a un archivo que nadie clasificó.
        self.assertEqual(carpetas_no_declaradas({"src/ui/hud.gd": ""}, CAPAS, CARPETAS), [])

    def test_un_nivel_y_no_mas(self):
        # El caso que decide la forma de la función: sin él, `carpetas_no_declaradas` puede mirar
        # sólo el primer segmento y dejar pasar `ui/diegetica/pantallas/`.
        self.assertEqual(
            carpetas_no_declaradas({"src/ui/diegetica/sub/x.gd": ""}, CAPAS, CARPETAS),
            [("src/ui/diegetica/sub/x.gd", "src/ui", "diegetica/sub")],
        )

    def test_lo_que_no_esta_en_ninguna_capa_no_participa(self):
        archivos = {"addons/gdUnit4/plugin.gd": ""}
        self.assertEqual(carpetas_no_declaradas(archivos, CAPAS, CARPETAS), [])

    def test_normaliza_las_barras_de_windows(self):
        # Mismo motivo que en `capa_de`: en Windows el walk devuelve `src\\ui\\pantallas\\x.gd`, y
        # sin normalizar el gate no ve ni una sola carpeta inventada — en verde.
        archivos = {ntpath.join("src", "ui", "pantallas", "x.gd"): ""}
        self.assertEqual(
            carpetas_no_declaradas(archivos, CAPAS, CARPETAS),
            [("src/ui/pantallas/x.gd", "src/ui", "pantallas")],
        )


class CarpetasQueElDominioAdmite(unittest.TestCase):
    """Los seis nombres que `src/dominio` declara, contra la constante **de producción**.

    Ésta es la diferencia con `CarpetasNoDeclaradas`, y es deliberada: aquélla ejerce la
    **función** y por eso usa un fixture propio; ésta ejerce el **dato**, así que tiene que leer
    `CARPETAS_POR_CAPA` de `lib/repo.py` o no verifica nada. Con el fixture, agregar un nombre al
    repo y olvidarse de declararlo pasaría en verde.

    El dominio es la única capa con un test así, y por el motivo que le da su spec: es la que se
    multiplica por 3,4 —los 44 archivos nuevos que traen los specs propuestos, sobre los 18 que
    hay hoy— y la única donde la clasificación es una decisión de diseño y no una consecuencia de
    dónde vive el archivo.
    """

    def test_declara_las_seis_carpetas(self):
        self.assertEqual(
            CARPETAS_POR_CAPA["src/dominio"],
            frozenset({"jugador", "jornada", "empleo", "almacen", "investigacion", "ambiente"}),
        )

    def test_investigacion_es_una_carpeta_valida_del_dominio(self):
        # La mitad de la tensión central del juego. `sistemas/` ya tenía `investigacion/`; que el
        # dominio no la tuviera dejaba a `pista.gd` sin lugar mientras
        # `registro_de_investigacion.gd` —lo que la guarda— sí tenía el suyo.
        archivos = {"src/dominio/investigacion/pista.gd": ""}
        self.assertEqual(carpetas_no_declaradas(archivos, CAPAS, CARPETAS_POR_CAPA), [])

    def test_una_carpeta_inventada_del_dominio_sigue_siendo_un_hallazgo(self):
        # La otra mitad del AC3, y la que hace falta para que la de arriba signifique algo: sin
        # ésta, un `CARPETAS_POR_CAPA` que admitiera cualquier nombre pasaría igual.
        archivos = {"src/dominio/objetos/x.gd": ""}
        self.assertEqual(
            carpetas_no_declaradas(archivos, CAPAS, CARPETAS_POR_CAPA),
            [("src/dominio/objetos/x.gd", "src/dominio", "objetos")],
        )


#: Los siete usos de motor que la tabla de `.claude/rules/dominio.md` enumera, uno por fila.
#:
#: Están en una constante porque los ejercen dos tests que se contestan entre sí —en la capa pura
#: cada uno es un hallazgo, y en las otras tres ninguno lo es—, y escritos dos veces el día que
#: se agregue el octavo entraría en una sola de las dos listas, con la mitad en verde.
USOS_DE_MOTOR = (
    "func _process(delta: float) -> void:\n",
    "get_tree()\n",
    'get_node("X")\n',
    "$Camara\n",
    "await get_tree().create_timer(1.0).timeout\n",
    'Input.is_action_pressed("x")\n',
    'print("x")\n',
)


class Impurezas(unittest.TestCase):
    """`impurezas()`: que la capa pura sea pura, que es de lo que cuelga poder testear el juego.

    Los casos son entrada sintética a propósito. Los 18 `.gd` que hoy tiene `src/dominio/` son
    puros, así que el rojo no se puede fabricar con el árbol real sin ensuciarlo — y un gate que
    nunca se vio en rojo no demostró que sabe ver el defecto, sólo que sabe callarse.
    """

    def test_extends_node_es_un_hallazgo(self):
        # 012-AC1. Se afirma la tupla entera y no el largo de la lista: sin la línea y sin el
        # patrón, el reporte del gate no puede nombrar qué hay que arreglar, y un gate que dice
        # «hay algo mal» sin decir dónde se termina apagando.
        self.assertEqual(
            impurezas({"src/dominio/x.gd": "extends Node\n"}, CAPAS),
            [("src/dominio/x.gd", 1, "extends Node")],
        )

    def test_la_lista_blanca_del_extends_tiene_tres_entradas(self):
        # 012-AC2. Los dos tipos puros del motor y un `class_name` del propio dominio.
        dominio = {"src/dominio/turno.gd": "class_name Turno\nextends RefCounted\n"}
        for texto in ("extends RefCounted\n", "extends Resource\n", "extends Turno\n"):
            with self.subTest(texto=texto):
                self.assertEqual(impurezas({**dominio, "src/dominio/x.gd": texto}, CAPAS), [])

    def test_un_class_name_de_otra_capa_no_esta_en_la_lista_blanca(self):
        # La otra mitad de la de arriba, y sin ella la lista blanca sería «cualquier `class_name`
        # del proyecto»: `Hud` extiende `Control`, así que heredarlo mete la escena adentro del
        # dominio por la puerta que ningún `preload` deja ver.
        archivos = {"src/dominio/x.gd": "extends Hud\n", "src/ui/hud.gd": "class_name Hud\n"}
        self.assertEqual(
            impurezas(archivos, CAPAS), [("src/dominio/x.gd", 1, "extends Hud")]
        )

    def test_los_siete_usos_de_motor_son_hallazgos(self):
        # 012-AC3. Uno por fila de la tabla de `.claude/rules/dominio.md`: hasta hoy esa tabla
        # era prosa, y la prosa dura hasta el primer apuro.
        for texto in USOS_DE_MOTOR:
            with self.subTest(texto=texto):
                self.assertTrue(impurezas({"src/dominio/x.gd": texto}, CAPAS))

    def test_las_otras_tres_capas_no_participan(self):
        # 012-AC4. En `sistemas/`, `ui/` y `escenas/` un `Node` es correcto por definición.
        # Mirarlas convertiría al gate en un linter de GDScript, que es lo que NO es.
        for capa in ("src/sistemas", "src/ui", "src/escenas"):
            for texto in USOS_DE_MOTOR:
                with self.subTest(capa=capa, texto=texto):
                    self.assertEqual(impurezas({f"{capa}/x.gd": texto}, CAPAS), [])

    def test_extender_node_fuera_de_la_capa_pura_es_correcto(self):
        # 012-AC4, el lado del `extends`: `sistemas/` existe justamente para tener los `Node`.
        archivos = {"src/sistemas/reloj.gd": "extends Node\n", "src/ui/hud.gd": "extends Control\n"}
        self.assertEqual(impurezas(archivos, CAPAS), [])

    def test_un_comentario_y_un_string_no_son_impurezas(self):
        # 012-AC5. Un gate con falsos positivos se apaga: la única salida que le queda a quien lo
        # sufre es sacarlo del `verificar`.
        texto = '# ojo con get_tree() acá\nvar s := "extends Node"\n'
        self.assertEqual(impurezas({"src/dominio/x.gd": texto}, CAPAS), [])

    def test_la_limpieza_conserva_el_numero_de_linea(self):
        # 012-AC5, la mitad que hace útil a la otra: los comentarios y los strings se reemplazan
        # por espacios y no se borran. Si se borraran, el hallazgo de abajo diría «línea 1» y
        # mandaría a leer el comentario en vez del código.
        texto = '# ojo con get_tree() acá\nvar s := "extends Node"\nget_tree()\n'
        self.assertEqual(
            impurezas({"src/dominio/x.gd": texto}, CAPAS),
            [("src/dominio/x.gd", 3, "get_tree()")],
        )

    def test_el_extends_conserva_su_linea_debajo_de_un_docstring(self):
        # 012-AC5, sobre el `extends` y no sobre los patrones: los comentarios se reemplazan por
        # espacios, así que una sangría de `\s*` deja que el `^` enganche en la primera línea del
        # bloque y se lo coma entero. El hallazgo salía diciendo «línea 1» y mandaba a leer el
        # docstring. No lo tapa ningún otro caso: los 18 `.gd` del dominio declaran `class_name`
        # arriba del `extends`, y eso corta la corrida de espacios por accidente.
        texto = "## qué es esto\n## y por qué\nextends CharacterBody3D\n"
        self.assertEqual(
            impurezas({"src/dominio/x.gd": texto}, CAPAS),
            [("src/dominio/x.gd", 3, "extends CharacterBody3D")],
        )

    def test_un_descendiente_de_node_que_no_figura_en_ninguna_lista(self):
        # 012-AC6, y es el AC que separa este diseño del de lista negra. `CharacterBody3D` no
        # está escrito en el código del gate —la jerarquía de `Node` tiene cientos de clases y
        # crece con cada versión menor del motor—, y aun así es un hallazgo, porque lo que se
        # enumera es lo permitido. Una lista negra nace incompleta y falla DANDO VERDE.
        self.assertEqual(
            impurezas({"src/dominio/x.gd": "extends CharacterBody3D\n"}, CAPAS),
            [("src/dominio/x.gd", 1, "extends CharacterBody3D")],
        )
        listas = repr(lib.capas._EXTENDS_PUROS) + repr(lib.capas._USOS_DE_MOTOR)
        self.assertNotIn("CharacterBody3D", listas)

    def test_el_acceso_a_disco_es_un_hallazgo_por_cada_uno(self):
        # 012-AC7. Lo pidió el spec 019, que midió que hoy pasan. Un dominio que lee o escribe el
        # disco deja de poder ejercerse sin preparar un archivo, que es la misma pérdida que un
        # dominio que necesita un frame.
        texto = 'FileAccess.open("x")\nConfigFile.new()\nResourceSaver.save(y)\n'
        self.assertEqual(
            impurezas({"src/dominio/x.gd": texto}, CAPAS),
            [
                ("src/dominio/x.gd", 1, "FileAccess"),
                ("src/dominio/x.gd", 2, "ConfigFile"),
                ("src/dominio/x.gd", 3, "ResourceSaver"),
            ],
        )

    def test_un_callback_no_matchea_adentro_de_otro_nombre(self):
        # Sin `func` adelante y sin límite de palabra atrás, `_process` matchea adentro de
        # `_procesar_venta` y el gate empieza a mentir sobre código correcto — que es la forma
        # más rápida de que alguien lo saque de `verificar.py`.
        texto = "func _procesar_venta(v: int) -> void:\n\tvar _procesos := 1\n"
        self.assertEqual(impurezas({"src/dominio/x.gd": texto}, CAPAS), [])


class LosDosFalsificadoresVivosDeLaLimpieza(unittest.TestCase):
    """`Input.` adentro de un comentario, en dos archivos REALES de `src/dominio/`.

    Son mejor evidencia que cualquier fixture: existen, están commiteados y son correctos. Sin
    `_sin_comentarios_ni_strings()` el gate nace rojo sobre ellos el día que se enciende, y un
    gate que nace rojo sobre código correcto no llega a la semana.

    Éste es el único test de este archivo que lee el disco, y lee las constantes de producción a
    propósito: lo que ejerce no es la función sino que el árbol de verdad la pase.
    """

    RUTAS = ("src/dominio/jugador/control_del_jugador.gd", "src/dominio/jugador/caminata.gd")

    def test_los_dos_nombran_input_en_un_comentario(self):
        # 012-AC5. Si algún día dejan de nombrarlo, el test de abajo pasa a no falsificar nada y
        # hay que decirlo acá y no descubrirlo cuando el gate empiece a mentir.
        for ruta in self.RUTAS:
            with self.subTest(ruta=ruta):
                self.assertRegex((RAIZ / ruta).read_text(encoding="utf-8"), r"#[^\n]*Input\.")

    def test_y_aun_asi_el_dominio_que_ya_existe_es_puro(self):
        # 012-AC5.
        archivos = {r: (RAIZ / r).read_text(encoding="utf-8") for r in self.RUTAS}
        self.assertEqual(impurezas(archivos, CAPAS_DEL_REPO), [])


if __name__ == "__main__":
    unittest.main()
