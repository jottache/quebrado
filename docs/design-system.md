# Design system v2 — OrtizApp («Ortiz al centro»)

> **Dueño:** `ui-ux-designer` · **Última revisión:** 2026-11-17 (spec 01, `specs/01-tema-oscuro-design-system.md`)
> Describe el sistema **nuevo** (tema oscuro ciruela y coral) tal como está en `quebrado-app-flutter/lib/theme/`. Si este documento y el código no coinciden, **manda el código** y hay que corregir el documento.
> Las cifras de deuda de la §12 se midieron con `grep` sobre `lib/` el 2026-11-17, antes de la spec 01; la spec 01 no tocó pantallas, así que siguen sirviendo como tendencia, no como contrato.
> Reglas operativas para agentes: skill `.claude/skills/ortiz-dark-ui/SKILL.md` (remite aquí para el detalle).
> Maqueta y decisiones C1–C20: https://claude.ai/artifact/TR22XAWd9anJ6xYLXCVn48

Rutas relativas a `quebrado-app-flutter/lib/`.

---

## 1. Principios

1. **Oscuro.** Un solo tema, oscuro, Material 3 (`OrtizTheme.dark` en `main.dart`). El tema claro no existe todavía (C9); los tokens son una `ThemeExtension` para poder añadirlo sin tocar pantallas.
2. **Sin tarjetas (C4).** El contenido va directamente sobre el fondo `bg`, agrupado con **espacio** (`OrtizSpace.xxl` entre grupos) y **líneas finas** (`Divider`, color `line`). Solo **flotan** tres cosas, sobre `surface`: el menú (popup, sidebar, navegación), las hojas y diálogos, y el campo del chat de Ortiz.
3. **Ortiz al centro.** El agente se llama «Ortiz» y su identidad es el acento coral. La spec 02 pone su cara y su chat en la pantalla de inicio.
4. **Un acento.** El coral `accent` es la única acción principal de toda la suite. Cada mini-app tiene un color propio (§2.2) que **solo la señala** (icono, marca, selección dentro de la app); nunca compite con el acento en botones principales. El color del libro activo solo marca el selector de libro y su indicador (PA-01).
5. **Todo es token.** Color, tipografía, espaciado, radio y movimiento salen de `lib/theme/`. Nada literal en pantallas nuevas.
6. **Movimiento sobrio.** Entradas cortas con una sola curva, escalonadas, y cero movimiento si el sistema pide reducirlo.
7. Textos en español, tuteo, frases cortas. La app es **solo web** (Flutter web en Vercel).

## 2. Color

### 2.1 Tokens base — `OrtizPalette` / `OrtizTokens` (`theme/ortiz_tokens.dart`)

- `OrtizPalette`: los valores como constantes `static const` (para widgets `const` y otras clases de color).
- `OrtizTokens`: los mismos valores como `ThemeExtension<OrtizTokens>`; se leen con `OrtizTokens.of(context)` (devuelve `OrtizTokens.dark` si el tema no la registra). Es lo preferido en pantallas nuevas.

| Token | Valor | Uso | Contraste sobre `bg` / `surface` / `surfaceHigh` |
| --- | --- | --- | --- |
| `bg` | `#110E12` | Fondo de toda pantalla | — |
| `surface` | `#1A161B` | Lo que flota: menú, hojas, diálogos, campo del chat, campos de texto | — |
| `surfaceHigh` | `#241E25` | Elemento activo o seleccionado, burbuja del usuario, pista de pestañas | — |
| `line` | `#352B37` | Separadores, bordes de campos y menús | — |
| `fg` | `#F1E9EE` | Texto principal e iconos | 16,1 / 15,0 / 13,7 |
| `muted` | `#9C8F98` | Texto secundario legible (metadatos, fechas, ayudas, pistas) | 6,2 / 5,8 / 5,3 |
| `faint` | `#655A62` | **Solo decorativo** (deshabilitado, adornos). Nunca texto que haya que leer | 2,9 / 2,7 / 2,5 |
| `accent` | `#FF8466` | Acción principal, foco, Ortiz | 8,0 / 7,4 / 6,8 |
| `onAccent` | `#1E0D08` | Texto e iconos **sobre** `accent` (y sobre cualquier relleno de color claro: app, estado) | 7,8 sobre `accent` |
| `ok` | `#7CC9A6` | Éxito, completado | 9,8 / 9,2 / 8,4 |
| `warn` | `#E9B65C` | Aviso, pospuesto, rachas | 10,3 / 9,6 / 8,8 |
| `bad` | `#EF7B6E` | Error, borrar, vencido | 7,1 / 6,6 / 6,0 |
| `income` | = `ok` | Ingreso (PA-02) | — |
| `expense` | = `bad` | Gasto (PA-02) | — |

