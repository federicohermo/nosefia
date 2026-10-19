# Inicio rápido

## Lo que hace falta instalar

| Qué | Cómo | Para qué |
|---|---|---|
| **Godot** | compilación corregida del proyecto, explicada abajo | el juego, y correr los tests |
| **Python** | del sitio oficial o Microsoft Store | las herramientas del harness |
| **gdtoolkit** | `pip install` con la versión que fija `.github/workflows/verify.yml` | `gdlint` y `gdformat` |
| **GitHub CLI** | de [cli.github.com](https://cli.github.com), después `gh auth login` | abrir y leer los issues |
| **ffmpeg** | `scoop install ffmpeg`, o del sitio oficial | comprimir un audio nuevo con `python .claude/scripts/comprimir_audio.py` |

**gdUnit4 no se instala**: está vendorizado en `addons/gdUnit4/` y viene con el clone. Las
versiones las declaran `.godot-version` para el motor, `addons/gdUnit4/plugin.cfg` para el
addon, y `verify.yml` para Python y gdtoolkit.

## El motor y el addon se mueven juntos

**El motor y el addon de tests son un solo pin.** El addon declara una versión mínima de Godot,
y Godot rompe la sintaxis vieja del addon. Afuera de su ventana, el addon **no compila**, y la
corrida sale con código 0 igual. Moverlos es un cambio para todo el equipo y para la CI a la vez.

- **`.godot-version` es la única fuente de la versión del motor.** `verify.yml` y
  `desplegar.yml` la leen de ahí. Dos copias harían que la CI verifique con un motor y el
  despliegue exporte con otro, sin un rojo.
- **La compatibilidad sale de la tabla «GdUnit4 Version / Godot minimal required»** del README
  de gdUnit4. No de los badges de «Supported Godot Versions», que mezclan las series.
- **La revisión nativa vive en `.github/patches/godot-native-compilacion.json`.** Fija el backport de ClassDB sobre la versión base.
- **La copia gestionada se valida antes de usarla.** `GODOT_BIN` permite indicar otra ubicación con la misma receta y manifiesto.

## Preparar el motor corregido

Godot 4.7.2 oficial contiene una carrera durante la importación concurrente.
El proyecto usa una compilación con el bloqueo oficial aplicado a `ClassDB`.
La receta comprueba las fuentes y el parche antes de compilar, y los ejecutables antes de reutilizarlos.

Descargar la copia publicada para Windows o Linux x86_64:

```bash
python .github/scripts/descargar_godot_nativo.py descargar
```

El verificador encuentra la copia de `build/godot-native/<plataforma>` sin modificar el registro global.
La descarga comprueba el paquete y su manifiesto contra el lock versionado.
No requiere Docker ni un compilador. La [guía del motor](./motor_nativo.md) explica cómo construir otra receta.
Para usar una copia en otra ubicación, declarar `GODOT_BIN` con su ejecutable de consola y conservar el manifiesto junto a él.

Una variable explícita que apunta al editor oficial vulnerable hace fallar el preflight.
El preflight rechaza un binario sin la receta y los hashes esperados.
En Windows, mantener los dos ejecutables y las DLL distribuidas en la misma carpeta, fuera de OneDrive.

Si falta un motor corregido válido, el nodo `tests` falla con instrucciones de preparación.

## Abrir el proyecto

Abrí `project.godot` con el motor corregido. El plugin de gdUnit4 ya está habilitado en el archivo, así que
la primera apertura lo carga sola y aparece el panel de tests.

## Correr todo

```bash
python .claude/scripts/verificar.py
```

Es **lo único que hay que correr antes de un PR**, y es lo mismo que corre la CI. Qué hace cada
nodo y qué se saltea, en [verificación](./verificacion.md).

## Empezar un cambio

El camino, de la idea al PR, está en `CLAUDE.md`. Los prefijos de rama y qué exige el hook, en
[ramas](../infra/ramas.md). Si el hook te frenó, el mensaje dice cómo salir.

## Leer un contrato

Los contratos **están en el repo** y se leen como cualquier archivo: `specs/<capability>/`. Qué
decide cada capacidad y qué pasa entre ellas, en
[capacidades](../architecture/capacidades.md).
