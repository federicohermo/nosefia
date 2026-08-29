---
name: spec-implement
description: Especialización de /spec-implement para No se fía (Godot). El paralelismo viene declarado por tarea con [P], el TDD es obligatorio y verificado, y el nodo de convergencia es verificar.py. Se lee junto con el skill global.
---

# spec-implement — No se fía

Este archivo **no reemplaza** al skill global: aporta lo que en este repo es distinto. El
método, el fake-edge test y la convergencia salen de allá.

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

## Al cerrar

- **Todas las casillas del `tasks.md` marcadas.** No hay marcador para «esto quedó pendiente».
  Lo que quedó pendiente es un issue.
- **Devolvé las marcas al issue**: `python .claude/scripts/publicar_spec.py publicar`. El
  archivo del disco es **caché**, y la próxima hidratación baja el `tasks.md` del issue y se
  lleva puesta cada casilla marcada que no se haya subido.
- **La deuda que aparece implementando se abre como issue**, y **no se anota en el spec**.
  Adentro de un `tasks.md` el ítem hereda el estado de su spec: un spec `Implementado` puede
  tener diez casillas abiertas y no deberle nada a nadie. Un issue tiene estado propio. Lleva
  tres cosas:
  - **Título que se entienda fuera del contexto del spec** — en la lista de issues no hay más
    contexto que el título.
  - **Cuerpo con la evidencia**: `archivo:línea`, el número medido, qué hace falta para verlo.
  - **`Detectado en #N`**, con el issue del spec. **El `#N` sale de `specs/mapa.json` y no del
    `NNN`**: son dos numeraciones distintas.

  El label es `bug` o `enhancement`. Inventar uno propio para la deuda de los specs vuelve a
  partir el tracker en dos.
- **El PR lleva un `Closes` por cada issue saldado**: el del spec más los de su `origen`.
- **No toques `specs/mapa.json` en el PR.** El estado lo deriva la Action en el push a
  `staging`, y el gate da rojo si el mapa dice `Implementado` mientras el PR está abierto.
- Si el spec falsificó algo que la documentación afirma en presente, actualizá `docs/`,
  `.claude/rules/` y `CLAUDE.md` — no los specs viejos, que son historia.
