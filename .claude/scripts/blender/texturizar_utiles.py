"""Hornea en una sola textura el detalle del balde y de la mopa: oclusión, bordes, uso y hebras.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_utiles.py -- [--aplicar]

Sin `--aplicar` deja la textura en la carpeta temporal y no guarda nada. Con `--aplicar` escribe
`TEXTURA` y guarda la fuente canónica. Después va `exportar_modelo.py`.

## Por qué

El balde y la mopa eran colores lisos: en el cuartito, contra los bloques con relieve, se leían
como juguetes. El detalle va horneado en el color, como el bisel de las etiquetas, porque la luz
del juego no deja brillo que un mapa de relieve pueda mover.

## Qué cambia

- Los dos objetos ganan una UV, la mitad izquierda de la textura para el balde y la derecha para
  la mopa. La geometría no se toca.
- Cada cara guarda su color original en el atributo `ranura_original`, y de ahí se hornea: correrlo de
  nuevo da la misma textura.
- Las ranuras que el juego pinta con el mismo shader se unen. El color ya viaja en la textura, y
  cada ranura es un dibujo más. Los nombres que el juego busca siguen estando.
"""

import sys
import tempfile
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import detalle_horneado as detalle  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

TEXTURA = RAIZ / "assets/source/textures/props/utiles_de_limpieza.png"
LADO = 1024
MARGEN = 6

#: El color liso que tenía cada material, en lineal. Es la base de lo que se hornea.
COLORES = {
    "util_plastico_azul": (0.036, 0.165, 0.34),
    "util_plastico_claro": (0.06, 0.23, 0.42),
    "util_borde_crema": (0.72, 0.73, 0.69),
    "util_asa_grafito": (0.085, 0.105, 0.12),
    "util_mango_acero": (0.36, 0.42, 0.45),
    "util_fibra_cruda": (0.72, 0.7, 0.62),
    "util_fibra_sombra": (0.58, 0.57, 0.5),
}
FIBRAS = ("util_fibra_cruda", "util_fibra_sombra")

#: Qué ranura absorbe a cuál en cada objeto, y en qué mitad de la textura cae su UV.
OBJETOS = {
    "balde-col": {"une": {"util_asa_grafito": "util_borde_crema"}, "columna": 0},
    "mopa-col": {
        "une": {"util_asa_grafito": "util_plastico_azul", "util_fibra_sombra": "util_fibra_cruda"},
        "columna": 1,
    },
}


def desplegar_por_costuras(objeto, columna: int, columnas: int, lado: int, margen: int) -> None:
    """Despliega `balde-col` respetando sus costuras limpias de material y cilindro."""
    malla = objeto.data
    while malla.uv_layers:
        malla.uv_layers.remove(malla.uv_layers[0])
    malla.uv_layers.new(name="UVMap")
    bpy.ops.object.select_all(action="DESELECT")
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.045)
    bpy.ops.object.mode_set(mode="OBJECT")
    borde = margen / lado
    for dato in malla.uv_layers[0].data:
        dato.uv.x = (columna + borde + dato.uv.x * (1 - 2 * borde)) / columnas
        dato.uv.y = borde + dato.uv.y * (1 - 2 * borde)


