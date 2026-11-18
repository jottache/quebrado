# Inicio de Ortiz, menú, riel, paleta y aviso

> Spec 02 · `specs/02-ortiz-al-centro.md` (Aprobado) · Fecha: 2026-11-17
> Maqueta: https://claude.ai/artifact/TR22XAWd9anJ6xYLXCVn48 · Cara: `docs/design/ortiz-face.md`
> Para `flutter-dev`, pasos 4–8. Rutas y router: `docs/design/rutas.md` (de `architect`).

## Arquitectura y datos

_(Dueño: `architect`. Las rutas están en `docs/design/rutas.md`. No hay cambios de datos.)_

## UI/UX

### 0. Objetivo y uso

- **Qué quiere lograr la persona:**
  - registrar algo en segundos (un gasto, el ánimo, los hábitos) o preguntarle a Ortiz, sin perderse entre apps;
  - ir a una app cuando necesita el detalle.
- **Frecuencia:** varias veces al día.
- **Dispositivos:**
  - **teléfono** (con una mano: lo importante abajo, al alcance del pulgar);
  - **computador** (con teclado: atajos, foco visible, cursor).
- **Puntos de entrada:**
  - URL `/`;
  - ☰ (compact) o el riel (≥ 840);
  - chips sobre el campo;
  - paleta `Ctrl/⌘+K`;
  - el chat mismo.
- **Salidas:**
  - el aviso «✓ … · Ver», que lleva a la URL del registro;
  - «Abrir {App}», que lleva a `/{app}`.

### 1. Clases de ventana

| Clase | Ancho | Layout | Decisión con |
| --- | --- | --- | --- |
| compact + medium móvil | < 840 | Barra superior con ☰ y chat a pantalla completa; menú en `Drawer` | `!ResponsiveBreakpoints.isDesktop` |
| escritorio | 840–1199 | Riel 210 · chat (máx. 720, centrado) · panel derecho 320 | `isDesktop && !isExpanded` |
| expanded | ≥ 1200 | Riel 240 · chat (máx. 720, centrado) · panel derecho 380 | `isExpanded` |

Entre 600 y 839 se usa el layout móvil (§7.1 del design system; no usar `isMedium`). A 840 px el chat queda en unos 310 px: es estrecho pero usable, porque cumple CA-02 (ver la pregunta abierta Q1).

### 2. Inicio de Ortiz (`lib/screens/ortiz_home_screen.dart`)

#### 2.1 Wireframes

**Compact (390 × 844), chat vacío**

```
┌────────────────────────────────────┐
│ ☰   [▣] Ortiz                   ⊕ │ 56 · fondo bg
│         ● Conectado a 5 apps       │      (subtítulo caption muted)
├────────────────────────────────────┤
│                                    │
│              ┌────────┐            │
│              │ ●    ● │  cara 96   │
│              │   ◡    │            │
│              └────────┘            │
│      Buenas tardes, soy Ortiz.     │ displayLg→display (ver 2.3)
│         ¿Qué hacemos hoy?          │
│  Tengo a la vista tus finanzas, el │ body muted, máx. 28ch aprox.
│  diario, los hábitos, los          │
│  recordatorios y las notas.        │
│  [ franja de hoy · vacía (spec 04)]│ slot, 0 px si está vacío
│                                    │
├────────────────────────────────────┤
│ (☀ Resumen del día)(↓ Registrar g… │ chips, scroll horizontal
│ ╭──────────────────────────────╮   │
│ │ Pregúntale algo a Ortiz…  (↑)│   │ campo flota sobre surface
│ ╰──────────────────────────────╯   │
└────────────────────────────────────┘
```

**Compact con conversación:** el saludo desaparece y la lista de mensajes (`ChatMessageBubble`, sin cambios en la 02) ocupa el centro. Los chips y el campo se mantienen abajo.

**Escritorio (≥ 840)**

```
┌──────────────┬───────────────────────────────────────┬──────────────────┐
│ [▣] Ortiz  / │  [▣] Ortiz                         ⊕  │ HOY · MAR 17 NOV │
│──────────────│      ● Conectado a 5 apps             │                  │
│ ● Finanzas  ›│                                       │  (panel de hoy:  │
│ ● Diario    ›│            ┌──────┐                   │   spec 04)       │
│ ▾ Hábitos    │            │●   ●│                    │                  │
│   → Abrir    │            └──────┘                   │  El resumen de   │
│   ☑ Marcar…  │     Buenas tardes, soy Ortiz.         │  hoy llega       │
│   + Nuevo…   │        ¿Qué hacemos hoy?              │  pronto.         │
│ ● Recordat. ›│                                       │                  │
│ ● Notas     ›│                                       │                  │
│              │ (☀ Resumen)(↓ Gasto)(✎ Entrada) ◀ ▶  │                  │
│──────────────│ ╭───────────────────────────────╮     │                  │
│ ⌕ Buscar  ⌃K │ │ Pregúntale algo a Ortiz…  /  (↑)│   │                  │
│ ↺ Conversac. │ ╰───────────────────────────────╯     │                  │
│ ⚙ Ajustes    │                                       │                  │
└──────────────┴───────────────────────────────────────┴──────────────────┘
  210 / 240   1px line   centro flexible, contenido máx. 720  1px line  320 / 380
```