`test/theme/ortiz_tokens_test.dart` comprueba que `fg` y `muted` cumplen ≥ 4,5:1 sobre las tres superficies (CA-04).

### 2.2 Un color por app — `SuiteApp` / `SuiteAppColors` (`theme/suite_apps.dart`)

`enum SuiteApp { finanzas, diario, habitos, recordatorios, notas }` con `label`, `route`, `icon`, `color`, `tint` y `border`. El Agente no está en el enum: su color es el `accent` (es Ortiz).

| App | `SuiteAppColors.xxxArgb` | Contraste sobre `bg` |
| --- | --- | --- |
| Finanzas | `0xFFE7C06A` | 11,1 |
| Diario | `0xFFEE8FA6` | 8,3 |
| Hábitos | `0xFF6FC3DF` | 9,6 |
| Recordatorios | `0xFFA99BFF` | 8,1 |
| Notas | `0xFFE9D8A6` | 13,5 |

Derivados (operaciones de bits sobre el mismo entero, conservan el RGB y fijan el alpha):

- `xxxTint` — alpha `tintAlpha = 0x29` (≈ 16 %): fondo suave de chips, selección, avatares.
- `xxxBorder` — alpha `borderAlpha = 0x73` (≈ 45 %): borde o separador con color.

**Recolorear una app = cambiar un solo entero** (`SuiteAppColors.diarioArgb`). Cambian a la vez `SuiteApp.diario.color/tint/border`, el `primary`, `primaryLight` y `primaryBorder` de `DiarioColors` y todo lo que los use, sin editar otro archivo (CA-02, `test/theme/suite_apps_test.dart`).

### 2.3 Por qué todo es `const`

Hay cientos de widgets `const` que usan las clases de color de los módulos (`const Icon(…, color: DiarioColors.primary)`). Si un color dejara de ser constante de compilación, esos widgets no compilarían. Por eso:

- Los tokens son `static const Color`, y `SuiteApp.x.color` **no** sirve en un contexto `const` (leer un campo de un valor de enum no es expresión constante): ahí se usa `SuiteAppColors.x`.
- Los derivados con alpha se calculan sobre **enteros** (`(argb & 0x00FFFFFF) | (alpha << 24)`), porque `Color.withValues`, `withAlpha` o leer el ARGB de un `Color` (`toARGB32()`) no son constantes.
- Por eso `OrtizPalette` expone los enteros del acento y de los estados (`accentArgb`, `warnArgb`, `badArgb`) y sus tonos `const` (`accentTint`, `warnTint`, `warnBorder`, `badTint`, con los mismos alphas que `SuiteAppColors`). Los módulos usan esos tonos; no hay copias de enteros fuera de `ortiz_tokens.dart`.
- Fuera de un `const`, en pantallas nuevas, lo correcto es `OrtizTokens.of(context).warn.withValues(alpha: …)`.

### 2.4 `AppColors` — suite y Finanzas (`theme/colors.dart`)

Conserva todos sus nombres públicos (≈ 400 usos), pero ya no define hex: lee `OrtizPalette`.

| Token | Ahora | Nota |
| --- | --- | --- |
| `primary`, `secondary` | `accent` | Fijos y `const`. El acento ya no depende del libro (PA-01). |
| `accent` | `income` | Serie de ingresos puntuales en gráficos, distinta del coral. |
| `background`, `dialogBg` | `bg`, `surface` | |
| `bookColor` + `updateThemeColor()` | color del libro activo | `updateThemeColor` ya no altera `primary`; solo guarda `bookColor`. Hoy nadie lo lee (el selector de libro usa el color de cada perfil); queda reservado para el indicador de libro de la spec 02. |
| `cardBackground` / `cardText` / `cardSubtitleText` / `cardBorderColor` | `surface` / `fg` / `muted` / `line` | Heredados; desaparecen con las tarjetas (spec 05). |
| `mainTab*`, `nestedTab*` | activo `accent` + `onAccent`, inactivo `muted`, pista `surfaceHigh` | |
| `income` / `expense` | `income` / `expense` | |
| `creationColors` | coral, dorado, cielo, lavanda, rosa, menta, ámbar, crema (de `OrtizPalette`/`SuiteAppColors`) | Paleta para lo que se cree desde ahora (decisión 2026-11-17). Los hex ya guardados en libros, cuentas, bolsillos y pagos no cambian. [0] = por defecto de libros y categorías; [1] = de cuentas, bolsillos y recurrentes. |

