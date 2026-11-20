# Entrega: la mancha de contacto sigue la forma de su objeto

## Commit del cambio

`02fab1b8` en la rama `improvement/mancha-con-la-forma`.

## Qué causaba la mancha cuadrada

`sombra_de_contacto.gdshader` ya dibujaba rectángulos redondeados y círculos mediante el uniforme `esquinas` (de 0 a 1). `objeto_agarrable.gd` fijaba `ESQUINAS_POR_DEFECTO = 0.1` para todo objeto sin sobreescritura, incluidas todas las unidades de producto sueltas (`UnidadDeProducto`). `oclusion_de_la_gondola.gd` aplicaba el mismo `0.1` a todos los bloques de productos en el estante. Por eso una lata cilíndrica como Arvecor dejaba una mancha casi cuadrada.

## Qué cambió

- `src/escenas/objetos/oclusion_de_contacto.gd`: calcula `esquinas` en `medir_huella_2d` desde los vértices de apoyo proyectados sobre el plano de contacto. Invierte el área exacta del rectángulo redondeado del shader contra el área del casco convexo 2D (`4 * hx * hz - (4 - PI) * r^2`). Elimina el parámetro manual `esquinas` de `configurar`.
- `src/escenas/puestos/oclusion_de_la_gondola.gd`: mide `esquinas` en `_medir_apoyo_local` con la misma función `OclusionDeContacto.medir_huella_2d`. Cada producto acomodado conserva la misma forma que su unidad suelta.
- `src/escenas/objetos/objeto_agarrable.gd`, `bolsa_de_basura.gd`, `util_de_limpieza.gd`, `caja_de_productos.gd`: eliminan `ESQUINAS_POR_DEFECTO` y las sobreescrituras manuales `_esquinas_de_contacto`. La medición desde la malla da 1,0 para el balde, la mopa, los bidones, la bolsa y las latas paradas, y 0,0 para las cajas.
- `test/escenas/objetos/oclusion_de_contacto_test.gd`, `oclusion_de_contacto_apoyo_test.gd`, `oclusion_de_los_objetos_test.gd`, `test/escenas/oclusion_de_la_gondola_test.gd`: agregan pruebas de comportamiento que afirman que una base redonda (cilindro, lata Arvecor, balde, bolsa) deja una mancha más redonda que una cuadrada (cubo, Zucarachas, caja de productos), que un cilindro acostado se vuelve menos redondo y que la góndola coincide con la unidad suelta.
- `docs/guides/iluminacion.md`: documenta el cálculo de redondez por casco convexo para objetos sueltos y góndola.

## Verificación

- `gdformat --check` y `gdlint` sobre los 10 archivos `.gd` tocados: sin errores.
- `gate_de_capas.py` y `gate_de_tests.py`: verde.
- `test_largo_de_oracion.py`: 12/12 OK.
- Suites de gdUnit4 (`oclusion_de_contacto_test.gd`, `oclusion_de_contacto_apoyo_test.gd`, `oclusion_de_los_objetos_test.gd`, `oclusion_de_la_gondola_test.gd`): 47/47 casos en verde (0 errores, 0 fallos, 0 huérfanos).

## Medición de la build web

Export completo en `export/web/` con plantilla `build/templates/web_release.zip` verificada (`verificar_export.py` y `preparar_plantilla_web.py --verificar-export` en verde):

- **Programas WebGL2 en carga (`--software --corridas=1 --sin-enlace-en-paralelo`):** 97 programas, 84 fuentes distintas (tope 98, `tope_de_carga.py` en verde). Resultado guardado en `C:/Users/fede_/.cache/nosefia/carga-mancha-con-la-forma.json`.
- **Tamaño del export web:** 9 archivos, 138,7 MB en total (145.399.431 bytes).
  - `index.pck`: 115.907.420 bytes (110,54 MiB).
  - `index.wasm`: 29.149.696 bytes (27,80 MiB; tope 31.457.280 bytes).

## Capturas web (antes `2e82981a` y después `02fab1b8`, misma pose)

- Arvecor sobre la mesa:
  - Antes: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/antes_arvecor_mesa.png`
  - Después: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/despues_arvecor_mesa.png`
- Caja (Zucarachas) sobre la mesa:
  - Antes: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/antes_caja_mesa.png`
  - Después: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/despues_caja_mesa.png`
- Balde en el piso:
  - Antes: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/antes_balde_piso.png`
  - Después: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/despues_balde_piso.png`
- Bolsa de basura en el piso:
  - Antes: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/antes_bolsa_piso.png`
  - Después: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/despues_bolsa_piso.png`
- Arvecor en el piso:
  - Antes: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/antes_arvecor_piso.png`
  - Después: `C:/Users/fede_/.cache/nosefia/capturas-mancha-con-la-forma/despues_arvecor_piso.png`