- Fondo `bg` en las tres columnas. El riel también va sobre `bg`: es navegación fija, no flota.
- Las columnas se separan con `VerticalDivider` de 1 px en `line`. No hay tarjetas.
- En las rutas de las apps (`/finanzas`…) el riel se mantiene y el centro pasa a ser la app. **El panel derecho solo existe en `/`.**

#### 2.2 Barra superior

- **Compact:** `AppBar` del tema (fondo `bg`, sin elevación). Se compone de:
  - `leading`: `IconButton(Icons.menu_rounded, tooltip: 'Menú')`, que abre el `Drawer`;
  - título a la izquierda: `OrtizFace(size: OrtizIconSize.xl)` + `OrtizSpace.sm` + columna con «Ortiz» (`OrtizType.title`, `fg`) y la línea de estado;
  - `actions`: `IconButton(Icons.add_comment_outlined, tooltip: 'Nueva conversación')`.
- **Escritorio:** es una cabecera del centro, sin ☰, alineada con la columna de lectura de 720.
- **Línea de estado** (una línea, `OrtizType.caption`, `muted`, con elipsis):
  - con Gemini: punto `OrtizSize.dot` en `ok` + «Conectado a 5 apps»;
  - mientras genera: el punto pasa a `accent` y el texto es `AgenteState.statusMessage` («Pensando…», «Consultando …»), con `Semantics(liveRegion: true)`. Reemplaza el banner de estado que hoy tiene `ChatConversationScreen`;
  - sin Gemini: punto `warn` + «Sin conectar».
- **Nueva conversación:**
  - llama a `startNewSession()` sin confirmación, porque la anterior queda en el historial;
  - si la conversación actual está vacía, no hace nada;
  - el foco va al campo.

#### 2.3 Saludo (chat vacío)

- Columna centrada, con un ancho máximo de `OrtizSize.readableWidth` (420). De arriba abajo:
  - la cara `OrtizSize.faceHero` (96, token nuevo);
  - `OrtizSpace.lg`;
  - el título;
  - `OrtizSpace.sm`;
  - el subtítulo;
  - `OrtizSpace.lg`;
  - la franja de hoy.
- **Título:** `OrtizType.display` (24) en compact y `OrtizType.displayLg` (32) en escritorio, color `fg`. Va en dos líneas: «{Saludo}, soy Ortiz.» / «¿Qué hacemos hoy?».
- **Saludo según la hora**, con un reloj inyectable para los tests:

  | Hora local | Saludo |
  | --- | --- |
  | 05:00–11:59 | «Buenos días» |
  | 12:00–18:59 | «Buenas tardes» |
  | 19:00–04:59 | «Buenas noches» |

- **Subtítulo** (`OrtizType.body`, `muted`, centrado): «Tengo a la vista tus finanzas, el diario, los hábitos, los recordatorios y las notas.»
- **Franja de hoy:** el widget `OrtizTodayStrip(child: null)`. En la 02 no ocupa espacio (`SizedBox.shrink`) y en la spec 04 recibe su contenido. No se muestra ningún texto de relleno en el teléfono.
- La cara grande flota suave solo si no se pide reducir movimiento: ±4 px en Y, ciclo de 5 s. Si se pide, queda quieta.
- Si el alto no alcanza (teléfono con el teclado abierto o texto al 200 %), el saludo va en un `SingleChildScrollView`. Nunca se corta.

#### 2.4 Chat

- Reutiliza la lógica de `ChatConversationScreen`: `AgenteState.messages`, `sendMessage`, el autoscroll y `ChatMessageBubble`.
- **Se extrae** el cuerpo (lista + campo) a un widget sin `Scaffold`, `OrtizChatView`, en `lib/agente/widgets/`. Así lo usan el inicio y, si sigue existiendo, `ChatConversationScreen`.
- `DockedLauncherChat` y `AgenteChatBottomSheet` dejan de usarse en el inicio. Se borran con el launcher (PA-05), salvo que otra pantalla los use.
- La lista se centra con `ConstrainedBox(maxWidth: OrtizSize.chatMaxWidth)` (720, token nuevo) y un margen lateral de `OrtizSpace.lg`.
- En la 02 los mensajes no llevan cara. La única cara animada está en la barra o el saludo (como máximo 2 montadas).
- **Autoscroll:** se usa `OrtizMotion.of(context, OrtizMotion.base)` con `OrtizMotion.ease` (hoy usa 300 ms literal).

#### 2.5 Campo «Pregúntale algo a Ortiz…»

- Flota sobre `surface`, con radio `OrtizRadius.sheet` y borde `line`. Con foco, el borde pasa a `accent` y 2 px (el tema).
- Texto a 16 px (`bodyLarge`, el del tema). Es multilínea de 1 a 5 líneas.
- **Teclas:** `Enter` envía y `Shift+Enter` hace un salto de línea.
- Pista: «Pregúntale algo a Ortiz…» en `muted`. En escritorio, un distintivo `/` a la derecha (`caption` `muted`, borde `line`, radio `chip`) recuerda el atajo.
- **Botón enviar:**
  - objetivo de 48 × 48, círculo de 40 en **`fg` con la flecha en `bg`** (inverso, como en la maqueta), `tooltip: 'Enviar'`. Así el coral queda libre para el chip «Resumen del día» (un solo `accent` por vista);
  - mientras genera, se deshabilita y muestra un `CircularProgressIndicator` de `OrtizIconSize.md` en `bg`.
