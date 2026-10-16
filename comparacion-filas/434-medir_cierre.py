"""Cierra referencias superiores, Amargadito y alternativas de la lista histórica."""
import json
from pathlib import Path

scratch = Path("C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435")
anterior = scratch / "434-medir_patron_actual.py"
exec(compile(anterior.read_text(encoding="utf-8").split('\npatron = {')[0],
             str(anterior), "exec"), globals())


def instancias(clave, productos, desplazamiento, filas_forzadas=None):
    letra = clave.split(".")[0]
    objeto, bm, arbol, estantes = medidos[letra]
    e = estantes[clave]
    envases = [m.envase_de(m.producto(p), bpy.data.objects[m.producto(p).objeto]) for p in productos]
    inclinacion = m.inclinacion_de(e)
    alto = max(m.alto_en_la_rampa(envase, inclinacion) for envase in envases) - m.ROCE_DE_ARRIBA
    desde, hasta = m.franja_del_estante(e, arbol, alto)
    izquierda, derecha = m.tramo_util(e, arbol, desde, hasta)
    cuentas = m.repartir(derecha - izquierda, envases)
    us = m.centros(derecha - izquierda, envases, cuentas)
    for producto, envase, centros in zip(productos, envases, us):
        p = m.producto(producto)
        unidad = bpy.data.objects[p.objeto]
        filas = filas_forzadas.get(producto, 1 if producto in m.DE_UNA_FILA else 2)
        for lugar in m.tanda(envase, [izquierda + u for u in centros], inclinacion, filas):
            matriz = m.matriz_de(p, unidad, e, lugar.u, desde + lugar.v + desplazamiento)
            yield p, unidad, matriz, letra, e, lugar


casos = {
    "amargadito_principal_single": ("A.sur.1", ("AMARGADITO",), {"AMARGADITO": 1}),
    "amargadito_fija_double": ("A.sur.0", ("AMARGADITO",), {"AMARGADITO": 2}),
    "oaaaa_fija_single": ("A.norte.3", ("OAAAA",), {"OAAAA": 1}),
    "actroncito_doble_principal": ("N.sur.2", ("ACTRONCITO", "DUREXTRA"), {"ACTRONCITO": 2}),
    "actroncito_doble_fija": ("N.sur.0", ("ACTRONCITO", "DUREXTRA"), {"ACTRONCITO": 2}),
    "prongles_doble_principal": ("B.oeste.2", ("DONSATURADOS", "PRONGLES"), {"PRONGLES": 2}),
    "prongles_doble_fija": ("B.oeste.0", ("DONSATURADOS", "PRONGLES"), {"PRONGLES": 2}),
    "marranos_single_principal": ("A.oeste.1", ("UAKAS", "MARRANOS"), {"MARRANOS": 1}),
    "marranos_single_fija": ("A.oeste.3", ("UAKAS", "MARRANOS"), {"MARRANOS": 1}),
    "poetico_single_principal": ("N.sur.1", ("POETICO",), {"POETICO": 1}),
    "poetico_single_fija": ("N.sur.3", ("POETICO",), {"POETICO": 1}),
}
salida = {"casos": {}, "poetico_parcial_detras_panel": {}}
for nombre, (clave, productos, filas) in casos.items():
    resultado = barrer(clave, productos, filas)
    completos = [p for p in resultado["ensayos"] if p["valido"] and p["contactos_fuera"] == 0]
    resultado["mejor_completo"] = min(completos, key=lambda p: abs(p["desplazamiento"])) if completos else None
    resultado["cantidad_completos"] = len(completos)
    salida["casos"][nombre] = {"estante": clave, "productos": productos, "barrido": resultado}

for clave in ("N.sur.2", "N.sur.3"):
    _, bm, arbol, estantes = medidos["N"]
    e = estantes[clave]
    corte_panel = m.fondo_util(e, arbol, .0005)
    filas = []
    for p, unidad, matriz, letra, e, lugar in instancias(clave, ("POETICO",), .085, {"POETICO": 2}):
        puntos = [matriz @ v.co - e.origen for v in unidad.data.vertices]
        pies = [v for v in puntos if abs(v.dot(e.normal)) <= m.TOLERANCIA_DEL_PLANO]
        filas.append({"fila": lugar.fila, "columna": lugar.columna,
                      "cuerpo_v": [min(v.dot(e.v) for v in puntos), max(v.dot(e.v) for v in puntos)],
                      "contactos_v": [min(v.dot(e.v) for v in pies), max(v.dot(e.v) for v in pies)],
                      "contactos_fuera": sum(not 0 <= v.dot(e.v) <= e.fondo for v in pies),
                      "cuerpo_z": [min((v + e.origen).z for v in puntos),
                                   max((v + e.origen).z for v in puntos)]})
    paneles = []
    objeto = medidos["N"][0]
    for cara in bm.faces:
        material = objeto.material_slots[cara.material_index].material
        if material and "Panel" in material.name and abs(cara.normal.dot(e.v)) > .9:
            paneles.append({"indice": cara.index, "material": material.name,
                            "v": [min((v.co-e.origen).dot(e.v) for v in cara.verts),
                                  max((v.co-e.origen).dot(e.v) for v in cara.verts)],
                            "z": [min(v.co.z for v in cara.verts), max(v.co.z for v in cara.verts)]})
    salida["poetico_parcial_detras_panel"][clave] = {
        "desplazamiento": .085, "fondo_chapa": e.fondo, "corte_panel": corte_panel,
        "filas": filas, "paneles": paneles}
for _, bm, _, _ in medidos.values():
    bm.free()
(scratch / "434-cierre-geometrico.json").write_text(json.dumps(salida, indent=2), encoding="utf-8")
print(json.dumps({k: {"completos": v["barrido"]["cantidad_completos"],
                      "mejor": v["barrido"]["mejor_completo"]}
                  for k, v in salida["casos"].items()}, indent=2))
print("434_CIERRE_GEOMETRICO_MEDIDO_OK")