Colores de moneda (`quebrado/widgets/currency_pill.dart`): siguen siendo constantes propias (`usd #16A34A`, `bs #D97706`, `eur #2563EB`); se revisan en la spec 05.

### 2.5 Clases de color de los módulos → tokens

Todas mantienen sus nombres públicos y son `const`. Ninguna define hex para su primario (CA-03).

| Clase | Primario y variantes | Neutrales y texto | Estados | Hex propios que quedan |
| --- | --- | --- | --- | --- |
| `DiarioColors` (`diario/theme/`) | `diario`; `primaryDark` = `primary` (antes verde oscuro); `primaryLight`/`*Light` = `diarioTint`; `primaryBorder` = `diarioBorder`; alias amber/emerald/purple/blue/cyan = `primary` (minimalismo de un color) | `bg`, `surface`, `surfaceHover` = `surfaceHigh`, `cardBorder` = `line`; `textPrimary` = `fg`; `textSecondary`/`textMuted` = `muted` | `rose` = `bad`; `roseLight` = `badTint` | — |
| `HabitosColors` (`habitos/theme/habitos_terminal_theme.dart`) | `habitos` + tint/border; alias heredados del tema terminal | igual que Diario | rachas `amber` = `warn` (`amberLight` = `warnTint`); recaídas `rose` = `bad` (`roseLight` = `badTint`) | — |
| `RemindersColors` | `recordatorios` + tint/border | igual | P1 `urgent` = `bad`, P2 `high` = `warn`, P3 `medium` = `recordatorios`, P4 `low` = `muted`; `overdue` = `bad`, `snoozed` = `warn`, `completed` = `ok` (los distingue también su icono y etiqueta) | — |
| `NotasColors` | `notas` + tint | igual | callout de aviso = `warnTint`/`warnBorder` | categorías `acuerdosPink #F48FB8`, `ideasAmber #F5C26B`, `datosGreen #72D4A8` (+ `Light`) |
| `AgenteColors` | `accent` (Ortiz); `primaryLight` = `accentTint` | burbuja usuario `surfaceHigh`, bot `surface`, texto `fg`; artefactos `surface` + `line` | `success` = `ok`, `error` = `bad` | `thinking #C3A6FF`, `toolExec #6EC8F0`: no hay token «pensando»/«herramienta» |
| `RichEditorColors` | `accent` estático, lo fija cada app al abrir el editor (por defecto `OrtizPalette.accent`); `accentLight` = `accent` con `tintAlpha` | texto `fg`/`muted`, `border` = `line`, iconos `fg` | callout = `warnTint`/`warnBorder` | — |

Todos los hex propios que quedan se recalibraron para fondo oscuro y cumplen ≥ 4,5:1 sobre `bg` (aptos para texto). Si se repiten en una segunda app, se proponen como token aquí antes de crearlos.

`HabitosStyles` sigue existiendo sin uso; no fija familia, así que hereda Manrope del tema.

## 3. Tipografía — `OrtizType` (`theme/ortiz_type.dart`)

Familias empaquetadas en `assets/fonts/` (sin descarga en tiempo de ejecución, CA-05): **Bricolage Grotesque** (`fontDisplay = 'Bricolage'`) para títulos, **Manrope** (`fontBody`) para texto y **JetBrains Mono** (`fontMono = 'JetBrainsMono'`) para montos, con cifras tabulares. Los estilos no llevan color: lo pone el tema.

| Nombre | Familia | Tamaño / peso | Para |
| --- | --- | --- | --- |
| `caption` | Manrope | 11 / 500 | Etiquetas pequeñas, encabezados de grupo |
| `bodySm` | Manrope | 12 / 400 | Texto secundario, ayudas |
| `body` | Manrope | 14 / 400 | Texto por defecto |
| `titleSm` | Manrope | 16 / 600 | Título de fila o de grupo |
| `title` | Bricolage | 18 / 600 | Título de pantalla (AppBar) |
| `display` | Bricolage | 24 / 700 | Título grande, cifra destacada |
| `displayLg` | Bricolage | 32 / 700 | Saludo de inicio, cabecera |
| `amount` | JetBrains Mono | 14 / 500, tabular | Montos en listas |
| `amountLg` | JetBrains Mono | 24 / 500, tabular | Saldo destacado |

