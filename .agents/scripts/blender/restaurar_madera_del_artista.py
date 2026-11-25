"""Devuelve el mostrador, su compuerta y el friso a la malla del artista.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/restaurar_madera_del_artista.py -- [--aplicar]

Sin `--aplicar` cambia sólo la sesión de Blender. Con `--aplicar` guarda el `.blend`. Después va
`listonar_frente_de_madera.py`.

## Por qué

Los listones en geometría sumaban más de dos mil triángulos, y el usuario los quiere en la
textura. La malla del artista es una caja por frente, con el zócalo de acero abajo. El `.blend`
de `47e971e7` la tiene intacta.

## Qué cambia

- `EscritorioComputadora-col`, `compuerta_mostrador` y `mueble_continuo` vuelven a la malla de
  `47e971e7`. Vuelve también el zócalo de acero del mostrador.
- Las caras toman los materiales de este `.blend` por nombre: el frente sigue con su imagen.
- Lo que la carga trajo y quedó sin uso se borra.

## Lo que cuesta

Nada: resta 2.394 triángulos. Saca el `.blend` de la historia con `git` a `build/madera/`. Una
malla que ya es la del artista no se toca.
"""

import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
COMMIT = "47e971e7"
MODELO = "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
FUENTE = RAIZ / "build" / "madera" / f"artista_{COMMIT}.blend"
#: El objeto y el nombre de su malla en la fuente.
OBJETOS = {
    "EscritorioComputadora-col": "Mostrador_L_recto_altura_115",
    "compuerta_mostrador": "Compuerta del mostrador",
    "mueble_continuo": "mueble_continuo",
}


def sacar_fuente() -> None:
    if FUENTE.exists():
        return
    FUENTE.parent.mkdir(parents=True, exist_ok=True)
    datos = subprocess.check_output(["git", "show", f"{COMMIT}:{MODELO}"], cwd=RAIZ)
    FUENTE.write_bytes(datos)


def huella(malla) -> tuple:
    return tuple(tuple(round(c, 5) for c in v.co) for v in malla.vertices), tuple(
        tuple(p.vertices) for p in malla.polygons
    )


def main() -> None:
    import bpy  # type: ignore[import-not-found]

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from lib.consola import configurar

    configurar()
    sacar_fuente()
    antes = {k: set(getattr(bpy.data, k).keys()) for k in ("materials", "images", "meshes")}
    with bpy.data.libraries.load(str(FUENTE), link=False) as (_, cargado):
        cargado.meshes = list(OBJETOS.values())
    for (nombre, nombre_de_malla), nueva in zip(OBJETOS.items(), cargado.meshes):
        objeto = bpy.data.objects[nombre]
        vieja = objeto.data
        if huella(vieja) == huella(nueva):
            print(f"{nombre}: ya es la malla del artista")
            bpy.data.meshes.remove(nueva)
            continue
        for i, material in enumerate(nueva.materials):
            if material is not None and material.name not in antes["materials"]:
                nueva.materials[i] = bpy.data.materials[material.name.rsplit(".", 1)[0]]
        triangulos = sum(len(p.vertices) - 2 for p in vieja.polygons)
        objeto.data = nueva
        if vieja.users == 0:
            bpy.data.meshes.remove(vieja)
        nueva.name = nombre_de_malla
        despues = sum(len(p.vertices) - 2 for p in nueva.polygons)
        print(f"{nombre}: {triangulos} -> {despues} triángulos ({despues - triangulos:+d})")
    for clase in ("materials", "images"):
        coleccion = getattr(bpy.data, clase)
        for nombre in set(coleccion.keys()) - antes[clase]:
            if coleccion[nombre].users == 0:
                coleccion.remove(coleccion[nombre])
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