- El dictado, si el chat actual lo tiene, se conserva igual (spec: «el dictado actual se queda»).
- Margen: `OrtizSpace.md` a los lados y `OrtizSpace.lg` abajo, con `SafeArea`.

#### 2.6 Chips de acción rápida

- Se colocan en una fila sobre el campo, separados entre sí por `OrtizSpace.sm` y del campo por `OrtizSpace.sm`.
- **Desplazamiento:** en compact, horizontal con el dedo; en escritorio, `ResponsiveHorizontalScroll` (◀ ▶).
- **Orden:**
  1. **«Resumen del día»**: `ActionChip` relleno `accent` con texto e icono `onAccent` (`Icons.wb_sunny_outlined`). En la 02 envía al chat el mensaje «Dame el resumen del día» (funciona con el RAG actual) y la spec 04 cambia su comportamiento. **Solo con Gemini**: si no está configurado, se oculta.
  2. Las acciones del catálogo marcadas como chip (§6): Registrar gasto · Nueva entrada · Registrar ánimo · Marcar hábitos de hoy · Nuevo recordatorio. Estilo: chip del tema (`surface`, borde `line`, icono `OrtizIconSize.sm` en el **color de su app**, texto `fg`).
  3. Los atajos de consulta guardados (`AgenteState.quickPrompts`), detrás de un separador vertical de 1 px en `line`:
     - estilo: chip del tema, icono `Icons.bolt_rounded` en `muted`; el texto es la etiqueta o el prompt, con un máximo de unos 28 caracteres y elipsis;
     - al tocarlo **envía** el texto al chat;
     - al final va un chip «＋ Atajo» (`tooltip: 'Nuevo atajo de consulta'`), que abre `PromptEditorDialog`;
     - solo con Gemini.
- **Tamaño:** el chip mide 36 de alto visual, con `materialTapTargetSize: padded` (objetivo de 48). **Sin `VisualDensity.compact`.**
- Mientras el campo tiene texto, la fila se oculta con `AnimatedSize` y `OrtizMotion.fast`, y vuelve cuando el campo queda vacío.

#### 2.7 Panel derecho (≥ 840, solo en `/`)

- **Ancho:** 320 (`OrtizSize.todayPanelWidth`) en escritorio y 380 (`todayPanelWidthExpanded`) en expanded. Fondo `bg`, separado del chat por una línea `line`. Padding `OrtizSpace.xl`.
- **Cabecera:** «HOY · {mar 17 nov}» en `OrtizType.caption`, `muted`, con espaciado de letras del tema. La fecha sale de `intl` en `es`.
- **Contenido 02** (placeholder definido): `OrtizTodayPanel(child: null)`, que muestra una línea `OrtizType.bodySm` `muted`: «El resumen de hoy llega pronto.». La spec 04 le pasa su contenido.
- **Acciones:** las acciones rápidas se abren con `showResponsiveSheet`, cuyo panel lateral derecho (de 480 de ancho por defecto) **cubre** el panel de hoy y deja el chat a la vista detrás del velo. No se cambia el helper.

#### 2.8 Estados del inicio

| Estado | Qué se ve |
| --- | --- |
| Vacío | El saludo, y los chips debajo. |
| Cargando sesiones (`!isInitialized`) | El saludo igual, sin indicador: el chat vacío ya es un estado válido. |
| Generando | Cara en `thinking` y luego en `talking`; la línea de estado muestra `statusMessage`; enviar se deshabilita. |
| Error de Gemini | El mensaje de error de `AgenteState` en la burbuja (texto en español, sin `$e`); la cara vuelve a `idle`. |
| **Sin Gemini** (`!GeminiConfig.isConfigured`) | <ul><li>Línea de estado: «Sin conectar».</li><li>En el saludo, el subtítulo cambia por «Ortiz no está conectado; las acciones rápidas siguen funcionando.» y debajo va `TextButton('Conectar a Ortiz')`, que abre `AgenteSettingsDialog`.</li><li>Con mensajes en pantalla, la misma frase va en una línea `bodySm` `muted` sobre los chips.</li><li>El campo queda deshabilitado (pista en `muted`, no en `faint`).</li><li>Se ocultan «Resumen del día» y los atajos de consulta.</li><li>El menú, el riel, la paleta y las acciones funcionan igual.</li></ul> |
| Sin Supabase | Cada app usa su respaldo; el chat y las acciones funcionan igual. No hay mensaje especial. |
| URL desconocida | Redirige a `/` y muestra `showOrtizNotice(context, 'Esa página no existe')`. |
| Texto grande (200 %) | <ul><li>Título y estado de la barra: una línea cada uno, con elipsis.</li><li>Saludo: hace scroll.</li><li>Chips: se desplazan.</li><li>Campo: crece hasta 5 líneas.</li></ul> |

### 3. Menú ☰ en compact (`lib/widgets/suite_drawer.dart`)

