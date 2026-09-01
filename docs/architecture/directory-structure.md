# Estructura de directorios

```text
.
├── project.godot           El proyecto. Godot lo reescribe: no se edita a mano salvo para algo puntual
├── icon.svg
├── .gdlintrc               La config de gdlint. Excluye addons/ y .godot/
├── .editorconfig           Tabs en .gd, espacios en .py y .md
│
├── src/                    ← PROTEGIDO por el hook: no se edita sin un spec detrás de la rama
│   ├── dominio/            Reglas puras. RefCounted/Resource. Test OBLIGATORIO
│   ├── sistemas/           Nodes y autoloads que orquestan el dominio. Test OBLIGATORIO
│   ├── ui/                 HUD, computadora, ventanilla
│   └── escenas/            Los scripts pegados a un .tscn, y las escenas del juego
│       ├── almacen.tscn                 La escena raíz. CABLEA: lo suyo cuelga de su raíz
│       ├── estructura_del_almacen.tscn  El blockout —piso, paredes y anclajes—, instanciado ahí
│       └── jugador.tscn                 El cuerpo en primera persona, instanciado en el almacén
│
├── test/                   El ESPEJO de src/: src/dominio/turno.gd → test/dominio/turno_test.gd
│   ├── dominio/            Espejo OBLIGATORIO, lo verifica gate_de_tests.py
│   ├── sistemas/           Espejo OBLIGATORIO, ídem
│   └── escenas/            OPCIONAL: ningún gate lo exige, y por eso lo que hay acá es lo que
│                           alguien decidió probar levantando la escena
│
├── assets/                 Arte, audio, fuentes. Lo que no es código
│
├── addons/
│   └── gdUnit4/            Vendorizado, versión 5.1.1 (la serie para Godot 4.4). NO se edita ni se lee
│
├── docs/                   ← PROTEGIDO por el hook
│
├── specs/
│   ├── README.md           La convención y el flujo
│   ├── mapa.json           El mapa spec↔issue. Lo ÚNICO del directorio que se commitea, con el README
│   └── NNN-…/              CACHÉ, ignorada por git. Se trae con hidratar_specs.py
│
├── reportes/               Los reportes de gdUnit4. Ignorado
│
├── .claude/
│   ├── settings.json       El hook PreToolUse que corre el gate de spec
│   ├── rules/              Reglas por capa: se cargan solas al tocar sus archivos
│   ├── skills/             spec-create, spec-review, spec-implement
│   └── scripts/            Las herramientas del harness (Python, sin dependencias)
│       ├── lib/            Lo PURO o inyectable: es lo que tiene tests
│       └── tests/          Los tests del harness, y los dos gates del registro de specs
│
└── .github/workflows/
    ├── verify.yml          Corre verificar.py en cada PR y en cada push a staging y main
    └── mapa.yml            Deriva specs/mapa.json en el push a staging
```

## Dónde crear cada cosa

| Si estás por escribir… | Va en | Y además |
|---|---|---|
| Una regla del juego (cuánto tiempo, qué cuenta como cumplir, qué consecuencia) | `src/dominio/` | su test en `test/dominio/`, **primero** |
| Algo que necesita `delta`, el árbol de escena o un archivo | `src/sistemas/` | su test en `test/sistemas/`, **primero** |
| Una pantalla, un panel, un botón | `src/ui/` | sin test obligatorio — y por eso no puede tener reglas adentro |
| El script de una escena concreta | `src/escenas/` | ídem — y si lo probás, va en `test/escenas/`, que **ningún gate exige** |
| Algo que va en el almacén y tiene hijos propios | su propio `.tscn` en `src/escenas/` | se **instancia** en `almacen.tscn`, que sólo cablea: colgarlo ahí adentro lo caza `test/escenas/almacen_test.gd` |
| Un número que dos archivos necesitan igual | un solo archivo de `src/dominio/` | nunca dos copias |
| Un `.png`, un `.ogg`, una fuente | `assets/` | no necesita spec |
| Una herramienta del proceso | `.claude/scripts/` | lo puro en `lib/`, su test en `tests/` |

## Las dos rutas protegidas

`src/` y `docs/`. El hook de `.claude/settings.json` no deja editarlas desde `main`, desde
`staging` ni desde una rama que no nombre un spec.

**`.claude/` y `specs/` quedan afuera a propósito**: son adonde el flujo te manda a escribir
primero, y `.claude/` es además donde vive el gate — uno que se impide arreglarse a sí mismo se
termina borrando en vez de corrigiéndose.

`project.godot`, `addons/` y los configs tampoco: el gate no puede impedir habilitar un plugin
o cambiar una configuración del editor, y pretenderlo lo volvería molesto sin volverlo útil.

## Lo que está ignorado, y por qué

| Ruta | Por qué |
|---|---|
| `.godot/` | Caché del editor. Se regenera sola y cambia en cada apertura |
| `specs/[0-9]*/` | Caché: la fuente es el issue. Ver [specs/README.md](../../specs/README.md) |
| `reportes/` | Salida de gdUnit4, se regenera en cada corrida |
| `export/`, `build/` | Las builds se publican, no se commitean |
| `__pycache__/` | De las herramientas del harness |
