# Preparar el motor nativo corregido

El editor usa Godot 4.7.2 con el bloqueo de escritura del [PR oficial #123546](https://github.com/godotengine/godot/pull/123546).
La versión upstream sigue en `.godot-version`.
La [receta nativa](../../.github/patches/godot-native-compilacion.json) fija la revisión, el parche, el compilador y las opciones.
La plantilla web conserva su receta y sus parches propios.

## Descargar para trabajar

Windows y Linux x86_64 usan los paquetes de la release de herramientas del proyecto.
El lock `.github/patches/godot-native-artefactos.json` fija su URL, receta y SHA256 del ZIP y del manifiesto.

```bash
python .github/scripts/descargar_godot_nativo.py descargar
python .claude/scripts/verificar.py
```

La descarga valida los hashes antes de extraer o ejecutar el motor.
Una copia válida en `build/godot-native/<plataforma>` permite reutilizarlo sin red.
La copia conserva el ejecutable principal, el de consola, las DLL necesarias y `manifiesto.json` en la misma carpeta.
El verificador usa esa copia cuando `GODOT_BIN` no está declarada.
Una `GODOT_BIN` declarada tiene prioridad y debe apuntar a un motor con el mismo manifiesto válido.
Si apunta al motor oficial, el nodo `tests` sale rojo aunque la copia exista.

## Construir otra receta

La construcción está separada de `verify`.
El workflow manual `construir-godot-nativo` construye ambas plataformas y prueba cada ejecutable en su sistema operativo.
Sus artifacts son resultados de construcción con retención limitada, no la distribución consumida por `verify`.
Después de revisar las ocho reproducciones concurrentes por plataforma, publicar los ZIP en una release de herramientas y actualizar el lock con sus hashes.
Publicar con una etiqueta nueva por receta, como prerelease y sin marcarla como última versión del juego.
No reemplazar archivos de una distribución aprobada.

También se puede construir localmente con los comandos siguientes.

### Windows x86_64

Docker Desktop permite compilar con MinGW sin instalar un compilador global en Windows.
Desde la raíz del checkout, preparar la imagen y el directorio de salida:

```powershell
docker build -t nosefia-godot-nativo:4.7.2 .github/containers/godot-native
New-Item -ItemType Directory -Force build/godot-native
docker volume create nosefia-godot-nativo
$repo_motor = $PWD.Path
$salida_motor = (Resolve-Path build/godot-native).Path
```

Compilar con las fuentes en un volumen de Docker y la salida en el checkout:

```powershell
docker run --rm `
  --mount "type=bind,source=$repo_motor,target=/repo,readonly" `
  --mount "type=bind,source=$salida_motor,target=/salida" `
  --mount type=volume,source=nosefia-godot-nativo,target=/trabajo `
  nosefia-godot-nativo:4.7.2 `
  python3 /repo/.github/scripts/preparar_godot_nativo.py preparar `
  --plataforma windows-x86_64 --destino /salida/windows-x86_64 --trabajo /trabajo --jobs 4
```

Comprobar el artefacto desde Windows antes de abrir el proyecto:

```powershell
python .github/scripts/preparar_godot_nativo.py comprobar --plataforma windows-x86_64
python .claude/scripts/verificar.py
```

### Linux x86_64

Instalar GCC 13.3.0 y las dependencias indicadas por la [documentación oficial de compilación](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_linuxbsd.html).
El Dockerfile enumera los paquetes usados en Ubuntu 24.04.
Después ejecutar:

```bash
python .github/scripts/preparar_godot_nativo.py preparar --plataforma linux-x86_64 --jobs 4
python .github/scripts/preparar_godot_nativo.py comprobar --plataforma linux-x86_64
python .claude/scripts/verificar.py
```

El preparador instala la versión fijada de SCons en un entorno privado.
Una copia completa y válida evita otra compilación.

Para validar y empaquetar una construcción antes de publicarla:

```bash
python .github/scripts/probar_godot_nativo.py
python .github/scripts/empaquetar_godot_nativo.py --plataforma linux-x86_64 --salida reports/motor-nativo/linux-x86_64.zip
```

En Windows usar `--plataforma windows-x86_64` y su nombre de ZIP.
El empaquetador genera junto al ZIP un JSON con las tres huellas para el lock.

## Qué se comprueba

El preparador valida el SHA256 del ZIP fuente, los archivos originales, el parche y los archivos modificados.
El manifiesto liga la receta esperada con las huellas del ejecutable y sus dependencias distribuidas.
La comprobación de una caché no ejecuta un binario antes de validar esos hashes.
El verificador rechaza el editor oficial vulnerable aunque declare la misma versión base.

Una receta distinta requiere otra preparación y otra clave de importaciones.
No reutilizar un manifiesto antiguo para justificar un ejecutable nuevo.
Los hashes identifican el artefacto real, sin prometer compilaciones idénticas entre toolchains distintas.

## Costo inicial y alcance

Cada receta necesita una construcción y validación inicial del editor completo por plataforma.
Ese costo queda fuera de las verificaciones del juego.
En `verify`, las seis particiones restauran o descargan el mismo motor publicado en paralelo.
Cada una valida el paquete contra el lock antes de usar su copia privada.
Ninguna espera un job previo de preparación del motor.
Las seis máquinas necesitan sus propias transferencias, que forman parte del trabajo acumulado de CI.
La caché acelera la descarga; su expulsión no provoca otra compilación.
La release sigue siendo necesaria para una descarga fría y puede perderse por eliminación explícita del repositorio o de la publicación.

El backport corrige el getter concurrente reproducido.
No incorpora propuestas adicionales pendientes sobre otros escritores de `ClassDB`.
Al adoptar una versión upstream corregida, actualizar la receta y validar nuevamente las reproducciones concurrentes.