```
┌──────────────────────────────┐
│ OrtizApp                  ✕  │ title · IconButton 'Cerrar menú'
│                              │
│ [▣] Ortiz                    │ fila activa en `/` → surfaceHigh
│ [■] Finanzas              ›  │ icono en tint de app, 32×32
│     Cuentas, bolsillos y pagos│ caption muted
│╭────────────────────────────╮│
││[■] Hábitos               ⌄ ││ abierta → surfaceHigh, radio block
││    Rachas de hoy           ││
││      → Abrir Hábitos       ││ subfilas ≥ 48, body muted→fg
││      ☑ Marcar hábitos de hoy││
││      ＋ Nuevo hábito        ││
│╰────────────────────────────╯│
│ [■] Recordatorios         ›  │
│ [■] Notas                 ›  │
│──────────────────────────────│ Divider
│ ↺ Conversaciones anteriores  │
│ ⚙ Ajustes                    │
└──────────────────────────────┘
```

- **Contenedor:** el `Drawer` del tema (`surface`, ancho por defecto 304). Es de lo poco que flota.
- **Cabecera:**
  - «OrtizApp» en `OrtizType.title`;
  - `IconButton(Icons.close_rounded, tooltip: 'Cerrar menú')`.
- **Fila «Ortiz»:** cara de 24 (`OrtizIconSize.lg`) + «Ortiz». Lleva a `/`.
- **Una fila por `SuiteApp`**, en el orden del enum:
  - un cuadro de 32 (`OrtizIconSize.xl`) con fondo `SuiteApp.x.tint` y radio `chip`, y dentro el `SuiteApp.x.icon` de `OrtizIconSize.md` en `SuiteApp.x.color`;
  - el nombre en `titleSm` `fg`;
  - la descripción en `caption` `muted`;
  - un chevron `Icons.chevron_right_rounded` en `muted`, que gira 90° al abrir (`OrtizMotion.base`).
- **Descripciones:**

  | App | Descripción |
  | --- | --- |
  | Finanzas | «Cuentas, bolsillos y pagos» |
  | Diario | «Entradas, contactos y ánimo» |
  | Hábitos | «Rachas de hoy» |
  | Recordatorios | «Agenda y matriz Covey» |
  | Notas | «Notas y acuerdos» |

- **Acordeón (CA-03):**
  - tocar una app la abre y cierra la que estuviera abierta; tocar la abierta la cierra;
  - el contenido se anima con `AnimatedSize`/`SizeTransition` en `OrtizMotion.base` y `OrtizMotion.ease` (instantáneo si se pide reducir movimiento);
  - la app abierta va sobre `surfaceHigh` con radio `OrtizRadius.block`;
  - al abrir el menú no hay ninguna app desplegada, salvo la de la ruta actual si se abre desde una app.
- **Subfilas:**
  - van sangradas para alinearse con el nombre de la app (`OrtizSpace.lg + 32 + OrtizSpace.md`) y tienen un alto mínimo de 48;
  - llevan icono `OrtizIconSize.md` en `muted` y texto `body` en `muted`, que pasa a `fg` con hover o foco;
  - la primera siempre es «Abrir {App}» (`Icons.arrow_forward_rounded`) y navega a `SuiteApp.x.route`.
- **Al elegir una acción**, primero se cierra el drawer y luego se abre el formulario (así la hoja no queda debajo).
- **Pie:**
  - `Divider` y luego «Conversaciones anteriores» (`Icons.history_rounded`) y «Ajustes» (`Icons.settings_outlined`);
  - son filas de 48 con `body` `muted`.

### 4. Riel (≥ 840) (`lib/widgets/suite_rail.dart`)

- **Ancho:** `OrtizSize.railWidth` (210), y `railWidthExpanded` (240) en expanded. Fondo `bg` y línea `line` a la derecha. Reemplaza el sidebar de `ResponsiveSuiteScaffold`.
- **Contenido:** las mismas filas que el drawer (Ortiz arriba, luego las 5 apps, y el pie). Las diferencias:
  - las filas de las apps no llevan descripción (el riel es estrecho); el nombre va con elipsis;
  - **activo:** la app de la ruta actual va sobre `surfaceHigh`, nombre en `fg` y desplegada por defecto;
  - **hover:** fondo `fg` con `withValues(alpha: 0.05)` y el chevron visible (en reposo, el chevron solo se ve en la fila activa o con foco). Además aparece a la derecha un `IconButton(Icons.arrow_forward_rounded, tooltip: 'Abrir {App}')` para ir a la app con un solo clic sin desplegar. Es la lectura de «acciones al pasar el cursor» sin que el riel salte de alto;
  - **clic en la fila:** despliega o pliega el acordeón, igual que en el teléfono (una sola app abierta).
- **Pie del riel:**
  1. «Buscar» (`Icons.search_rounded`) con el distintivo «Ctrl K» o «⌘ K» según la plataforma, que abre la paleta;
  2. «Conversaciones anteriores»;
  3. «Ajustes».
- **Acciones:** se abren con `showResponsiveSheet`, es decir, en el panel derecho (§2.7).

### 5. Paleta de comandos `Ctrl/⌘+K` (`lib/widgets/suite_command_palette.dart`)

Toma el patrón visual de `recordatorios/dialogs/command_palette_dialog.dart` (diálogo arriba, buscador, línea, secciones con encabezado y pie con teclas), pero generalizado. **La de Recordatorios no se toca** (no se migra «de paso»).

