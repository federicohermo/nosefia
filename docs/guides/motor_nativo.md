# Preparar el motor nativo corregido

El editor usa Godot 4.7.2 con el bloqueo de escritura del [PR oficial #123546](https://github.com/godotengine/godot/pull/123546).
La versión upstream sigue en `.godot-version`.
La [receta nativa](../../.github/patches/godot-native-compilacion.json) fija la revisión, el parche, el compilador y las opciones.
La plantilla web conserva su receta y sus parches propios.

## Windows x86_64

Docker Desktop permite compilar con MinGW sin instalar un compilador global en Windows.
Desde la raíz del checkout, preparar la imagen y el directorio de salida:

```powershell
docker build -t nosefia-godot-nativo:4.7.2 .github/containers/godot-native
New-Item -ItemType Directory -Force build/godot-native/windows-x86_64
docker volume create nosefia-godot-nativo
$repo_motor = $PWD.Path
$salida_motor = (Resolve-Path build/godot-native/windows-x86_64).Path
```

Compilar con las fuentes en un volumen de Docker y la salida en el checkout:

```powershell
docker run --rm `
  --mount "type=bind,source=$repo_motor,target=/repo,readonly" `
  --mount "type=bind,source=$salida_motor,target=/salida" `
  --mount type=volume,source=nosefia-godot-nativo,target=/trabajo `
  nosefia-godot-nativo:4.7.2 `
  python3 /repo/.github/scripts/preparar_godot_nativo.py preparar `
  --plataforma windows-x86_64 --destino /salida --trabajo /trabajo --jobs 4
```

Comprobar el artefacto desde Windows antes de abrir el proyecto:

```powershell
python .github/scripts/preparar_godot_nativo.py comprobar --plataforma windows-x86_64
python .claude/scripts/verificar.py
```

La copia conserva el ejecutable principal, el de consola, las DLL necesarias y `manifiesto.json` en la misma carpeta.
El verificador encuentra esa copia sin cambiar `GODOT_BIN` en el registro global.
Una variable explícita sigue teniendo prioridad y debe apuntar a un motor con el mismo manifiesto válido.

## Linux x86_64

Instalar GCC 13.3.0 y las dependencias indicadas por la [documentación oficial de compilación](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_linuxbsd.html).
El workflow de preparación enumera los paquetes usados en Ubuntu 24.04.
Después ejecutar:

```bash
python .github/scripts/preparar_godot_nativo.py preparar --plataforma linux-x86_64 --jobs 4
python .github/scripts/preparar_godot_nativo.py comprobar --plataforma linux-x86_64
python .claude/scripts/verificar.py
```

El preparador instala la versión fijada de SCons en un entorno privado.
Una copia completa y válida evita otra compilación.

## Qué se comprueba

El preparador valida el SHA256 del ZIP fuente, los archivos originales, el parche y los archivos modificados.
El manifiesto liga la receta esperada con las huellas del ejecutable y sus dependencias distribuidas.
La comprobación de una caché no ejecuta un binario antes de validar esos hashes.
El verificador rechaza el editor oficial vulnerable aunque declare la misma versión base.

Una receta distinta requiere otra preparación y otra clave de importaciones.
No reutilizar un manifiesto antiguo para justificar un ejecutable nuevo.
Los hashes identifican el artefacto real, sin prometer compilaciones idénticas entre toolchains distintas.

## Costo inicial y alcance

La primera construcción compila el editor completo y puede durar mucho más que las suites.
En CI, un único productor prepara el motor y las seis particiones consumen el mismo artefacto validado.
La caché del motor evita repetir esa construcción mientras siga disponible y sea compatible.
Su expulsión exige reconstruir, sin sustituir el resultado por el editor oficial.

El backport corrige el getter concurrente reproducido.
No incorpora propuestas adicionales pendientes sobre otros escritores de `ClassDB`.
Al adoptar una versión upstream corregida, actualizar la receta y validar nuevamente las reproducciones concurrentes.
