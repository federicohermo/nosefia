from pathlib import Path
r=Path.cwd(); s=Path(__file__).parent
for archivo,borrador in [
    ("test/dominio/almacen/tarea_de_la_basura_test.gd","370-test-dominio.gd"),
    ("test/sistemas/tareas/recolector_de_basura_test.gd","370-test-sistema.gd"),
]:
    p=r/archivo; texto=p.read_text(encoding="utf-8")
    argumento="jornada" if "/sistemas/" in archivo else "2"
    texto=texto.replace("TareaDeLaBasura.de_la_jornada()",f"TareaDeLaBasura.de_la_jornada({argumento})")
    p.write_text(texto+s.joinpath(borrador).read_text(encoding="utf-8"),encoding="utf-8",newline="\n")
p=r/"src/dominio/almacen/tarea_de_la_basura.gd"; t=p.read_text(encoding="utf-8")
t=t.replace("enum Resultado", "enum Tacho { LOCAL, ESCRITORIO, BANO }\n\nenum Resultado")
t=t.replace("func de_la_jornada()", "func de_la_jornada(_jornada: int = 1)")
t+="""


func tiene_bolsa(_tacho: Tacho) -> bool:
\treturn false


func sacar(_tacho: Tacho, _mano_vacia: bool) -> StringName:
\treturn ObjetoDelAlmacen.SIN_ID
"""
p.write_text(t,encoding="utf-8",newline="\n")
p=r/"src/sistemas/tareas/recolector_de_basura.gd"; t=p.read_text(encoding="utf-8")
t=t.replace("signal bolsa_depositada", "signal bolsa_sacada(tacho: TareaDeLaBasura.Tacho)\n\nsignal bolsa_depositada")
t=t.replace("@export var repositor: Repositor", "@export var repositor: Repositor\n@export var bolsas: Array[Node3D] = []")
t+="""


func sacar_bolsa(_tacho: TareaDeLaBasura.Tacho) -> bool:
\treturn false
"""
p.write_text(t,encoding="utf-8",newline="\n")