```
            ┌─────────────────────────────────────────────┐
            │ ⌕  Busca una app o una acción…         ESC  │
            ├─────────────────────────────────────────────┤
            │ APPS                                        │
            │ ▌[▣] Ortiz                                  │ ← resaltado surfaceHigh
            │  [■] Finanzas                               │
            │ ACCIONES RÁPIDAS                            │
            │  ↓  Registrar gasto              ● Finanzas │
            │  ☑  Marcar hábitos de hoy        ● Hábitos  │
            │ ORTIZ                                       │
            │  ⊕  Nueva conversación                      │
            ├─────────────────────────────────────────────┤
            │ ↑↓ Moverte   ↵ Abrir   Esc Cerrar           │ solo ≥ 840
            └─────────────────────────────────────────────┘
```

- **Contenedor:** `Dialog` alineado arriba (`Alignment.topCenter`), con `insetPadding` de `OrtizSpace.xxxl` arriba en escritorio y `OrtizSpace.lg` en compact. Ancho máximo `OrtizSize.paletteMaxWidth` (560, token nuevo) y alto máximo del 70 % de la ventana. Fondo `surface`, radio `OrtizRadius.dialog` y borde `line`.
- **Buscador:** `TextField` con `autofocus`, a 16 px y sin borde, con el icono `search` en `muted` y la pista «Busca una app o una acción…». A la derecha, el distintivo «ESC».
- **Secciones** (encabezados en `caption` `muted`):
  - **Apps:** «Ortiz» y las 5 apps (navegan);
  - **Acciones rápidas:** todo el catálogo §6 salvo «Abrir»; a la derecha, un punto de color con el nombre de la app en `caption` `muted`;
  - **Ortiz:** «Nueva conversación», «Conversaciones anteriores» y «Ajustes».
- **Filtrado al escribir:**
  - sin distinguir mayúsculas ni tildes («habitos» encuentra «Hábitos»);
  - cada palabra de la búsqueda debe aparecer en `etiqueta + nombre de la app + palabras clave` (§6);
  - primero salen los que empiezan por la búsqueda y después el resto, en el orden del catálogo;
  - se ocultan las secciones vacías.
- **Teclado:**
  - `↑`/`↓` mueve el resaltado (recorre todas las filas visibles, de forma circular) y lo mantiene a la vista con `Scrollable.ensureVisible`;
  - `Enter` ejecuta la fila resaltada;
  - `Esc` cierra;
  - `Ctrl/⌘+K` con la paleta abierta también la cierra;
  - el hover del ratón mueve el resaltado;
  - al escribir, el resaltado vuelve a la primera fila.

  (Esto corrige el `_selectedIndex` sin uso del patrón original.)
- **Fila:** alto mínimo de 48, icono `OrtizIconSize.md`, texto `body` `fg`. La resaltada va sobre `surfaceHigh` con radio `chip` y `Semantics(selected: true)`.
- **Al ejecutar:** primero se cierra la paleta y después se navega o se abre el formulario.
- **Sin resultados:** «Nada coincide con «{búsqueda}».» en `bodySm` `muted`. Con Gemini, se añade una fila «Pregúntale a Ortiz: «{búsqueda}»» (`Icons.auto_awesome_rounded` en `accent`) que envía la búsqueda al chat de `/`.
- **Pie con las teclas:** solo ≥ 840. En el teléfono no aporta.

### 6. Catálogo `SuiteAction` (`lib/widgets/suite_actions.dart`)

Una sola lista alimenta el menú, el riel, los chips y la paleta. Cada acción tiene estos campos: `app`, `label`, `icon`, `keywords`, `chip` (si sale como chip), `open(context)` → `Future<SuiteActionResult?>` (registro + `noticeText` + `viewRoute`). Los iconos son de Material `_rounded`.

| App | Acción | Icono | Chip | Abre | Aviso al guardar | «Ver» → |
| --- | --- | --- | --- | --- | --- | --- |
| Finanzas | Registrar gasto | `arrow_downward` | ✓ | `AddTransactionDialog(initialType: expense)` | «Gasto registrado» | `/finanzas/movimientos/:id` |
| Finanzas | Registrar ingreso | `arrow_upward` | — | `AddTransactionDialog(initialType: income)` | «Ingreso registrado» | `/finanzas/movimientos/:id` |
| Finanzas | Tasas del día | `currency_exchange` | — | Aviso, sin formulario | «BCV {r} · Paralelo {r} · Euro {r}» (`formatRate`, sin marca ✓). Si alguna es 0: «Aún no tengo las tasas de hoy» | «Ver» → `/finanzas` |
| Finanzas | Pagos pendientes | `pending_actions` | — | `PendingConfirmationsDialog` | «Pago confirmado» | `/finanzas/pagos` |
| Diario | Nueva entrada | `edit` | ✓ | `entry_editor_dialog` | «Entrada guardada» | `/diario/entradas/:id` |
| Diario | Registrar ánimo | `mood` | ✓ | `MoodCheckinSheet` | «Ánimo registrado» | `/diario/animo` |
| Diario | Nuevo contacto | `person_add_alt` | — | `ContactEditorDialog` | «Contacto guardado» | `/diario` (no hay ruta de contacto; Q3) |
| Hábitos | Nuevo hábito | `add_task` | — | `habit_terminal_editor_dialog` | «Hábito creado» | `/habitos/:id` |
| Hábitos | Marcar hábitos de hoy | `checklist` | ✓ | Hoja §8 | «Hábitos de hoy: {n} de {m} hechos» | `/habitos` |
| Recordatorios | Nuevo recordatorio | `add_alert` | ✓ | `ReminderEditorDialog` | «Recordatorio creado» | `/recordatorios/:id` |
| Recordatorios | Agenda de la semana | `calendar_view_week` | — | `WeeklyScheduleView` en `showResponsiveSheet` (`desktopWidth` 720) | — (no guarda) | — |
| Notas | Nueva nota | `note_add` | — | `NoteEditorScreen` (pantalla completa en el teléfono, panel en escritorio; PA-04) | «Nota guardada» | `/notas/:id` |
| Notas | Nuevo acuerdo | `handshake` | — | `NoteEditorScreen(initialCategoryId: NoteCategory.acuerdosCategoryId)` | «Acuerdo guardado» | `/notas/:id` |

