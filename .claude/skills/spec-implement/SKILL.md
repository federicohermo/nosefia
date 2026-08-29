---
name: spec-implement
description: Especialización de /spec-implement para No se fía (Godot). El paralelismo viene declarado por tarea con [P], el TDD es obligatorio y verificado, y el nodo de convergencia es verificar.py. Se lee junto con el skill global.
---

# spec-implement — No se fía

Este archivo **no reemplaza** al skill global: aporta lo que en este repo es distinto. El
método, el fake-edge test y la convergencia salen de allá.

**No deja deuda**, y eso está en [`../sin-deuda.md`](../sin-deuda.md). Lo propio de implementar es
el lazo: **si acá aparece un problema de planteo, el defecto no es de este spec — es del skill que
lo dejó salir así**, y se corrigen los dos en esta corrida. Ver «Cuando el spec no alcanza», abajo.

## Antes de arrancar

**La rama la abrís vos, y es el primer movimiento.** `spec-create` deja el spec publicado y su
fila en `staging`, y nada más.

```bash
git checkout staging && git pull                      # ahí está la fila del spec
git checkout -b feature/<NNN>-<descripcion-kebab>     # de acá saca el número el gate
python .claude/scripts/hidratar_specs.py <NNN>        # specs/ es caché: hace falta en CADA worktree
```

**El nombre de la rama no es decorativo**: `feature/<NNN>-` es de donde el hook saca el número
del spec, y una rama con otro nombre bloquea la primera edición de `src/`.

Si el spec ya tiene rama, no la vuelvas a crear: puede haberla abierto otra sesión, y ahí lo
que corresponde es un worktree propio sobre esa rama.

**`specs/` está en el `.gitignore`.** Leerlos anda igual —`Read` y `cat` los abren— pero
**`Grep` no los ve**: es ripgrep y respeta el `.gitignore`, así que una búsqueda ahí devuelve
cero resultados **sin decir que no miró**. Para buscar en specs: `rg --no-ignore … specs/`.

## El paralelismo viene declarado — no lo derives de cero

El formato de tarea de este repo es:

```markdown
- [ ] T012 [P] Descripción, con la ruta del archivo que toca
```

- **`[P]`** — no depende de las otras `[P]` de su bloque ni comparte archivo con ellas. Lo
  escribió quien conocía las dependencias reales, al escribir el spec.
- **`T0NN`** — ID estable. Usalo para nombrar nodos y aristas en el `--dry`, que es lo que
  hace revisable el grafo antes de lanzar nada.

**Seguí usando el fake-edge test sobre los `[P]` declarados, no en su lugar.** Un `[P]` mal
puesto es un conflicto de escritura que aparece recién al implementar; si el test contradice a
la declaración, gana el test y **decilo** — es un hallazgo sobre el spec.

## El test va primero, y el gate lo verifica

Esto es lo que más cambia respecto de un repo cualquiera. En Godot **no hay cobertura**, así
que la disciplina no se sostiene sola: la sostienen cuatro reglas que
`python .claude/scripts/gate_de_tests.py` verifica, y que están explicadas con su modo de
falla en `.claude/scripts/lib/tdd.py`.

En la práctica, para cada tarea que toca `src/dominio/` o `src/sistemas/`:

1. **Escribí `test/<capa>/<nombre>_test.gd` primero** y corrélo: tiene que fallar, y fallar por
   lo que se espera. Un rojo de `nonexistent function` no verifica nada — verifica que el
   archivo no existe.
2. Lo mínimo para que pase.
3. Limpiar, con el test de testigo.

**Si algo no se puede probar sin levantar una escena, no va en esas dos capas.** Va en `ui/` o
en `escenas/`, que son cáscara — y entonces la regla que tenía adentro hay que bajarla al
dominio. Ésa es la conversación que el gate fuerza, y es la que hace que el juego se pueda
probar.

## La dirección de dependencia la verifica otro gate

`dominio/` → `sistemas/` → `ui/` → `escenas/`, sólo hacia abajo. Y **cuenta también nombrar un
`class_name` de otra capa**, que en Godot es la forma normal de escribir código y no deja
rastro en ningún import: por eso el gate construye el índice y busca los identificadores.