def pintar(base, forma, uso, altura, es_balde: bool = False) -> np.ndarray:
    """El color final, en lineal, desde las capas horneadas."""
    oclusion, arista, grano = forma[..., 0:1], forma[..., 1:2], forma[..., 2:3]
    manchas, hebras, rayones = uso[..., 0:1], uso[..., 1:2], uso[..., 2:3]
    alto = altura[..., 2:3]
    es_fibra = np.zeros(base.shape[:2] + (1,), dtype=bool)
    for nombre in FIBRAS:
        es_fibra |= np.abs(base - np.array(COLORES[nombre])).sum(axis=2, keepdims=True) < 0.02

    if es_balde:
        # Desgaste físicamente motivado de balde de comercio: sin ruido pixelado tipo estática;
        # marca de agua interior, roce de piso en el pie, escurridos desde el aro y uso en el agarre.
        dx = (altura[..., 0:1] - 0.5) * 0.421
        dy = (altura[..., 1:2] - 0.5) * 0.390
        radio_xy = np.hypot(dx, dy)
        en_interior = (radio_xy < 0.1755) & (alto < 0.62)
        en_exterior = (~en_interior) & (alto < 0.61)
        en_aro = (alto >= 0.60) & (alto <= 0.68)
        en_agarre = alto > 0.88

        # Base plástica lisa con AO en pliegues y variación tonal suave (sin grano 1-px).
        ao = np.clip(oclusion, 0, 1)
        luz = 0.56 + 0.44 * (ao ** 1.3)
        plastico = base * luz * (0.95 + 0.09 * manchas)

        # Mugre atrapada en recovecos profundos (bajo el labio del aro y junto a bisagras).
        rincon = np.clip((1.0 - ao - 0.16) * 2.0, 0, 1) ** 1.4
        tinte_rincon = np.array([0.045, 0.046, 0.040], dtype=np.float32)
        plastico = plastico * (1.0 - 0.50 * rincon) + tinte_rincon * (0.50 * rincon)

        # Interior: línea de agua turbia + sedimento mineral abajo + aureola seca de jabón.
        nivel_agua = 0.36 + 0.045 * (manchas - 0.5)
        bajo_agua = np.clip((nivel_agua - alto) * 9.0, 0, 1) * en_interior
        fondo_int = np.clip(1.0 - alto * 3.6, 0, 1) * en_interior
        tinte_agua = np.array([0.040, 0.056, 0.064], dtype=np.float32)
        peso_agua = np.clip(bajo_agua * (0.28 + 0.22 * manchas) + fondo_int * 0.28, 0, 0.60)
        plastico = plastico * (1.0 - peso_agua) + tinte_agua * peso_agua
        anillo_jabon = np.exp(-(((alto - nivel_agua) / 0.024) ** 2)) * en_interior
        anillo_jabon = anillo_jabon * np.clip((manchas - 0.28) * 1.8, 0.30, 1.0)
        tinte_jabon = np.array([0.36, 0.40, 0.40], dtype=np.float32)
        plastico = plastico * (1.0 - 0.30 * anillo_jabon) + tinte_jabon * (0.30 * anillo_jabon)

        # Exterior bajo: polvo y arrastre sobre concreto + cantos gastados en el aro inferior.
        zona_piso = np.clip((0.28 - alto) / 0.28, 0, 1) ** 1.25 * en_exterior
        mugre_piso = zona_piso * np.clip(0.42 + 0.85 * manchas, 0, 1)
        tinte_piso = np.array([0.042, 0.048, 0.046], dtype=np.float32)
        plastico = plastico * (1.0 - 0.52 * mugre_piso) + tinte_piso * (0.52 * mugre_piso)
        roce_bajo = np.clip(arista * 4.4, 0, 1) * np.clip((0.28 - alto) / 0.28, 0, 1)
        tinte_roce = np.array([0.30, 0.38, 0.44], dtype=np.float32)
        plastico = plastico * (1.0 - 0.42 * roce_bajo) + tinte_roce * (0.42 * roce_bajo)

        # Escurridos verticales y roces suaves en la pared exterior.
        zona_escurrido = np.clip((alto - 0.22) / 0.38, 0, 1) * en_exterior
        gotas = np.clip((hebras - 0.56) * 5.0, 0, 1) * np.clip((manchas - 0.42) * 3.0, 0, 1)
        plastico = plastico * (1.0 - 0.30 * gotas * zona_escurrido)
        roces_ext = np.clip((np.abs(rayones - 0.5) - 0.24) * 18.0, 0, 1) * np.clip(
            (manchas - 0.46) * 3.5, 0, 1
        ) * en_exterior
        tinte_roce_ext = np.array([0.24, 0.34, 0.42], dtype=np.float32)
        plastico = plastico * (1.0 - 0.22 * roces_ext) + tinte_roce_ext * (0.22 * roces_ext)

        # Aro blanco y agarre superior: roce de mopa en el labio y oscurecimiento por mano en el centro.
        roce_aro = np.clip((manchas - 0.46) * 2.6, 0, 1) * en_aro
        tinte_roce_aro = np.array([0.40, 0.41, 0.38], dtype=np.float32)
        plastico = plastico * (1.0 - 0.26 * roce_aro) + tinte_roce_aro * (0.26 * roce_aro)
        centro_mano = np.exp(-((dx / 0.042) ** 2)) * en_agarre
        mano_uso = centro_mano * (0.65 + 0.35 * manchas)
        tinte_mano = np.array([0.42, 0.42, 0.38], dtype=np.float32)
        plastico = plastico * (1.0 - 0.32 * mano_uso) + tinte_mano * (0.32 * mano_uso)

        # Cantos vivos generales con leve brillo de desgaste plástico.
        canto = np.clip(arista * 3.5, 0, 1)
        plastico = plastico + (np.minimum(plastico * 1.32 + 0.025, 1) - plastico) * canto * 0.28
    else:
        luz = 0.5 + 0.5 * np.clip(oclusion, 0, 1) ** 1.3
        plastico = base * luz * (0.93 + 0.14 * grano)
        suciedad = np.clip((manchas - 0.48) * 4, 0, 1) * np.clip(1 - alto * 3.2, 0, 1)
        velo = np.clip((manchas - 0.58) * 5, 0, 1) * 0.35
        plastico = plastico * (1 - 0.55 * np.maximum(suciedad, velo))
        raya = np.clip((np.abs(rayones - 0.5) - 0.2) * 25, 0, 1) * np.clip((manchas - 0.4) * 4, 0, 1)
        plastico = plastico + (0.55 - plastico) * raya * 0.35
        canto = np.clip(arista * 5, 0, 1)
        plastico = plastico + (np.minimum(plastico * 1.7 + 0.05, 1) - plastico) * canto * 0.7

    fibra = base * (0.45 + 0.55 * np.clip(oclusion, 0, 1)) * (0.62 + 0.76 * hebras)
    return np.clip(np.where(es_fibra, fibra, plastico), 0, 1)


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    antes = detalle.preparar_cycles()
    color = np.zeros((LADO, LADO, 3), dtype=np.float32)
    for nombre, datos in OBJETOS.items():
        objeto = bpy.data.objects[nombre]
        originales = detalle.guardar_ranuras(objeto.data, COLORES)
        if nombre == "balde-col":
            desplegar_por_costuras(objeto, datos["columna"], len(OBJETOS), LADO, MARGEN)
        else:
            detalle.desplegar(objeto, datos["columna"], len(OBJETOS), LADO, MARGEN)
        copia = detalle.copia_con_color(objeto, [COLORES[nombre_] for nombre_ in originales])
        capas = detalle.capas(copia, LADO, MARGEN)
        detalle.descartar(copia)
        mitad = slice(datos["columna"] * LADO // 2, (datos["columna"] + 1) * LADO // 2)
        color[:, mitad] = pintar(*capas, es_balde=(nombre == "balde-col"))[:, mitad]
        detalle.unir_ranuras(objeto, originales, datos["une"])
        print(f"{nombre}: {len(originales)} caras horneadas")
    detalle.restaurar(antes)
    destino = TEXTURA if aplicar else Path(tempfile.gettempdir()) / TEXTURA.name
    detalle.escribir(color, destino)
    print(f"textura: {destino}")
    if aplicar:
        detalle.cablear(destino, COLORES)
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
