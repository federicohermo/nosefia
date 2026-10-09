# Las capacidades y lo que pasa entre ellas

**El contrato de cada capacidad vive en su spec** —`specs/<capability>/<capability>.md`—, y su
código, en el `capability_id` del frontmatter. Este documento no lo repite: declara **lo que
pasa entre ellas**, que es lo único que ningún spec puede decir solo.

Las reglas de edición de un spec están en [`.claude/rules/specs.md`](../../.claude/rules/specs.md),
y se cargan solas al tocar ese árbol.

## Una capacidad no es una capa

Una capacidad es una tajada de lo que el juego **hace**: atender la ventanilla, reponer la
góndola, arrastrar el legajo entre noches. Una capa es dónde vive el código que la implementa.
Son dos ejes distintos y se cruzan: casi toda capacidad tiene piezas en `dominio/` y en
`sistemas/`, y varias tienen una en `escenas/`.

Por eso el spec no nombra archivos, clases ni escenas: lo pide
[la regla de specs](../../.claude/rules/specs.md).

## El mapa

```mermaid
flowchart TD
  SHF["shift-cycle<br/><i>el tiempo de la noche</i>"]
  EMP["employment-record<br/><i>el legajo y el final</i>"]
  SAV["save-and-resume<br/><i>lo que cruza la sesión</i>"]
  PLY["player-actions<br/><i>moverse y manipular</i>"]
  INV["investigation<br/><i>lo que compra el minuto</i>"]
  CTR["counter-service<br/><i>la ventanilla</i>"]
  STK["store-stock<br/><i>la mercadería</i>"]
  CLN["store-cleanup<br/><i>el local en orden</i>"]
  AMB["ambience<br/><i>qué suena</i>"]
  NTF["notifications<br/><i>qué se avisa</i>"]

  CTR -- "obligatoria cumplida" --> SHF
  STK -- "obligatorias cumplidas y descumplidas" --> SHF
  CLN -- "obligatorias cumplidas" --> SHF
  CLN -- "motivos únicos de la noche" --> EMP
  STK -- "unidades sueltas" --> CLN
  SHF -- "obligatorias declaradas" --> PLY
  SHF -- "cuántas se cumplieron" --> EMP
  EMP -- "jornada, legajo y final" --> SAV
  STK -- "unidades en góndola" --> CTR
  CTR -- "lo vendido" --> STK
  PLY -- "qué se lleva y qué se tira" --> CLN
  CLN -- "la unidad tirada" --> STK
  PLY -- "la unidad viaja en la mano" --> STK
  STK -- "qué casilleros están vacíos y cuáles ocupados" --> PLY
  PLY -- "qué objeto se examina" --> INV
  INV -- "la caja que se examina" --> STK
  SHF -.-> AMB
  EMP -.-> AMB
  CTR -.-> AMB
  STK -.-> AMB
  CLN -.-> AMB
  PLY -.-> AMB
  INV -.-> AMB
  CTR -.-> NTF
  SHF -.-> NTF
```

La línea punteada expresa escucha sin respuesta. `ambience` escucha las señales de las demás.
`notifications` escucha la llegada, el rechazo del lector y el cierre del turno. Ninguna
contesta a quien publica el suceso. Por eso la tabla de sonidos es un archivo y no un `match`:
agregar un sonido no toca a quien lo emite.

## Las dos mitades de la resta

La tensión central del juego es aritmética, y en el mapa se lee de un vistazo. **`shift-cycle`
es la resta**, y las capacidades que le apuntan son lo que cada lado compra.

| Lado | Capacidades | Qué le hacen al turno |
|---|---|---|
| **Lo que el jefe pide** | `counter-service`, `store-stock`, `store-cleanup` | consumen tiempo **y** cumplen una obligatoria |
| **Lo que el jugador elige** | `investigation` | consume tiempo y **no cumple nada** |
| **El cuerpo** | `player-actions` | no consume por sí mismo: el precio son los metros |
| **Lo que dura más que la noche** | `employment-record`, `save-and-resume` | no consumen: reciben el cierre |

Al evaluar una feature, la pregunta es de qué lado cae. Una que no toca esa resta es contenido,
no diseño.

## Las fronteras que más se rompen

Tres pares se confunden seguido, y cada uno tiene su regla escrita en los dos specs:

- **`counter-service` y `store-stock`.** Cobrar es de la ventanilla; cuántas unidades hay y dónde
  están, de la mercadería. La ventanilla **pregunta**, no lleva su propia cuenta.
  En la primera noche, Martín y Tiago llegan por el reloj y reciben unidades físicas y un ticket
  exacto. Sólo el pedido completo cuenta como venta. Al vencer, se llevan lo recibido sin sumar
  una venta; el aviso de salida usa la misma pila de notificaciones que la llegada. El aviso de
  llegada permanece hasta iniciar la conversación. El comprador espera animado en el mundo,
  detrás de la ventanilla, mirando hacia la cámara incluso con la interfaz cerrada.
- **`player-actions` e `investigation`.** Agarrar y examinar son del cuerpo; **qué esconde** el
  objeto es de la investigación. La identidad de lo que se agarra es opaca a propósito: lo que se
  investiga no está en el catálogo.
- **`employment-record` y `save-and-resume`.** El legajo decide; el guardado sólo lo pone en
  disco y lo trae de vuelta.

## Dónde va una regla nueva

1. **¿Qué capacidad decide esto?** Si la respuesta es «dos», la regla está mal partida: una de
   las dos la consume.
2. **¿Se puede ejercer sin levantar una escena?** Si sí, el código va en `dominio/`. Si no, mirá
   otra vez — casi siempre se puede, y lo que no se puede es *dibujarla*.
3. **¿El GDD ya lo decidió?** Entonces el spec dice eso, aunque el código todavía diga otra cosa.
   Esa diferencia es el hallazgo, y sale en un issue.

Una capacidad nueva se abre sólo si la regla no entra en ninguna **y** no es regla de una de
ellas. Una capacidad de un solo criterio casi siempre es lo segundo.
