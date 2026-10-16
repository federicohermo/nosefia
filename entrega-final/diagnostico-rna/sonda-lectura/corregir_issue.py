import json
from pathlib import Path

base = Path(__file__).resolve().parent
data = json.loads((base / "issue-434-actual02.json").read_text(encoding="utf-8"))
body = data["body"]


def cambiar(viejo, nuevo):
    global body
    assert body.count(viejo) == 1, viejo
    body = body.replace(viejo, nuevo)


cambiar("El head de este carril es `c90d1523e51816813702a27c3ae6f994f9233d5f`.",
        "El head histórico del carril al detectar esta colisión era "
        "`c90d1523e51816813702a27c3ae6f994f9233d5f`; no describe la cabeza actual.")
cambiar("- [ ] ~~Duronga sólo depósito~~ **Obsoleto (Tiago 2026-10-15):** Duronga **sí** tiene copias/guías/casilleros en góndolas según el mapa (destino provisional del dibujo). Su caja del depósito mantiene ocho unidades. El dato detallado «Solo está en su caja…» queda subordinado al comentario del Mapa de góndolas hasta que se reemplace el producto.",
        "- [ ] Duronga conserva copias, guías y casilleros en góndolas según el destino provisional del mapa (decisión de Tiago del 2026-10-15). Su caja del depósito mantiene ocho unidades. El dato detallado «Solo está en su caja…» queda subordinado a esa decisión del Mapa de góndolas hasta el reemplazo futuro del producto.")
cambiar("- [ ] ~~Cero casilleros de Duronga~~ **Obsoleto:** Duronga tiene cupo/casilleros en góndola como el resto de exhibibles. No se renumera `Producto.Id`. Productos «sólo depósito» (si los hubiera en el futuro) siguen siendo estado válido del generador; Duronga ya no es ese caso.",
        "- [ ] Duronga tiene cupo y casilleros en góndola como los otros productos exhibidos. No se renumera `Producto.Id`. El generador conserva como capacidad separada la posibilidad de un futuro producto sólo-depósito; Duronga no usa ese estado.")
start = body.index("### Ajuste a criterios (post-verificación + comentario Tiago)")
end = body.index("## Contrato", start)
body = body[:start] + """### Decisiones vigentes que delimitan los criterios

- **Duronga exhibible:** permanece en el destino provisional del mapa hasta su reemplazo futuro. Tiene tanda principal, referencias fijas, cupo y casilleros como los demás productos exhibidos; no se le fuerza un bloque vacío. Su caja sigue teniendo ocho unidades.
- **Cuatro niveles interactuables:** se conservan las cuatro chapas existentes. Las tandas fijas de los niveles 0 y 3 mantienen sus unidades y su interacción; las principales de 1 y 2 conservan la reposición. Los casilleros totales suman frontales principales y fijas; el sorteo de apertura de #367 usa sólo frontales principales. Esto no cambia alturas ni resuelve OQ-STK-007.
- Se conservan Cindolor en la segunda heladera, Oaaaa/Terminator en la cabecera de bebidas sin refrigerar y el cruce completo de sectores por `Producto.Id`.
- **OQ-STK-008 está resuelta:** Actroncito y Prongles conservan sus dos hileras ya existentes; rigen la lista de cinco y las excepciones por tanda detalladas arriba. No queda una decisión de filas pendiente ni se exige una conversión universal a dos filas.
- El destino de Duronga procede del mapa y la decisión citada, no de una heurística del generador. La capacidad futura de admitir productos sólo-depósito no cambia la exhibición actual de Duronga.

""" + body[end:]
cambiar("- **Recursos:** `DisposicionDeLaGondola` conserva listas indexadas por los 32 IDs. Duronga tiene bloque vacío y cero filas de adelante; no aporta guía. Sus consultas de cupo devuelven cero. Ningún acceso calcula un índice negativo ni fuerza una exhibición para ese producto.",
        "- **Recursos:** `DisposicionDeLaGondola` conserva listas indexadas por los 32 IDs. Duronga tiene bloques, principal, guías y casilleros derivados de su exhibición provisional; sus consultas devuelven ese cupo real. Por separado, un futuro producto declarado sólo-depósito puede tener listas vacías y cupo cero sin accesos a índices negativos. Esa capacidad no se aplica a Duronga.")
cambiar("- **Generación/puesto:** `disponer.py` permite cero tandas con casilleros sólo para el producto declarado de depósito. Sigue generando su malla fuente, datos y recurso de producto porque sacar de la caja y vender lo requieren. `reposicion_manual.gd` omite la construcción de casilleros/bloques visibles para cupo cero y conserva la creación de unidades que salen de cajas.",
        "- **Generación/puesto:** `disponer.py` exige la tanda principal de Duronga y deriva sus casilleros reales. La posibilidad de cero tandas se reserva a productos declarados explícitamente sólo-depósito, si se incorporan en el futuro. Para ellos conserva malla fuente, datos y recurso exportable; `reposicion_manual.gd` puede omitir bloques de cupo cero y seguir creando unidades desde cajas. No se vacía la exhibición de Duronga para ejercer esa capacidad.")
start = body.index("### Corrección de Límites (post-verificación)")
end = body.index("## Verificación", start)
body = body[:start] + body[end:]
body += """
### Diagnóstico de idempotencia del generador (sin cambio de diseño)

La primera regeneración y su repetición no produjeron textos byteidénticos. Se conservan los hashes originales, ambas exportaciones GLB, el backup candidato de la primera fuente y todos los outputs de la segunda. No se afirman recuperados los textos originales que no fueron copiados.

Una sonda Blender de sólo lectura sobre fuente original, backup y segunda fuente midió realimentación de la escala al descomponer `matrix_world` y volver a usar `to_scale()`. La corrección mecánica queda acotada al acomodador y su espejo: conservar la escala local original del artista en las lecturas y escrituras de colocación sobre los marcos rígidos medidos. No cambia redondeos globales, geometría, UV, materiales, columnas, alturas, ángulos ni el contrato de filas aprobado. No introduce metadatos ocultos.

La validación debe repetir la generación desde la fuente original y conservar TODAS las salidas de ambas pasadas por separado (cuatro textos, 32 RES, blend, GLB, huella y caché), antes de comparar sus hashes. Los textos y RES siguen requiriendo igualdad estricta de bytes; una diferencia residual del GLB exige análisis semántico documentado y no se oculta mediante tolerancias. Este diagnóstico no acredita todavía la regeneración completa ni altera las decisiones o restricciones anteriores. El TDD funcional compara el acomodador anterior c780 con la corrección sobre la misma fuente y exige estabilidad exacta de escala y matrices RNA.
"""
assert "sigue bloqueando" not in body
assert "Duronga tiene bloque vacío" not in body
assert "Su[s] consultas" not in body
(base / "issue434-idempotencia-WHOLE-coherente.md").write_bytes(body.encode("utf-8"))