Si te frena, la salida no es una excepción: es mover la decisión hacia abajo, o pasar el dato
por parámetro en vez de ir a buscarlo.

## El nodo de convergencia es `verificar.py`, no los tests

```bash
python .claude/scripts/verificar.py
```

Corre los seis nodos en paralelo: `lint`, `formato`, `capas`, `tdd`, `harness` y `tests`.
Correr sólo la suite de gdUnit4 deja afuera los dos gates, que son justamente los que cuidan
lo que en este motor nadie más cuida.

**Un nodo salteado no es un nodo verde**, y el reporte lo distingue. Si `tests` dice que se
saltea porque no hay `GODOT_BIN`, eso **es un rojo**: significa que la suite no corrió.

## Cuando el spec no alcanza — el lazo

**Para cuando llegás acá no debería quedar ninguna duda de planteo.** Se resuelven entre
`spec-create` y `spec-review`, que es donde cuestan un párrafo. Así que **una duda que aparece
implementando es evidencia de que uno de esos dos skills tiene un agujero**, y tratarla como un
problema de este spec la deja volver la próxima vez.

La descarga son dos mitades, las dos en esta corrida:

1. **Corregí el spec** para poder seguir —el AC que no se puede ver fallar, la tarea que falta, la
   regla que estaba en la capa equivocada— y **devolvelo al issue** con
   `python .claude/scripts/publicar_spec.py publicar`. Sin eso, `specs/` es caché y la próxima
   hidratación se lleva puesta la corrección.
2. **Corregí el `SKILL.md` que lo permitió**, con la regla que lo habría atajado:

   | Lo que apareció | Qué skill se corrige |
   |---|---|
   | un AC que no se puede ver fallar | `spec-create` |
   | una tarea que no dice qué archivo toca | `spec-create` |
   | una regla del juego ubicada en `ui/` o en `escenas/` | `spec-create` |
   | un `[P]` que resultó falso | `spec-review` |
   | dos specs que se pisan la misma escena | `spec-review-batch` |
   | una medición que el spec supuso en vez de correr | `spec-create` |

   **Si no entra en ninguna fila, agregá la fila** —en [`../sin-deuda.md`](../sin-deuda.md)—. La
   tabla está incompleta a propósito: es el registro de lo que este flujo ya aprendió.

Va al reporte como sección propia. **Es el entregable más caro de la corrida y el más fácil de
saltear**, porque no lo reclama ningún test ni ningún PR: el spec ya quedó andando sin él.

## Al cerrar

- **Todas las casillas del `tasks.md` marcadas.** No hay marcador para «esto quedó pendiente».
  Lo que quedó pendiente es un issue.
- **Devolvé las marcas al issue**: `python .claude/scripts/publicar_spec.py publicar`. El
  archivo del disco es **caché**, y la próxima hidratación baja el `tasks.md` del issue y se
  lleva puesta cada casilla marcada que no se haya subido.
- **Lo que aparece implementando se hace, no se anota.** Un `tasks.md` incompleto no se cierra
  abriendo un issue: se completa. Adentro del spec el ítem hereda su estado —un spec
  `Implementado` con diez casillas abiertas no le debe nada a nadie—, y afuera, en un issue, el
  trabajo que este spec necesitaba queda huérfano de la razón por la que existía.

  **Y lo verifica el gate:** un spec `Implementado` con una casilla abierta pone en rojo el nodo
  `harness` (`test_convencion_de_specs.py`).
- **El PR lleva un `Closes` por cada issue saldado**: el del spec más los de su `origen`.
- **No toques `specs/mapa.json` en el PR.** El estado lo deriva la Action en el push a
  `staging`, y el gate da rojo si el mapa dice `Implementado` mientras el PR está abierto.
- Si el spec falsificó algo que la documentación afirma en presente, actualizá `docs/`,
  `.claude/rules/` y `CLAUDE.md` — no los specs viejos, que son historia.