- `OrtizType.textTheme` asigna la escala a los 15 slots de Material 3 (`titleLarge` = `title`, `bodyMedium` = `body`, `bodyLarge` = 16 px para campos, `labelLarge` = botones). `OrtizTheme.darkTextTheme` le pone color: todo `fg` salvo `bodySmall` en `muted`.
- Uso: `Theme.of(context).textTheme.bodyMedium` o `OrtizType.body.copyWith(color: t.muted)`.
- **Campos de texto a 16 px** (`bodyLarge`): por debajo, Safari de iOS hace zoom al enfocar.
- Nada por debajo de 11 px ni medios puntos.

## 4. Espaciado y radio — `OrtizSpace` / `OrtizRadius` (`theme/ortiz_space.dart`)

| `OrtizSpace` | px | Uso típico |
| --- | --- | --- |
| `xs` | 4 | Icono ↔ texto |
| `sm` | 8 | Entre elementos de una fila |
| `md` | 12 | Entre filas de un grupo |
| `lg` | 16 | Margen de pantalla, padding de bloque |
| `xl` | 20 | Padding de hoja y diálogo |
| `xxl` | 24 | **Entre grupos** (lo que antes separaba una tarjeta) |
| `xxxl` | 32 | Entre secciones grandes |

`OrtizSpace.scale` es la lista completa.

| `OrtizRadius` | px | Dónde lo usa el tema |
| --- | --- | --- |
| `chip` | 8 | Chips, tooltips |
| `field` | 12 | Campos, snackbars |
| `menu` | 12 | Menús emergentes |
| `block` | 16 | Bloque agrupado; `Card` mientras exista |
| `dialog` | 20 | Diálogos |
| `sheet` | 22 | Hojas inferiores (solo arriba) |
| `pill` / `pillShape` | 999 / `StadiumBorder()` | Botones y FAB |

`OrtizTheme` toma sus radios de aquí (`test/theme/ortiz_space_test.dart`).

## 5. Movimiento — `OrtizMotion` (`theme/ortiz_motion.dart`)

| Token | Valor | Uso |
| --- | --- | --- |
| `fast` | 180 ms | Hover, toggles, cambios de estado |
| `base` | 320 ms | Entradas, hojas |
| `slow` | 450 ms | Transiciones grandes |
| `stagger` | 60 ms | Retraso entre elementos de una lista |
| `ease` | `Cubic(0.2, 0.8, 0.2, 1)` | Curva única (rápida al empezar, se posa al final) |

- **Reducir movimiento:** `OrtizMotion.of(context, d)` devuelve `Duration.zero` si `MediaQuery.disableAnimations` es verdadero; `OrtizMotion.staggerOf(context, i)` igual para el retraso; `OrtizMotion.reduced(context)` para decidir quitar un efecto (CA-06). Toda animación nueva pasa por ellos.
- **Entradas de lista: `ortizStaggered`** (`widgets/ortiz/ortiz_animate.dart`), con un `AnimationController` propio (el retraso es un `Interval` dentro de la misma animación). **La entrada se ve una sola vez por lista:** dentro de un `Scrollable` solo animan las filas creadas durante la primera tanda; las que aparecen al hacer scroll (o al volver a subir en una lista perezosa) salen ya visibles. **No usar `flutter_animate` para entradas**: su `Animate` siempre programa un `Future.delayed` que no se cancela al desmontar y deja Timers pendientes (rompía widget tests). La dependencia sigue en `pubspec.yaml` sin uso en código (decisión pendiente de la persona: quitarla o reservarla). Las animaciones nativas (`AnimatedContainer`, `AnimatedSwitcher`…) siguen valiendo, con duraciones de `OrtizMotion.of`.

```dart
child.animate(delay: OrtizMotion.staggerOf(context, index))
    .fadeIn(duration: OrtizMotion.of(context, OrtizMotion.base), curve: OrtizMotion.ease)
    .slideY(begin: 0.08, end: 0, duration: OrtizMotion.of(context, OrtizMotion.base), curve: OrtizMotion.ease);
```

- Transiciones de página: Cupertino en todas las plataformas (`pageTransitionsTheme`).