- La tabla de la spec trae «Registrar gasto / ingreso» y «Nueva nota / Nuevo acuerdo» juntas; aquí se separan en dos acciones cada una, como en la maqueta, porque los textos del aviso son distintos y así se ahorra un toque.
- **Palabras clave** (para la paleta):

  | Acción | Palabras clave |
  | --- | --- |
  | Registrar gasto | «pago compra egreso» |
  | Registrar ingreso | «cobro sueldo» |
  | Tasas del día | «dólar bcv paralelo euro cambio» |
  | Registrar ánimo | «humor emoción» |
  | Nueva entrada | «diario escribir» |
  | Nuevo recordatorio | «tarea pendiente alarma» |
  | Nuevo acuerdo | «reunión compromiso» |

- **Cómo se abre cada formulario:** con el `show…` que ya tiene cada uno. Si el formulario es contenido de hoja, se abre con `showResponsiveSheet`. Si es un `Dialog` propio, se abre como está hoy, para no rehacerlo (spec 05).

### 7. Aviso al guardar (C8)

- Se usa `showOrtizNotice(context, texto, success: true, actionLabel: 'Ver', onAction: () => go(viewRoute))`.
- **La marca ✓ la pone `success`**: el texto **no** lleva «✓» (para no repetirla).
- **Cuándo aparece:**
  - solo si el formulario devuelve un registro;
  - si se cierra sin guardar, no hay aviso;
  - si el guardado falla, el error lo muestra el propio formulario y no hay aviso de éxito.
- **«Ver»:**
  - solo si hay `viewRoute`;
  - si el registro no tiene id (R-04, guardado local sin id), el aviso sale sin «Ver».
- **La URL no cambia** al guardar: sigue en `/` (CA-04).
- **La cara pasa a `happy`** durante `OrtizMotion.celebrate` (1,8 s) cuando aparece un aviso con `success` (CA-09). Tasas y «Esa página no existe» no son de éxito y no la activan.
- **Duración:** la del SnackBar del tema. Con navegación accesible activa, se queda hasta que se pulse (ya lo hace el helper).
- **Posición:** flotante abajo. En el teléfono puede tapar un momento el campo; es aceptable.

### 8. Hoja «Marcar hábitos de hoy» (PA-03) (`lib/habitos/widgets/today_habits_sheet.dart`)

**Qué hábitos entran.** Hoy no hay reglas de programación: `frequencyType` no filtra la lista en Hábitos, así que entran **todos los hábitos activos** (`HabitosState.allHabits`, sin archivados) **buenos** (`!isNegative`), en su orden actual. Cada tipo se marca igual que en `habitos_home_screen.dart`:

| Tipo (bueno) | Control en la hoja | Llama a | Subtítulo |
| --- | --- | --- | --- |
| `binary` | Casilla | `toggleHabitCompletion` | — |
| `quantitative` | Casilla (al marcar llega a la meta; al desmarcar vuelve a 0, como en Hábitos) | `toggleHabitCompletion` | «{valor} / {meta} {unidad}» |
| `timer` | Casilla (marca la meta cumplida, sin cronómetro) | `toggleHabitCompletion` | «{meta en min} min» |
| `counter` | Botón «+1» (`OutlinedButton`, objetivo de 48, `tooltip: 'Sumar 1'`), sin casilla | `incrementCounter(dateStr: hoy)` | «{n} {unidad ?? 'veces'} hoy» |

- **Malos hábitos (`isNegative`): no entran.** Su día limpio se cuenta solo, y una recaída necesita la confirmación que ya tiene Hábitos. Al pie, en `bodySm` `muted`, va «Los malos hábitos se registran en Hábitos.» con `TextButton('Abrir Hábitos')`. Q2 confirma esta decisión.
- ⚠️ **Fecha:**
  - `toggleHabitCompletion` marca la **fecha seleccionada en Hábitos** (`selectedDateKey`), no hoy. La hoja tiene que marcar **hoy** sin cambiar la fecha que se ve en Hábitos;
  - `flutter-dev` añade un parámetro opcional `dateKey` a `toggleHabitCompletion` (con su test) y la hoja pasa `todayKey`, calculado al abrirse;
  - no se usa `selectToday()`, porque cambiaría la vista de Hábitos.
- **Vista:** `showResponsiveSheet`, con el panel derecho en escritorio y la hoja inferior en el teléfono.

