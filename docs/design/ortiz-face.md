# Cara de Ortiz (`OrtizFace`)

> Spec 02, paso 1 y base del paso 7 · `specs/02-ortiz-al-centro.md` · Fecha: 2026-11-17
> Decisión de la persona (PA-01): se usa la cara vectorial **«Pantalla»** mientras tanto. El conejo de Rive queda como opción futura si ella lo remezcla.
> Maqueta de referencia (estilo «Pantalla»): https://claude.ai/artifact/TR22XAWd9anJ6xYLXCVn48

## Arquitectura y datos

_(Dueño: `architect`. No hay cambios de datos. El ánimo se calcula a partir de `AgenteState`; ver «Origen del ánimo» en la sección UI/UX.)_

## UI/UX

### 1. Validación del conejo de Rive (versión corta)

**Archivo:** «Bunny emoji» de **cathy._.linlin**, https://rive.app/marketplace/9058-17308-bunny-emoji/

| Regla del paso 1 | Resultado | Notas |
| --- | --- | --- |
| (a) Licencia | ✅ Se cumple | CC BY 4.0. Hay que dar crédito y, si se remezcla, **indicar que se modificó**. Texto para Ajustes › Acerca de: «Personaje: Bunny emoji de cathy._.linlin (CC BY 4.0), modificado», con enlace al archivo y a la licencia (https://creativecommons.org/licenses/by/4.0/deed.es). El crédito **solo es obligatorio cuando el `.riv` se empaquete**. Mientras se use «Pantalla», no hace falta. Hoy no existe ninguna sección «Acerca de»: hay que crearla con la versión Rive (ver §1.4). |
| (b) Flutter web | ⚠️ Viable, sin medir | Ver §1.2. No se añadió la dependencia. |
| (c) 4 ánimos | ❌ No tal cual (probable) | Ver §1.1. Hace falta una remezcla con las entradas de §1.3. |

**Conclusión:** según la regla de decisión, falla (c) y no hay remezcla, así que se usa **«Pantalla»**, lo que coincide con PA-01. `OrtizFace` mantiene una interfaz única para poder pasar a Rive sin tocar el resto de la app.

#### 1.1 Lo que se ve sin cuenta de Rive

En la página pública del marketplace (consultada el 2026-11-17) se ve:

- Autor cathy._.linlin, licencia CC BY, publicado y actualizado el 24/03/2024.
- Descripción: «They are animated emojis. Just hover and click on them!». Reacciona a pasar el cursor y a hacer clic, es decir, a *listeners* de puntero dentro del archivo, no a entradas que la app pueda manejar.
- Artboard **«New Artboard»** y state machine **«State Machine 1»** (salen de los parámetros de la URL de vista previa).
- Botones «Download» y «Remix in Rive».

Lo que **no** se ve sin abrir el archivo en el editor: la lista de entradas (*inputs*) o propiedades del view model, el número de estados, el tamaño del `.riv` y si trae algo parecido a «pensando» o «hablando». No se descargó el archivo. Lo más probable (R-01) es que solo tenga estados de reposo, hover y clic, sin entradas numéricas.

#### 1.2 Paquete `rive` en Flutter web

- La versión actual en pub.dev es `rive 0.14.11` (hay una 0.15.0-dev). Depende de `rive_native` (ya no de `rive_common`) y declara soporte web.
- **En web, `rive_native` descarga su WebAssembly en tiempo de ejecución desde el CDN jsDelivr de Rive**, fijado a la versión del paquete. Eso implica:
  - una petición a un tercero en cada carga en frío;
  - que sin red el personaje no aparece.
  
  Se puede alojar en el propio Vercel copiando las carpetas `wasm/` y `wasm_compatibility/` del paquete npm `@rive-app/flutter-native-wasm` y compilando con `--dart-define=RIVE_NATIVE_WASM_HOST=<url>/` (la barra final es obligatoria). **Recomendación: alojarlo nosotros** (por privacidad y por la CSP), y que lo revise `security-auditor`.
- **Peso aproximado:** Rive no publica la cifra de `rive_native`. Como referencia, sus runtimes web miden 1728 KB / 567 KB con brotli (canvas) y 2179 KB / 648 KB (webgl2). Hay que contar con **unos 0,6–0,7 MB comprimidos más** en la primera carga, más el código Dart del paquete. Se mide con `flutter build web` antes y después cuando exista la remezcla.
- **Renderer:** el build actual (`build.sh`) es `flutter build web --release` sin `--wasm`, es decir, JS + CanvasKit.
  - Con `Factory.rive`, Rive usa sus propios contextos WebGL. Los navegadores permiten unos 16, compartidos con CanvasKit, así que conviene que haya **como máximo 2 caras montadas a la vez** (barra superior y saludo) o usar `RivePanel`.
  - Para una cara pequeña basta `Factory.flutter`, que pinta en el canvas de Flutter y no abre contextos nuevos.
  - Con `--wasm` (skwasm) no se ha probado; hoy no aplica.

#### 1.3 Qué pedir en la remezcla (para la persona)

Se remezcla en el editor de Rive (gratis), con «Remix in Rive»:

| Qué | Valor |
| --- | --- |
| Artboard | Uno solo, cuadrado (p. ej. 512×512), fondo transparente, nombre **`Ortiz`** |
| State machine | Nombre **`Ortiz`** |
| Entrada `mood` | Número: 0 = reposo, 1 = pensando, 2 = hablando, 3 = contento |
| Entrada `lookX` | Número de −100 (izquierda) a 100 (derecha); 0 = centro |
| Entrada `lookY` | Número de −100 (arriba) a 100 (abajo); 0 = centro |
| Reposo (0) | Parpadeo propio cada ~5 s y una mirada que deriva suave |
| Pensando (1) | Mirada arriba que oscila de lado a lado y boca plana |
| Hablando (2) | Boca que abre y cierra en bucle (~0,18 s) |
| Contento (3) | Ojos en arco «^ ^» y un saltito al entrar; se queda así hasta que `mood` cambie |
| Quitar | Las reacciones propias a hover y clic: la app maneja la mirada con `lookX`/`lookY` |
| Legible | A 32 px (barra superior) y a 96 px (saludo) |
| Colores | Cercanos a la paleta: coral `#FF8466` (acento) sobre ciruela `#241E25`/`#110E12` |
| Peso | `.riv` < 100 KB |

Si la remezcla usa *data binding* (view model) en lugar de entradas de state machine, vale igual con los mismos nombres de propiedad: `mood`, `lookX` y `lookY`.

#### 1.4 Cambio futuro a Rive

- `OrtizFace` decide entre `VectorOrtizFace` (hoy) y `RiveOrtizFace` (cuando exista `assets/rive/ortiz.riv` y la persona lo apruebe).
- Ese cambio trae su propia mini-spec con:
  - la dependencia;
  - el alojamiento del WASM;
  - la medición de peso;
  - el crédito en Ajustes › Acerca de.
- Mientras el WASM carga o si falla, se muestra la cara «Pantalla».

### 2. Especificación de la cara «Pantalla» (`CustomPainter`)

#### 2.1 Interfaz

```dart
enum OrtizMood { idle, thinking, talking, happy }

OrtizFace({required OrtizMood mood, required double size, bool followPointer = true})
```

- **Tamaños:**
  - `OrtizIconSize.xl` (32) en la barra superior y en la cabecera del riel.
  - `OrtizSize.faceHero` (96, **token nuevo**, ver `ortiz-home.md` §9) en el saludo.
- **Accesibilidad:** la cara es decorativa (`ExcludeSemantics`). El estado se anuncia como texto en la barra superior («Pensando…», ver `ortiz-home.md`).
- `RepaintBoundary` + `CustomPaint(painter: …, repaint: controller)`. Un solo `AnimationController` (ticker) por cara, y la cara se pausa fuera de pantalla (`TickerMode`).

#### 2.2 Geometría (caja de 100 × 100 unidades; `u = size / 100`)

| Pieza | Forma (en unidades) | Pintura |
| --- | --- | --- |
| Pantalla | `RRect` x 3, y 9, ancho 94, alto 82, radio 26 | Relleno `surfaceHigh`; borde `line`, grosor `max(OrtizStroke.hairline, 3u)` |
| Ojos (reposo, pensando, hablando) | Dos elipses: centros (35, 45) y (65, 45), rx 6.5, ry 9 | Relleno `accent` |
| Ojos contentos «^ ^» | Arcos: `M28 48 q7 -10 14 0` y `M58 48 q7 -10 14 0` | Trazo `accent`, grosor 5.5u, extremos redondos |
| Boca sonrisa (reposo, contento) | `M38 63 q12 11 24 0` | Trazo `accent`, 5.5u, redondo |
| Boca plana (pensando) | `M43 67 h14` | Trazo `accent`, 5.5u, redondo |
| Boca hablando | Elipse centro (50, 66), rx 7.5, ry 6 | Relleno `accent` |

- **Brillo suave:** cada pieza en `accent` se pinta dos veces.
  1. Primero con `MaskFilter.blur(BlurStyle.normal, σ)`, `σ = max(1, 0.025 · size)` y `accent` con `withValues(alpha: 0.55)`.
  2. Después, sólida.
  
  Equivale al `drop-shadow(0 0 2.5px accent)` de la maqueta.
- **Grupos de transformación:**
  - `follow` (ojos + boca) se desplaza con el puntero.
  - Dentro, `look` (solo los ojos o los arcos) suma la deriva o la oscilación de pensar.
  - El parpadeo escala los ojos en vertical alrededor de y = 45.
- **Colores:** solo `OrtizTokens.of(context)` (`surfaceHigh`, `line`, `accent`). Nada literal.

#### 2.3 Estados y tiempos

Las duraciones de transición salen de `OrtizMotion`. Los ciclos propios del personaje (5 s, 8 s, 1,3 s) son constantes privadas con nombre en `ortiz_face.dart` (p. ej. `_blinkEvery`), no tokens de la suite.

| Estado | Ojos | Boca | Movimiento |
| --- | --- | --- | --- |
| `idle` | Elipses | Sonrisa | **Parpadeo** cada 5 s ± hasta 1,5 s al azar (cada cara con su propia fase): escala Y a 0,08 y vuelta en `OrtizMotion.fast` (180 ms). **Deriva de la mirada** en un ciclo de 8 s: quieta (0, 0) del 0 al 28 %, (−4, 1)u del 38 al 52 %, (4, −1)u del 62 al 78 % y vuelta a 0. Tramos con `OrtizMotion.ease` y fase inicial al azar. |
| `thinking` | Elipses, con parpadeo | Plana | `look` oscila entre (−5, −6)u y (5, −6)u con un periodo de 1,3 s (seno, ida y vuelta). |
| `talking` | Elipses, con parpadeo y deriva | Elipse | La boca escala en Y entre 0,3 y 1, ida y vuelta, cada `OrtizMotion.fast`. |
| `happy` | Arcos «^ ^» | Sonrisa | **Saltito** al entrar: toda la cara sube −14 % de `size` y baja, en `OrtizMotion.slow` (450 ms), con un pico al 40 % y curva `OrtizMotion.ease`. Una sola vez. |

- **Cambio de estado:** la boca y los ojos hacen un *cross-fade* en `OrtizMotion.fast`. El desplazamiento de `look` interpola hacia su nuevo objetivo en `OrtizMotion.fast`.
- **Contento → reposo:** lo decide quien da el ánimo, no el painter. Se vuelve a `idle` a los **1,8 s** (CA-09). Se propone el token `OrtizMotion.celebrate = 1800 ms` (ver `ortiz-home.md` §9).

#### 2.4 Seguir el cursor (web y escritorio con ratón)

- Solo con `PointerDeviceKind.mouse`. Con el tacto no sigue nada.
- `OrtizHomeScreen` escucha `onHover` a pantalla completa (un `MouseRegion`/`Listener` arriba) y pasa la posición global a las caras con `followPointer`.
- Desplazamiento de `follow`: `dir · 6u · min(1, distancia / 260 px)`, donde `dir` es el vector unitario desde el centro de la cara hacia el puntero. Se suaviza hacia el objetivo en `OrtizMotion.base` con `OrtizMotion.ease`.
- Cuando el puntero sale de la ventana, la mirada vuelve a (0, 0) en `OrtizMotion.base`.
- El seguimiento se suma a la deriva y a la oscilación de pensar: no las reemplaza.

#### 2.5 Reducir movimiento (CA-12)

Con `OrtizMotion.reduced(context)` el controlador no corre: no hay parpadeo, deriva, oscilación, boca animada, saltito ni seguimiento del cursor. Cada estado se pinta como una imagen fija, distinta en cada caso:

- `idle`: ojos abiertos y sonrisa.
- `thinking`: ojos desplazados (0, −6)u y boca plana.
- `talking`: boca elipse con escala Y 0,65.
- `happy`: arcos y sonrisa, sin saltito.

El cambio de estado es inmediato.

#### 2.6 Origen del ánimo (para `flutter-dev`, paso 7)

Debe ser una función pura y testeable a partir de `AgenteState`:

- `thinking`: `isGenerating` y el último mensaje del modelo con `content` vacío.
- `talking`: `isGenerating` y ese mensaje ya con texto (`isStreaming`).
- `idle`: en cualquier otro caso.
- `happy`: lo activa el aviso de guardado (`ortiz-home.md` §7) durante `OrtizMotion.celebrate` y tiene prioridad sobre `idle`, pero **no** sobre `thinking`/`talking`.

#### 2.7 Tests sugeridos

- Pinta sin errores en los 4 estados, a 32 y a 96.
- Con `disableAnimations: true` no hay *tickers* activos (`tester.hasRunningAnimations == false`).
- La función de ánimo cubre las transiciones de CA-08 y CA-09.
- No deja Timers pendientes al desmontar.