## 6. Componentes de Material ya tematizados (`theme/ortiz_theme.dart`)

`OrtizTheme.dark` se construye una vez y solo con tokens (sin `ColorScheme.fromSeed`). Un widget de Material sin colores propios ya sale bien:

| Componente | Cómo queda |
| --- | --- |
| `ColorScheme` | `primary`/`secondary` = `accent` con `onAccent`; `surface` = `surface`; `onSurface` = `fg`; `onSurfaceVariant` = `muted`; `outline` = `line`; `error` = `bad`; `tertiary` = `ok` |
| Scaffold, AppBar | Fondo `bg`, sin elevación ni tinte; título `title` centrado |
| `Card` | `surface`, sin elevación, borde `line`, radio `block` (transición: no usar en código nuevo) |
| Diálogos, hojas, drawer | `surface`, sin tinte; radios `dialog` y `sheet`; asa de la hoja `line` |
| Campos (`InputDecoration`) | Relleno `surface`, borde en reposo `faint` (2,9:1 sobre `bg`, para que el campo se vea), foco `accent` 2 px, error `bad`; texto, pista y etiqueta a 16 px (pista y etiqueta `muted`) |
| Botones | `Elevated`/`Filled`: `accent` + `onAccent`, píldora; `Outlined`: `fg` con borde `line`; `Text`: `accent`; deshabilitados `surfaceHigh` + `faint`. Foco de teclado: borde de 2 px en `fg` en todos (también `IconButton`) |
| FAB | `accent` + `onAccent`, píldora, sin elevación |
| SnackBar | Flotante, fondo `fg` con texto `bg` (inverso), radio `field` |
| `Divider` | `line`, 1 px |
| Chips | `surface`, seleccionado `surfaceHigh` con borde `accent`; sin seleccionar, borde `line`; radio `chip` |
| `ListTile` | Iconos `muted`, texto `fg`, seleccionado `accent` sobre `surfaceHigh` |
| Switch, Checkbox, Radio | Activo `accent` (pulgar/marca `onAccent`); inactivo `muted`/`surfaceHigh` |
| Progreso | `accent` sobre `surfaceHigh` |
| Pestañas | Activa `fg` con indicador `accent`; inactiva `muted` |
| NavigationRail / NavigationBar / BottomNavigationBar | Seleccionado `accent`, resto `muted`, indicador `surfaceHigh` |
| Tooltip, PopupMenu | `surfaceHigh` / `surface` con borde `line` |
| Selección de texto | Cursor `accent`, resaltado `accent` al 35 % |

## 7. Responsive

Sin cambios en la spec 01.

### 7.1 Clases de ventana — `widgets/responsive_breakpoints.dart`

| Constante | Valor | Helper | Condición |
| --- | --- | --- | --- |
| `compact` | 600 | `isCompact` | ancho < 600 |
| `medium` | 840 | `isMedium` | 600 ≤ ancho < **1200** (usa `compact` y `expanded`, no `medium`) |
| — | — | `isDesktop` | ancho ≥ **840** |
| `expanded` | 1200 | `isExpanded` | ancho ≥ 1200 |

⚠️ **`isMedium` e `isDesktop` se solapan entre 840 y 1199** (ambos `true`), y entre 600 y 839 la ventana es "medium" pero no "desktop", así que recibe el layout **móvil**. La decisión real de layout de toda la app es **`isDesktop` (≥ 840)**: por debajo, layout móvil; por encima, layout de escritorio. Código nuevo: decidir con `isDesktop` / `isExpanded`; no introducir lógica nueva basada en `isMedium` hasta que se corrija (P-23).

### 7.2 Patrones de layout