```
──────  (asa)
Hábitos de hoy                     title
3 de 5 hechos                      bodySm muted (n/m de los listados)
──────────────────────────────────
[☑] ● Meditar                      fila ≥ 48, toda la fila toca la casilla
[☐] ● Leer         0 / 20 pág      
[☐] ● Agua         750 / 2000 ml
     ● Café         2 veces hoy    [ +1 ]
──────────────────────────────────
Los malos hábitos se registran en Hábitos.  [Abrir Hábitos]
                                   [   Listo   ]  FilledButton accent
```

- **Fila:** `CheckboxListTile` o una fila propia sobre `bg`/`surface` sin tarjeta, con `Divider` entre filas, punto `OrtizSize.dot` en el color del hábito y título `body` `fg`.
- **Casilla:** se rellena con `SuiteApp.habitos.color` y la marca va en `onAccent`, como la identidad de Hábitos en su pantalla.
- **Guardado:** cada toque guarda al instante (optimista, como en Hábitos). No hay «Guardar».
- **«Listo»:** cierra la hoja. Si cambió algo, muestra el aviso «Hábitos de hoy: {n} de {m} hechos» · Ver → `/habitos`, y la cara pasa a `happy`. Si no cambió nada, no hay aviso.
- **Estados:**
  - **cargando** (`isLoading`): `LinearProgressIndicator` bajo el título;
  - **sin hábitos:** `OrtizEmptyState` con «Aún no tienes hábitos» y el botón «Crear hábito», que abre la acción «Nuevo hábito»;
  - **solo malos hábitos:** «No tienes hábitos para marcar hoy» y la línea de los malos hábitos;
  - **sin Supabase:** funciona con las semillas en memoria;
  - **nombres largos:** dos líneas y elipsis;
  - **muchos hábitos:** la lista hace scroll y «Listo» queda fijo abajo.
- **Accesibilidad:** cada casilla con `Semantics(label: '{hábito}, {hecho|sin hacer}')`, y el «+1» con la etiqueta «Sumar 1 a {hábito}».

### 9. Tokens y componentes

**Componentes existentes:**

- `showOrtizNotice`, `OrtizListRow` (para el historial y Ajustes), `OrtizEmptyState`, `OrtizSection`;
- `ortizStaggered` (entrada de las filas del drawer y del riel: solo la primera vez, sin repetirse al reabrir);
- `showResponsiveSheet`, `ResponsiveHorizontalScroll` y `ResponsiveBreakpoints`.

**Tokens nuevos** (los crea `ui-ux-designer` en `lib/theme/` con su test y en `docs/design-system.md` **antes del paso 4**; `flutter-dev` no los inventa):

| Token | Valor | Uso |
| --- | --- | --- |
| `OrtizSize.railWidth` / `railWidthExpanded` | 210 / 240 | Riel (hoy literal en `responsive_suite_scaffold.dart`) |
| `OrtizSize.todayPanelWidth` / `todayPanelWidthExpanded` | 320 / 380 | Panel derecho del inicio |
| `OrtizSize.chatMaxWidth` | 720 | Columna de lectura del chat |
| `OrtizSize.paletteMaxWidth` | 560 | Paleta de comandos |
| `OrtizSize.faceHero` | 96 | Cara del saludo |
| `OrtizMotion.celebrate` | 1800 ms | Duración de `happy` tras guardar |

### 10. Atajos y foco (escritorio)

| Tecla | Efecto | Nota |
| --- | --- | --- |
| `Ctrl/⌘+K` | Abre la paleta o la cierra | Funciona en cualquier ruta, también con el foco en un campo |
| `/` | Lleva el foco al campo del chat | Solo en `/` y solo si el foco **no** está en un campo de texto |
| `Esc` | Cierra lo que esté encima | Prioridad: paleta → hoja o panel → drawer → quita el foco del campo |
| `Enter` / `Shift+Enter` | En el campo: envía / salto de línea | — |

- **Orden de foco en escritorio:** riel (de arriba abajo) → cabecera (Nueva conversación) → mensajes → chips → campo → panel.
- **Anillo de foco:** el del tema (2 px en `fg`). Las filas propias del riel y del drawer usan `FocusableActionDetector`/`InkWell` con el mismo anillo.
- **Al cerrar** una hoja o la paleta, el foco vuelve a quien la abrió.
- **Acordeón:**
  - cada fila de app con `Semantics(button: true, expanded: abierta)`;
  - `Enter` y `Space` despliegan o pliegan.
- **Botones solo-icono:** todos con `tooltip` («Menú», «Cerrar menú», «Nueva conversación», «Enviar», «Abrir {App}», «Nuevo atajo de consulta»).
- **Objetivos:** ≥ 48 × 48 en todo, incluidos los chips (padded) y las subfilas.
- **Contraste:** `fg`/`muted` sobre `bg`/`surface`/`surfaceHigh` (≥ 5,3:1); `onAccent` sobre `accent`; iconos de app sobre su tint (≥ 8:1 sobre `bg`); `faint` solo en adornos.
- **Reducir movimiento:** acordeón, chevron, chips, cara y saludo, todos sin animación.

### 11. Textos (exactos)

