"""Reparte los `NNN` de un lote de specs, de una vez y desde un solo lugar.

Uso, desde cualquier lado —la raíz sale de `__file__`, no del CWD—:

    python .claude/skills/spec-create-batch/scripts/numeros.py        # el censo, nada más
    python .claude/skills/spec-create-batch/scripts/numeros.py 4      # el censo + 4 números

El SKILL.md lo **inyecta sin argumentos** al cargar, así que el censo llega con el skill ya
puesto. Con un número, además reserva.

## Por qué esto es un script y no una mirada al mapa

Escribir un spec suelto dice «el número se reserva tarde: mirá `specs/mapa.json` recién cuando
vayas a crear la carpeta, porque si hay otra sesión en paralelo el número que elegiste al empezar
ya no es tuyo».

En un lote, **esa regla no se puede cumplir**: los N agentes escriben a la vez, y si cada uno
mira el mapa cuando le toca, los N ven el mismo último número y eligen el mismo siguiente. La
colisión no da error —son carpetas distintas hasta que alguien las compara— y aparece recién en
`publicar_spec.py crear`, con la mitad del lote ya escrita.

La salida es la contraria a la del spec suelto: **el número se reserva temprano y lo reserva el
padre**, una sola vez, antes de lanzar a nadie. Este script es esa reserva.

## Por qué no se rellenan los huecos

Un `NNN` que estuvo ocupado no vuelve a estar libre aunque su spec se haya descartado y su
carpeta ya no esté. El número aparece en ramas, en commits, en comentarios de issues y en las
citas de otros specs; reusarlo vuelve ambiguas todas esas referencias **sin romper nada**, que es
la clase de daño que no se descubre. Se cuenta siempre desde el máximo hacia arriba.
"""

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[4]

# `configurar()` va antes de imprimir nada: la salida de este script va a una tubería —así la lee
# un agente— y en esta máquina eso es cp1252, donde no entra ni una tilde.
sys.path.insert(0, str(RAIZ / ".claude" / "scripts"))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.specs import leer_mapa  # noqa: E402

SPECS = RAIZ / "specs"
CARPETA = re.compile(r"^(\d{3})-[a-z0-9-]+$")


def main() -> None:
    cuantos = 0
    for a in sys.argv[1:]:
        if re.fullmatch(r"\d+", a):
            cuantos = int(a)
        else:
            print(f"uso: numeros.py [cuantos]  (no reconozco «{a}»)", file=sys.stderr)
            sys.exit(2)

    mapa = leer_mapa((SPECS / "mapa.json").read_text(encoding="utf-8"))
    en_disco = {
        m.group(1): d.name for d in SPECS.iterdir() if d.is_dir() and (m := CARPETA.match(d.name))
    }

    ocupados = sorted(set(mapa) | set(en_disco))

    print("== censo de numeros ==")
    if not ocupados:
        print("  el registro esta vacio: el lote arranca en 001.")
    else:
        print(f"  ocupados: {len(ocupados)}, de {ocupados[0]} a {ocupados[-1]}")

    # Una carpeta en disco sin fila en el mapa es un spec **escrito y sin publicar**. Su número
    # ya está tomado aunque el registro no lo sepa, y decirlo importa por dos motivos opuestos:
    # repartirlo otra vez pisa trabajo de alguien, y no publicarlo lo deja fuera del registro
    # para siempre — la carpeta está en el `.gitignore`, así que no viaja en ningún commit.
    huerfanas = sorted(n for n in en_disco if n not in mapa)
    if huerfanas:
        print()
        print("  OJO: en disco y sin fila en mapa.json — specs escritos y sin publicar:")
        for n in huerfanas:
            print(f"    {n}  {en_disco[n]}")
        print("    Su numero cuenta como ocupado igual. Si son tuyos, falta `publicar_spec.py crear`.")

    # Una fila en el mapa sin carpeta en disco es sólo un spec sin hidratar: normal, y no es un
    # aviso. No se lista, para no enseñar a ignorar los avisos de este bloque.

    if not cuantos:
        return

    desde = int(ocupados[-1]) + 1 if ocupados else 1
    print()
    print(f"== {cuantos} numeros reservados ==")
    for n in range(desde, desde + cuantos):
        if n > 999:
            print("  se acabaron los tres digitos. Eso es una decision, no un bug de este script.")
            sys.exit(1)
        print(f"  {n:03d}")


if __name__ == "__main__":
    main()