- **Shell de la suite** (`widgets/responsive_suite_scaffold.dart`, `ResponsiveSuiteScaffold`, montado por `widgets/suite_router.dart`): menú ☰ (`SuiteDrawer`) en `< 840` y riel en `≥ 840`. El inicio (`/`) es la conversación con Ortiz (`screens/ortiz_home_screen.dart`, vía `SuiteOrtizHome`). El launcher y el command center se borraron en la spec 02.
- **Sheets responsivos** (`widgets/responsive_sheet_helper.dart`, `showResponsiveSheet`): en móvil `showModalBottomSheet`; en escritorio **panel lateral derecho** (ancho por defecto 480, mínimo 380, máximo 90 % de la ventana), radio `OrtizRadius.sheet` a la izquierda y fondo `surface`, con **Navigator anidado** para abrir subpantallas dentro del panel. Barrita de arrastre: `showDragHandle: true` (color `dragHandleColor` = `line` del tema, solo en la hoja inferior) junto con `backgroundColor: null` para que la hoja pinte `surface` y la barrita quede sobre ella; el contenido no pinta su propio fondo. Usar siempre este helper para sheets nuevos (hoy convive con 63 `showModalBottomSheet` directos).
- **Scroll horizontal en escritorio** (`ResponsiveHorizontalScroll`, mismo archivo): en escritorio añade botones ◀ ▶ a filas de chips/filtros que en móvil se desplazan con el dedo.
- **Dos columnas en escritorio**: Finanzas (dashboard + subnav), Hábitos (lista + métricas en vivo), Diario (contactos + detalle maestro-detalle). Patrón: columna izquierda de lista/navegación, derecha de detalle o métricas. Sin tarjetas: las columnas se separan con una línea `line` de 1 px.

## 8. Inventario de componentes reutilizables

| Componente | Ruta | Cuándo usarlo |
| --- | --- | --- |
| `OrtizTheme`, `OrtizTokens`, `SuiteApp`, `OrtizType`/`OrtizFontSize`, `OrtizSpace`/`OrtizRadius`/`OrtizIconSize`/`OrtizStroke`/`OrtizSize`, `OrtizMotion` | `theme/` | Siempre (§2–6). `OrtizFontSize.micro` (9) solo en vistas muy densas (celdas de calendario, badges). |
| `OrtizSection` | `widgets/ortiz/ortiz_section.dart` | Agrupar contenido **sin tarjeta**: título `caption` `muted`, separación `xxl`; `divided` para líneas entre filas; `surface` solo para el bloque que de verdad debe destacarse. |
| `OrtizListRow` | `widgets/ortiz/ortiz_list_row.dart` | Fila de lista con punto de color (app, bolsillo, categoría), subtítulo y acción; hover/foco visibles; alto mínimo 48. En un selector, la opción vigente lleva `selected: true, autofocus: true` para que el teclado empiece ahí. |
| `OrtizPill` | `widgets/ortiz/ortiz_pill.dart` | Estado, moneda o etiqueta; elige solo el color de texto con contraste. |
| `OrtizAmount` | `widgets/ortiz/ortiz_amount.dart` | Montos (cifras tabulares); `animate` cuenta hasta el valor; `format:` para reutilizar `formatUSD`/`formatBs`. |
| `OrtizProgressBar` | `widgets/ortiz/ortiz_progress.dart` | Avance de metas; el color del bolsillo va aquí y en el punto, no de fondo. |
| `OrtizEmptyState` | `widgets/ortiz/ortiz_empty_state.dart` | Estados vacíos. |
| `showOrtizNotice` | `widgets/ortiz/ortiz_notice.dart` | Avisos (SnackBar) con acción opcional («Ver», «Deshacer»). |
| `ortizStaggered` | `widgets/ortiz/ortiz_animate.dart` | Entrada escalonada de listas; respeta reducir movimiento. |
| `ResponsiveSuiteScaffold` | `widgets/responsive_suite_scaffold.dart` | Raíz de la app; añadir aquí un módulo nuevo de la suite. |
| `showResponsiveSheet` | `widgets/responsive_sheet_helper.dart` | Cualquier formulario o detalle en hoja (móvil) / panel (escritorio). |
| `ResponsiveHorizontalScroll` | `widgets/responsive_sheet_helper.dart` | Filas horizontales de chips. |
| `ResponsiveBreakpoints` | `widgets/responsive_breakpoints.dart` | Toda decisión responsive. |
| ~~`ClaymorphicCard`~~ | — | **Borrado en la spec 05** (C4): sus ~97 usos pasaron a `OrtizSection`/`OrtizListRow`. `ClaymorphicBackground` sigue existiendo pero solo pinta `bg`. |
| `ClaymorphicBackground` | `quebrado/widgets/claymorphic_background.dart` | Solo pinta `bg` (heredado; quitar cuando se toque la pantalla, P-46). |
| `CurrencyPill` + `currencyColor` / `currencyShortLabel` | `quebrado/widgets/currency_pill.dart` | Etiqueta de moneda (`$`, `Bs`, `€`, o `$ → Bs`) con `AppColors.currencyUsd/Bs/Eur`. |
| `AnimatedProgressBar` | `quebrado/widgets/animated_progress_bar.dart` | Redirige a `OrtizProgressBar`. |
| `PocketCard`, `TimelineEventRow`, `ExchangeSuggestionRow`, `DashboardChartsCard` | `quebrado/widgets/` | Bolsillo, fila del timeline, sugerencia de cambio, gráficos `fl_chart`. |
| Helpers de formato | `quebrado/widgets/helpers.dart` | `formatUSD`, `formatBs`, `formatCurrency`, `formatRate`, `formatDate`, `formatFullDate`, `parseHexColor`, `getIconData`, `CommaTextInputFormatter`. |
| Editor enriquecido | `rich_editor/` (`RichDocumentEditor`, `RichDocumentViewer`, `FormatToolbar`, `DraftBanner`…) | Texto largo con formato en Notas y Diario; fijar `RichEditorColors.accent` al color de la app al abrir. |
| Ánimo | `diario/widgets/mood_*` | Check-in, selector de emoción, calendario mensual, gráfica de tendencia. |
| `MentionTextField` | `diario/widgets/mention_text_field.dart` | Menciones `@contacto`. |
| Vistas de agenda | `recordatorios/widgets/covey_matrix_view.dart`, `weekly_schedule_view.dart` | Matriz 2×2 Covey y agenda semanal. |