| Dónde | Texto |
| --- | --- |
| Barra / riel | «Ortiz», «Conectado a 5 apps», «Sin conectar» |
| Saludo | «Buenos días / Buenas tardes / Buenas noches, soy Ortiz.» · «¿Qué hacemos hoy?» · «Tengo a la vista tus finanzas, el diario, los hábitos, los recordatorios y las notas.» |
| Sin Gemini | «Ortiz no está conectado; las acciones rápidas siguen funcionando.» · «Conectar a Ortiz» |
| Campo | «Pregúntale algo a Ortiz…» |
| Chips | «Resumen del día» · «＋ Atajo» |
| Panel | «HOY · {fecha}» · «El resumen de hoy llega pronto.» |
| Menú | «OrtizApp» · «Abrir {App}» · «Conversaciones anteriores» · «Ajustes» · «Buscar» |
| Paleta | «Busca una app o una acción…» · «Apps» · «Acciones rápidas» · «Ortiz» · «Nueva conversación» · «Nada coincide con «{q}».» · «Pregúntale a Ortiz: «{q}»» · «Moverte» · «Abrir» · «Cerrar» |
| Avisos | Ver §6 y §7 · «Esa página no existe» |
| Historial | «Conversaciones» · «{n} mensajes · {dd/MM/yyyy}» · «Aún no hay conversaciones» · borrar: «¿Borrar esta conversación?» / «Se borran sus mensajes. No se puede deshacer.» / «Cancelar» / «Borrar» (en `bad`) |
| Ajustes | «Ortiz» (clave, modelo y atajos de consulta) → `AgenteSettingsDialog` · «Finanzas» (PIN, respaldos y libros) → `SettingsScreen` · «Acerca de» |

En ningún sitio dice «Agente Ortiz» (CA-11). La pista actual «Pregúntale al Agente Ortiz...» desaparece con el campo nuevo.

### 12. Tests de widget sugeridos (por clase de ventana)

- **compact:**
  - ☰ visible;
  - saludo según el reloj inyectado (3 franjas);
  - chips y campo;
  - sin riel (CA-01).
- **desktop (1000×800) y expanded (1280×800):**
  - riel con 5 apps, chat y panel (CA-02);
  - anchos del riel y del panel según la clase.
- **Acordeón:** abrir Finanzas cierra Hábitos (CA-03).
- **Sin Gemini:**
  - aparece el texto;
  - el campo está deshabilitado;
  - los chips de acción siguen activos.
- **Paleta:**
  - filtra «habitos» → «Marcar hábitos de hoy»;
  - `↓` + `Enter` ejecuta;
  - `Esc` cierra.
- **Hoja de hábitos:**
  - excluye los malos hábitos;
  - marca la fecha de hoy aunque Hábitos tenga otra seleccionada;
  - el contador suma 1.
- **Reducir movimiento:** `disableAnimations` → sin animaciones activas.

### 13. Preguntas abiertas

**Resueltas por la persona el 2026-11-17** (prevalecen sobre las propuestas de abajo):
- **Q1:** el panel «Hoy» aparece **solo desde 1200 px**; entre 840 y 1199 se ven riel + chat (CA-02 se entiende así: panel en `≥ 1200`).
- **Q2 / Q4:** la hoja «Marcar hábitos de hoy» muestra **solo los hábitos buenos programados para hoy** (respeta días específicos y metas semanales; regla confirmada por la persona). Los malos hábitos se registran en Hábitos.
- **Q3:** «Ver» de «Nuevo contacto» abre la **ficha del contacto** con una ruta nueva `/diario/contactos/:id`.
- **Q5:** (decisión de diseño del hilo principal, no de negocio) «Ajustes» del pie del menú abre los **ajustes existentes**; en ellos se añade una sección **«Acerca de»** con los créditos (fuentes OFL y, si se adopta, el personaje de Rive).
- **Q6:** en compact, todas las apps llevan **☰** a la izquierda; Ortiz es la primera entrada del menú y Atrás del navegador sigue funcionando.
- **Tokens nuevos creados** en `lib/theme/ortiz_space.dart` (`OrtizSize.railWidth/railWidthExpanded/todayPanelWidth/todayPanelWidthExpanded/chatMaxWidth/paletteMaxWidth/faceHero`) y `lib/theme/ortiz_motion.dart` (`OrtizMotion.celebrate`).

- **Q1:** a 840 px el chat queda en unos 310 px por el panel de 320. ¿Se acepta, o entre 840 y 1023 se colapsa el panel tras un botón «Hoy»? (Esto último contradice la letra de CA-02.)
- **Q2:** en «Marcar hábitos de hoy», ¿se dejan fuera los malos hábitos (propuesta) o se añade «Registrar recaída» con confirmación?
- **Q3:** «Nuevo contacto» no tiene ruta de detalle en la spec. ¿«Ver» lleva a `/diario` o a una ruta nueva `/diario/contactos/:id` (decisión de `architect` en `rutas.md`)?
- **Q4:** ¿Los hábitos con `customDays`/`weeklyTarget` deberían filtrarse por el día de hoy? Hoy Hábitos no lo hace: es una regla de negocio y la decide la persona.
- **Q5:** ¿«Ajustes» es una hoja (propuesta) o una ruta `/ajustes`? ¿Y dónde vive «Acerca de»? (Hoy no existe; el crédito del conejo solo hace falta si se adopta el `.riv`.)
- **Q6:** ¿En compact, las apps (`/finanzas`…) llevan ☰ o «atrás» hacia Ortiz? Lo decide `rutas.md`; la barra de cada app es de la spec 05.