## 9. Patrones de UX

- **Agrupar sin tarjetas:** encabezado de grupo en `caption`/`titleSm` color `muted`, filas separadas por `OrtizSpace.md` o por `Divider`, y `OrtizSpace.xxl` entre grupos. Lo seleccionado o activo va sobre `surfaceHigh`. Si un bloque necesita contorno (p. ej. una cita, un código), fondo `surface` con radio `block`, sin sombra.
- **Hoja vs. diálogo:** formularios de creación/edición y detalles → `showResponsiveSheet`. Confirmaciones cortas y avisos → `AlertDialog`. Lectores/editores grandes de escritorio → diálogo grande (`entry_reader_dialog`, `note_reader_dialog`). Código nuevo usa el helper.
- **Acción principal:** un solo botón `accent` por vista (`FilledButton` o FAB). Las demás, `OutlinedButton`/`TextButton`.
- **Confirmaciones de dinero:** botón normal (la confirmación deslizante se eliminó en la spec 05, decisión de la persona); operaciones sensibles protegidas por PIN de 4 dígitos / biometría.
- **Borrado:** siempre con confirmación y en `bad`. No hay «deshacer».
- **Feedback:** `SnackBar` del tema (flotante, inverso). Sin helper común todavía (P-24).
- **Carga:** `CircularProgressIndicator` / `LinearProgressIndicator` del tema; sin skeletons.
- **Vacío:** texto simple en `muted` («Sin registros este día.»). No existe un componente `EmptyState`.
- **Error:** mensaje en español sin `$e`; la app funciona sin Supabase (datos locales / semillas).
- **Montos y monedas:** `OrtizType.amount`/`amountLg` (cifras tabulares); ingreso `income`, gasto `expense`. Formato con `helpers.dart`: USD `"$1234.56"`, EUR `"€1234.56"`, VES `"Bs. 1234.56"`, siempre 2 decimales, sin separador de miles, punto decimal; el input acepta coma (`CommaTextInputFormatter`).
- **Fechas:** `dd/MM/yyyy` y `dd/MM/yyyy HH:mm` (`formatDate`, `formatFullDate`).
- **Textos:** español, tuteo, sin tecnicismos. El agente es «Ortiz».

## 10. Accesibilidad

- **Contraste:** `fg`, `muted`, `accent`, estados y colores de app cumplen ≥ 4,5:1 sobre las tres superficies (§2.1–2.2). `faint` no cumple (2,5–2,9:1): solo decorativo. Texto sobre un relleno claro (`accent`, color de app, estado) → `onAccent`, nunca blanco.
- **Movimiento:** respetar `disableAnimations` (§5).
- **Campos a 16 px** (§3).
- Pendiente (P-22, fuera de la spec 01): 0 `Semantics`/`semanticLabel` medidos el 2026-11-17; objetivos táctiles < 48 por `VisualDensity.compact` y `BoxConstraints()` vacíos; escalado de texto sin probar. En código nuevo: `tooltip` o `Semantics` en todo botón solo-icono, objetivo ≥ 48×48, sin alturas fijas que corten texto.

## 11. Transición (R-01)

Hasta la spec 05 conviven el tema oscuro y pantallas con literales claros. Lo que **sigue claro o mal** y es esperado (filas en `docs/pendientes.md`, sección Diseño, «a resolver en spec 05»):

- **Spec 05 (2026-11-17):** todas las apps quedaron sin valores de estilo escritos a mano (guardián `test/contract/no_hardcoded_styles_test.dart`) y sin tarjetas; lo listado aquí antes (fondos claros, blanco sobre coral, crema de Notas, `ClaymorphicCard` con volumen, literales sueltos) se resolvió en ella.
- El launcher, el hub de acciones y el command center, que quedaban fuera del alcance, se borraron en la spec 02.

Nada de esto se arregla «de paso»: cada pantalla se migra en la spec 05 con sus tests.

## 12. Deuda de diseño medida

| Deuda | Medida aprox. (`grep` en `lib/`, 2026-11-17) |
| --- | --- |
| `Color(0x…)` literales | ~454 fuera de los archivos de tema |
| `Colors.*` de Material directos | ~1 856 (`grey` 614, `white` 600, `black` 277, `transparent` 196, `orange` 42, `red` 33…) |
| `fontSize:` literales | ~1 840 |
| `EdgeInsets.*` literales | ~1 315 |
| `BorderRadius.circular` literales | > 1 000 con 10+ valores distintos |
| `withOpacity` deprecado | 613 |
| Sheets/diálogos sin helper responsivo | 63 `showModalBottomSheet` + 95 `showDialog` |

Resuelto por la spec 01: el primario dinámico a medias (P-21), los cuatro grises de fondo y los dos de borde de las clases de color, los rojos y verdes distintos entre clases (ahora `bad` y `ok`), Notas y Agente compartiendo índigo, y la falta de escala tipográfica, de espaciado y de radio como tokens. Sigue: los literales de las pantallas (P-20), los nombres heredados del tema «terminal» de Hábitos y los shims de re-exportación (`quebrado/theme/colors.dart` → `theme/colors.dart`, etc.; importar siempre la ruta real).

## 13. Reglas

1. **Solo tokens** en código nuevo: color (`OrtizTokens`/`OrtizPalette`, la clase del módulo o `SuiteApp`), tipografía (`OrtizType` o `textTheme`), espaciado (`OrtizSpace`), radio (`OrtizRadius`), movimiento (`OrtizMotion`). Nada de `Colors.white`, hex, `fontSize`, `EdgeInsets` ni radios literales en pantallas. Se toleran `Colors.transparent` y la escala de `OrtizSpace` dentro de `EdgeInsets`.
2. **Sin tarjetas** (§1, §9).
3. Color de app solo vía `SuiteApp`/`SuiteAppColors` (o la clase del módulo, que lo lee de ahí).
4. `withValues(alpha: …)`, no `withOpacity`.
5. **Si falta un token**, `ui-ux-designer` lo propone aquí y lo crea en `lib/theme/` con su test. `flutter-dev` no inventa tokens.
6. Sheets con `showResponsiveSheet`; layout con `ResponsiveBreakpoints.isDesktop` / `isExpanded`; toda vista nueva funciona en compact, medium y expanded.
7. Montos con `helpers.dart` y `OrtizType.amount`; fechas con `formatDate` / `formatFullDate`.
8. **No migrar pantallas existentes «de paso»** (spec 05).

### Checklist de revisión visual (`ui-ux-designer`)

| Severidad | Qué se marca |
| --- | --- |
| **Bloqueante** | Pantalla rota o desbordada en alguna clase de ventana; texto ilegible (contraste < 3:1, `faint` en texto que hay que leer, blanco sobre coral); acción destructiva o de dinero sin confirmación; color de identidad equivocado (otra app); estado de error o vacío que deja la pantalla en blanco. |
| **Importante** | Valor literal nuevo en lugar de token; tarjeta nueva (`Card`, `ClaymorphicCard`, contenedor con sombra); animación que ignora reducir movimiento; sheet sin `showResponsiveSheet`; botón solo-icono sin tooltip/Semantics; objetivo táctil < 48; contraste < 4,5:1; monto formateado a mano o sin `amount`; mensaje con `$e`; falta estado de carga. |
| **Menor** | Valor fuera de la escala; más de una acción en `accent`; textos mejorables (tono, longitud); orden de elementos. |

Ante la duda, se sube la severidad.
