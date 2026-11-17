# Design system — OrtizApp / Quebrado

> **Dueño:** `ui-ux-designer` · **Última revisión:** 2026-11-17
> Describe el design system **tal como está hoy** en `quebrado-app-flutter/lib/`, no uno ideal. Si este documento y el código no coinciden, **manda el código** y hay que corregir el documento.
> Las cifras de la §7 se midieron con `grep` sobre `lib/` el 2026-11-17; son aproximadas y sirven para ver la tendencia, no como contrato.

Rutas relativas a `quebrado-app-flutter/lib/`.

---

## 1. Principios y personalidad visual

La app es una **suite** ("OrtizApp", `MaterialApp.title`) con un launcher y seis mini-apps. Comparten una base y cada una tiene un color de identidad propio.

**Común a toda la suite**

- Tema **claro** únicamente (no hay `darkTheme` ni `Brightness.dark`).
- Material 3 (`useMaterial3: true`), tipografía **Josefin Sans** vía `GoogleFonts.josefinSansTextTheme` en `main.dart`.
- Estilo "minimalista limpio": fondo gris muy claro, tarjetas blancas con borde de 1 px gris claro y sombra suave o ninguna (`elevation: 0` es lo habitual: 92 usos).
- Transiciones de página tipo Cupertino en todas las plataformas.
- Radios generosos (10–16 px en tarjetas, 20 px en `ClaymorphicCard`, 24 px en sheets).
- Textos en español, tono cercano y directo (tuteo).

**Identidad por mini-app**

| Mini-app | Clase de color | Primario | Personalidad |
| --- | --- | --- | --- |
| Launcher / Quebrado (finanzas) | `AppColors` (`theme/colors.dart`) | `#1F6F5F` verde azulado, **dinámico** | "Claymórfico": tarjetas con volumen (solo cuando la tarjeta es de color; las blancas son planas con sombra suave). Montos y monedas protagonistas. |
| Diario Jottache (+ Ánimo) | `DiarioColors` | `#1F6F5F` fijo | Minimalista de un solo color: casi todos los "acentos" (amber, emerald, purple, blue, cyan) apuntan al primario a propósito. Rojo solo para borrar. |
| Hábitos | `HabitosColors` / `HabitosStyles` (`habitos/theme/habitos_terminal_theme.dart`) | `#1F6F5F` fijo | Antes era estilo terminal (de ahí nombres como `habit_terminal_editor_dialog`, `mono`, `prompt`, `textGreen`); hoy es minimalista claro. Ámbar para rachas, rojo para recaídas. |
| Recordatorios / Agenda Covey | `RemindersColors` | `#2E5B88` slate indigo | Sobrio, colores por prioridad P1–P4 y por estado (vencido, pospuesto, completado). |
| Notas & Acuerdos | `NotasColors` | `#6366F1` índigo | Cuaderno digital tipo Notion: acentos por categoría (acuerdos rosa, ideas ámbar, datos verde) y callouts. |
| Agente Ortiz (chat IA) | `AgenteColors` | `#6366F1` índigo | Chat con burbujas (usuario índigo, bot gris), artefactos y colores de estado (pensando, herramienta, éxito, error). |
| Editor enriquecido (compartido) | `RichEditorColors` | `accent` mutable | El acento lo fija cada app al abrir el editor (Notas índigo, Diario verde). Es estático porque las barras flotantes viven en el Overlay raíz. |

**Regla de identidad:** dentro de una mini-app se usa su clase de color; los elementos de la suite (launcher, sidebar de escritorio, command center) usan `AppColors` y el color de identidad de cada módulo solo para señalarlo (icono, tarjeta del launcher).

## 2. Tokens actuales

Hoy **solo los colores** están tokenizados. Tipografía, espaciados, radios y sombras son **literales** repartidos por las pantallas; abajo se documentan los valores más usados como "tokens de facto".

### 2.1 Colores de la suite — `AppColors` (`theme/colors.dart`)

| Token | Valor | Notas |
| --- | --- | --- |
| `primary` | `#1F6F5F` | **No es `const`**: lo cambia `AppColors.updateThemeColor()` según el color del libro/perfil activo (`quebrado/viewmodels/app_state.dart`). |
| `secondary` | `#2FA084` | Derivado de `primary` (+10 % luminosidad) al cambiar el tema. |
| `accent` | `#6FCF97` | Derivado de `primary` (+25 % luminosidad). No usar para texto (contraste 1.9:1). |
| `background` | `#EEEEEE` | Fondo de pantallas y diálogos (`dialogBg`). |
| `cardBackground` | `Colors.white` | |
| `cardText` / `cardSubtitleText` | `black87` / `black54` | |
| `cardBorderColor` / `cardBorderWidth` | `#E0E0E0` / `1.0` | |
| `mainTabActiveBg` / `mainTabActiveText` / `mainTabInactiveText` / `mainTabTrackBg` | `primary` / blanco / `black54` / negro 5 % | Pestañas principales (fuera de tarjetas). |
| `nestedTabActiveBg` / `nestedTabTrackBg` | `secondary` / negro 5 % | Pestañas dentro de tarjetas. |
| `income` | `#5F8575` | Semántico: ingreso. |
| `expense` | `#C84E4E` | Semántico: gasto. |
| `creationColors` | `#1F6F5F, #2FA084, #6FCF97, #5F8575, #3B6B7B, #7C8B64, #D4A373, #C84E4E` | Paleta para elegir color de bolsillos, suscripciones, libros. |

**Colores por moneda** (`quebrado/widgets/currency_pill.dart`, constantes de nivel superior): `usdCurrencyColor #16A34A` (verde), `bsCurrencyColor #D97706` (ámbar), `eurCurrencyColor #2563EB` (azul), con `currencyColor()` y `currencyShortLabel()` (`$`, `Bs`, `€`).

### 2.2 Colores por módulo

Todas siguen el mismo esqueleto (`primary`, `primaryLight`, `primaryDark`, `background`, `surface`/`cardSurface`, `cardBorder`, `textPrimary`, `textSecondary`, `textMuted`) con valores de la escala Slate de Tailwind:

| Clase | primary / light / dark | background | cardBorder | textPrimary / Secondary / Muted | Extras |
| --- | --- | --- | --- | --- | --- |
| `DiarioColors` | `#1F6F5F` / `#E8F3F0` / `#154C41` | `#F9FAFB` | `#E5E7EB` | `#111827` / `#4B5563` / `#9CA3AF` | `rose #DC2626` (+`roseLight`), `surfaceHover`, `primaryGlow`; alias amber/emerald/purple/blue/cyan = primary |
| `HabitosColors` | `#1F6F5F` / `#E8F3F0` / `#154C41` | `#F9FAFB` | `#E5E7EB` | `#111827` / `#4B5563` / `#9CA3AF` | `amber #D97706`, `rose #DC2626`, `primaryBorder` (20 %), alias heredados del tema terminal |
| `RemindersColors` | `#2E5B88` / `#EBF2F8` / `#1E3E5E` | `#F8FAFC` | `#E2E8F0` | `#0F172A` / `#475569` / `#94A3B8` | prioridad `urgent #DC2626`, `high #EA580C`, `medium #2563EB`, `low #64748B`; estado `overdue #E11D48`, `snoozed #D97706`, `completed #059669` |
| `NotasColors` | `#6366F1` / `#EEF2FF` / `#4F46E5` | `#F8FAFC` | `#E2E8F0` | `#0F172A` / `#64748B` / `#94A3B8` | categorías `acuerdosPink`, `ideasAmber`, `datosGreen` (+ light); callouts info/warn/pink (bg + border) |
| `AgenteColors` | `#6366F1` / `#EEF2FF` / `#4F46E5` | `#F8F9FD` | `#E2E8F0` | — | burbujas `userBubble`/`botBubble`, `artifact*`, estado `thinking #8B5CF6`, `toolExec #0EA5E9`, `success #10B981`, `error #EF4444` |
| `RichEditorColors` | `accent` (mutable, defecto `#6366F1`) | — | `border #E2E8F0` | `#0F172A` / `#64748B` / `#94A3B8` | `calloutBg/Border`, `icon #37352F` |

### 2.3 Tipografía

- Familia: **Josefin Sans** (tema global). Excepciones: `GoogleFonts.roboto*` en la exportación PDF de Notas (`notas/services/note_pdf_service.dart`) y `fontFamily: 'monospace'` en 3 sitios.
- AppBar: 18 / bold / `black87`, centrado.
- No hay escala tipográfica en código: `Theme.of(context).textTheme` se usa **1 vez**; hay ~1 840 `fontSize:` literales.
- Tamaños de facto (frecuencia): **12** (360), **13** (332), **11** (298), **10** (169), **14** (161), 16 (87), 15 (65), 18 (56), 9 (54), 20 (29) y medios puntos (10.5, 11.5, 12.5, 9.5).
- Escala de referencia para código nuevo (la de facto, redondeada): `caption 11` · `body-sm 12` · `body 13–14` · `title-sm 16` · `title 18` · `display 20+`. Evitar < 11 (hay ~300 usos de 9–10.5) y medios puntos.
- `HabitosStyles` (`title 16/w800`, `body 14/w500`, `caption 12`, `badge 11/w700`) es la única familia de estilos con nombre, pero **no se usa** (0 referencias).

### 2.4 Espaciado, radios, sombras, iconos (literales de facto)

| Tipo | Valores más usados (frecuencia) | Recomendado para código nuevo |
| --- | --- | --- |
| Separadores `SizedBox` | alto 16 (232), 12 (163), 8 (159), 4 (134), 6 (96); ancho 8 (209), 12 (88), 6 (93), 4 (83), 10 (83) | Escala 4 · 8 · 12 · 16 · 20 · 24 |
| Padding `EdgeInsets` | `all(12)` 51, `all(8)` 44, `all(16)` 44+22, `symmetric(vertical:14)` 43, `all(20)` 37, `all(14)` 33 | Tarjeta 16, contenido de sheet 20, chip `h6 v2` |
| Radio `BorderRadius.circular` | 12 (233), 10 (187), 8 (151), 16 (145), 14 (116), 20 (58), 6 (56), 24 (30) | Chip 6–8 · campo/botón 12 · tarjeta 16 · tarjeta clay 20 · sheet 24 |
| Sombras | 90 `BoxShadow`; `blurRadius` 4, 6, 8, 10; tarjeta clara: negro 4 %, `offset (0,4)`, `blur 12` | Usar la sombra de `ClaymorphicCard` clara o ninguna |
| Iconos | `size` 18 (82), 16 (78), 20 (52), 14 (45) | 16 en chips, 20 en listas, 24 en acciones |
| Opacidades | 613 `withOpacity(` (deprecado) vs 12 `withValues(alpha:)` | Código nuevo: `withValues(alpha: …)` |

## 3. Responsive

### 3.1 Clases de ventana — `widgets/responsive_breakpoints.dart`

| Constante | Valor | Helper | Condición |
| --- | --- | --- | --- |
| `compact` | 600 | `isCompact` | ancho < 600 |
| `medium` | 840 | `isMedium` | 600 ≤ ancho < **1200** (usa `compact` y `expanded`, no `medium`) |
| — | — | `isDesktop` | ancho ≥ **840** |
| `expanded` | 1200 | `isExpanded` | ancho ≥ 1200 |

⚠️ **`isMedium` e `isDesktop` se solapan entre 840 y 1199** (ambos `true`), y entre 600 y 839 la ventana es "medium" pero no "desktop", así que recibe el layout **móvil**. La decisión real de layout de toda la app es **`isDesktop` (≥ 840)**: por debajo, layout móvil; por encima, layout de escritorio. Código nuevo: decidir con `isDesktop` / `isExpanded`; no introducir lógica nueva basada en `isMedium` hasta que se corrija (pendiente).

### 3.2 Patrones de layout

- **Scaffold de la suite** (`widgets/responsive_suite_scaffold.dart`, `ResponsiveSuiteScaffold` + enum `SuiteModule`): en móvil devuelve el launcher (`screens/app_launcher_screen.dart`); en escritorio, **sidebar fijo** (210 px, 240 px en expanded) + separador de 1 px + módulo activo. El módulo inicial en escritorio es el **command center** (`widgets/desktop_command_center_view.dart`).
- **Sheets responsivos** (`widgets/responsive_sheet_helper.dart`, `showResponsiveSheet`): en móvil `showModalBottomSheet`; en escritorio **panel lateral derecho** (ancho por defecto 480, mínimo 380, máximo 90 % de la ventana), radio 24 a la izquierda, fondo `#F9FAFB`, con **Navigator anidado** para poder abrir subpantallas dentro del panel. Usar siempre este helper para sheets nuevos (hoy convive con 63 `showModalBottomSheet` directos).
- **Scroll horizontal en escritorio** (`ResponsiveHorizontalScroll`, mismo archivo): en escritorio añade botones ◀ ▶ a filas de chips/filtros que en móvil se desplazan con el dedo.
- **Dos columnas en escritorio**: Quebrado (dashboard + subnav), Hábitos (lista + métricas en vivo), Diario (contactos + detalle maestro-detalle). Patrón: columna izquierda de lista/navegación, derecha de detalle o métricas.

## 4. Inventario de componentes reutilizables

| Componente | Ruta | Cuándo usarlo |
| --- | --- | --- |
| `ResponsiveSuiteScaffold` | `widgets/responsive_suite_scaffold.dart` | Raíz de la app; añadir aquí un módulo nuevo de la suite. |
| `DesktopCommandCenterView` | `widgets/desktop_command_center_view.dart` | Vista resumen en escritorio. |
| `showResponsiveSheet` | `widgets/responsive_sheet_helper.dart` | Cualquier formulario o detalle en hoja (móvil) / panel (escritorio). |
| `ResponsiveHorizontalScroll` | `widgets/responsive_sheet_helper.dart` | Filas horizontales de chips o tarjetas. |
| `ResponsiveBreakpoints` | `widgets/responsive_breakpoints.dart` | Toda decisión responsive. |
| `ClaymorphicCard` | `quebrado/widgets/claymorphic_card.dart` | Tarjeta base de Quebrado (radio 20, padding 16). Con fondo de color aplica volumen 3D y texto blanco automáticamente (luminosidad < 0.75). 97 usos. |
| `ClaymorphicBackground` | `quebrado/widgets/claymorphic_background.dart` | Fondo `AppColors.background` a pantalla completa. |
| `SlideToConfirmButton` | `quebrado/widgets/slide_to_confirm_button.dart` | Confirmar operaciones de dinero (activable en ajustes con `useSlideToConfirm`). |
| `CurrencyPill` + `currencyColor` / `currencyShortLabel` | `quebrado/widgets/currency_pill.dart` | Etiqueta de moneda (`$`, `Bs`, `€`, o `$ → Bs` en cambios). |
| `AnimatedProgressBar` | `quebrado/widgets/animated_progress_bar.dart` | Progreso de metas (bolsillos). |
| `PocketCard` | `quebrado/widgets/pocket_card.dart` | Tarjeta de bolsillo de ahorro. |
| `TimelineEventRow` | `quebrado/widgets/timeline_event_row.dart` | Fila de evento en el timeline/proyección. |
| `ExchangeSuggestionRow` | `quebrado/widgets/exchange_suggestion_row.dart` | Sugerencia de cambio de divisa. |
| `DashboardChartsCard` | `quebrado/widgets/dashboard_charts_card.dart` | Gráficos `fl_chart` del dashboard. |
| Helpers de formato | `quebrado/widgets/helpers.dart` | `formatUSD`, `formatBs`, `formatCurrency`, `formatRate`, `formatDate`, `formatFullDate`, `parseHexColor`, `getIconData`, `CommaTextInputFormatter`. |
| Editor enriquecido | `rich_editor/` (`RichDocumentEditor`, `RichDocumentViewer`, `FormatToolbar`, `DraftBanner`…) | Texto largo con formato en Notas y Diario; fijar `RichEditorColors.accent` al abrir. |
| Ánimo | `diario/widgets/mood_*` | Check-in, selector de emoción, calendario mensual, gráfica de tendencia. |
| `MentionTextField` | `diario/widgets/mention_text_field.dart` | Menciones `@contacto`. |
| Vistas de agenda | `recordatorios/widgets/covey_matrix_view.dart`, `weekly_schedule_view.dart` | Matriz 2×2 Covey y agenda semanal. |

## 5. Patrones de UX

- **Hoja vs. diálogo:** formularios de creación/edición y detalles → `showResponsiveSheet`. Confirmaciones cortas y avisos → `AlertDialog` (33 usos). Lectores/editores grandes de escritorio → diálogo a pantalla grande (p. ej. `entry_reader_dialog`, `note_reader_dialog`). Hoy hay 95 `showDialog` y 63 `showModalBottomSheet` directos: código nuevo usa el helper.
- **Confirmaciones de dinero:** `SlideToConfirmButton` cuando el ajuste está activo; operaciones sensibles protegidas por PIN de 4 dígitos / biometría (`pin_verification_dialog`, `biometric_service`).
- **Borrado:** siempre con confirmación y en rojo (`DiarioColors.rose`, `HabitosColors.rose`, `AppColors.expense`). Solo hay 1 `Dismissible`; no hay "deshacer".
- **Feedback:** `SnackBar` vía `ScaffoldMessenger` (234 usos; 17 `floating`). No hay helper común: estilo, duración y color varían por pantalla.
- **Carga:** `CircularProgressIndicator` (32) y `LinearProgressIndicator` (9); sin skeletons. `RefreshIndicator` en 4 listas.
- **Vacío:** texto simple tipo "Sin registros este día.", "No hay categorías registradas". No existe un componente `EmptyState`.
- **Error:** se registra con `debugPrint` y, a veces, SnackBar con `'Error …: $e'` (expone el mensaje técnico al usuario). La app funciona sin Supabase (datos locales / semillas) y lo indica en logs, no en UI.
- **Onboarding:** tutoriales con `showcaseview` (15 usos).
- **Montos y monedas:** USD `"$1234.56"`, EUR `"€1234.56"`, VES `"Bs. 1234.56"` y tasas `"Bs. 36.50"` (`helpers.dart`). Siempre 2 decimales, **sin separador de miles** y con punto decimal; el input acepta coma y la convierte a punto (`CommaTextInputFormatter`). Hay 215 `toStringAsFixed` dispersos y 0 `NumberFormat`: usar los helpers, no formatear a mano.
- **Fechas:** `dd/MM/yyyy` y `dd/MM/yyyy HH:mm` (`formatDate`, `formatFullDate`).
- **Textos:** español, tuteo, frases cortas, sin tecnicismos ("Bolsillos", "Libros", "Abono parcial"). Los mensajes de error para el usuario no deben incluir `$e`.

## 6. Accesibilidad

**Lo que hay:** 103 `tooltip:` y 12 `Tooltip(` (principalmente en `IconButton`), `HapticFeedback` en 7 sitios, primarios con buen contraste sobre blanco (`AppColors.primary` 6.0:1, `RemindersColors.primary` 7.1:1, `textSecondary` 7.6:1).

**Lo que falta / riesgos medidos:**

- **0** `Semantics(` y **0** `semanticLabel`: lectores de pantalla dependen solo de tooltips y textos.
- **Escalado de texto:** no se prueba ni se limita (`textScaler` 0 usos); con tamaños fijos de 9–12 px y alturas fijas es probable el desbordamiento con texto grande.
- **Contraste (WCAG AA 4.5:1 texto normal):** `textMuted` `#9CA3AF`/`#94A3B8` ≈ 2.5:1 ❌; `Colors.grey` (`#9E9E9E`) 2.7:1 ❌ (614 usos de `Colors.grey`); `AppColors.accent` 1.9:1 ❌; `secondary` y blanco sobre `secondary` (pestañas anidadas activas) 3.2:1 ❌ texto normal; `income` 4.1:1 ❌; `NotasColors.primary` 4.47:1 (límite); colores de moneda USD 3.3:1 y Bs 3.2:1 ❌ como texto. Se aceptan solo para texto ≥ 18 px (o 14 bold) o elementos no textuales.
- **Tamaño táctil:** 23 `VisualDensity.compact`, 13 `BoxConstraints()` vacíos y 4 `shrinkWrap` reducen el objetivo por debajo de 48×48.
- Sin tema oscuro ni modo de alto contraste.

## 7. Deuda de diseño medida

| Deuda | Medida aprox. (`grep` en `lib/`) |
| --- | --- |
| `Color(0x…)` literales | 547 en total, **~454 fuera de los archivos de tema** |
| `Colors.*` de Material directos | ~1 856 (`grey` 614, `white` 600, `black` 277, `transparent` 196, `orange` 42, `red` 33…) |
| `fontSize:` literales | ~1 840 (escala tipográfica inexistente) |
| `EdgeInsets.*` literales | ~1 315 |
| `BorderRadius.circular` literales | > 1 000 con 10+ valores distintos |
| `withOpacity` deprecado | 613 |
| Sheets/diálogos sin helper responsivo | 63 `showModalBottomSheet` + 95 `showDialog` |

**Inconsistencias entre módulos**

1. **Primario dinámico a medias:** `AppColors.primary` cambia con el color del libro, pero `DiarioColors`, `HabitosColors`, el sidebar de escritorio (`responsive_suite_scaffold.dart`, `#1F6F5F` literal en 6+ sitios) y el launcher tienen `#1F6F5F` fijo → al cambiar de libro la suite queda con dos verdes distintos.
2. **Tres grises de fondo:** `#EEEEEE` (`AppColors`), `#F9FAFB` (Diario, Hábitos, panel lateral), `#F8FAFC` (Recordatorios, Notas) y `#F8F9FD` (Agente); y dos grises de borde (`#E0E0E0` vs `#E5E7EB`/`#E2E8F0`).
3. **Dos rojos de borrado/error:** `#C84E4E` (Quebrado), `#DC2626` (Diario/Hábitos/Recordatorios), `#EF4444` (Agente, launcher), `#E11D48` (vencido).
4. **Verdes de "positivo" distintos:** `income #5F8575`, `usdCurrencyColor #16A34A`, `success/datosGreen #10B981`, `completed #059669`.
5. **Notas y Agente comparten índigo** `#6366F1` y no se distinguen en el launcher salvo por icono.
6. Nombres heredados del tema "terminal" de Hábitos que ya no describen el estilo (`HabitosStyles.mono/prompt`, `textGreen`, archivo `habitos_terminal_theme.dart`); `HabitosStyles` sin uso.
7. **Shims de re-exportación** (no son duplicados reales, pero confunden): `quebrado/theme/colors.dart` → `theme/colors.dart`; `quebrado/services/{notification_manager,supabase_service,supabase_config}.dart` → `services/…`; `viewmodels/app_state.dart` → `quebrado/viewmodels/app_state.dart`. Importar siempre la ruta real.
8. README describe Quebrado como "claymórfico", pero con `cardBackground` blanco la mayoría de tarjetas son planas; el volumen solo aparece en tarjetas de color.

## 8. Reglas a partir de ahora

1. **Código nuevo usa tokens existentes:** colores de la clase del módulo (o `AppColors` en piezas de suite); nada de `Color(0x…)` ni `Colors.grey/orange/red…` en pantallas. `Colors.white`, `Colors.transparent` y `Colors.black` con opacidad se toleran en sombras/overlays.
2. Tamaños, espaciados y radios: usar los valores recomendados de la §2.3–2.4 (escala 4/8/12/16/20/24; radios 8/12/16/20/24; fuentes ≥ 11 sin medios puntos).
3. **Si falta un token**, el `ui-ux-designer` lo propone primero en este documento y lo crea en `lib/theme/` (con test si tiene lógica). `flutter-dev` no inventa tokens.
4. Sheets con `showResponsiveSheet`; decisiones de layout con `ResponsiveBreakpoints.isDesktop` / `isExpanded`; toda pantalla nueva se diseña para compact (< 600), móvil ancho/tablet (600–839, hoy layout móvil) y escritorio (≥ 840).
5. Montos con los helpers de `helpers.dart`; fechas con `formatDate` / `formatFullDate`.
6. Accesibilidad mínima en lo nuevo: `tooltip` o `Semantics` en todo botón solo-icono, objetivo táctil ≥ 48×48, contraste ≥ 4.5:1 en texto normal, sin alturas fijas que corten texto escalado.
7. Mensajes al usuario en español, tuteo, sin `$e` ni jerga técnica; estados vacío, carga y error definidos en el diseño de cada vista.
8. **No migrar pantallas existentes "de paso".** La deuda de la §7 se apunta en `docs/pendientes.md` y se paga en cambios dedicados.

### Checklist de revisión visual (`ui-ux-designer`)

| Severidad | Qué se marca |
| --- | --- |
| **Bloqueante** | Pantalla rota o desbordada en alguna clase de ventana; texto ilegible (contraste < 3:1 en texto normal); acción destructiva sin confirmación; flujo de dinero sin confirmación; color de identidad equivocado (otro módulo); estado de error o vacío inexistente que deja la pantalla en blanco. |
| **Importante** | Color/tamaño/espaciado literal nuevo en lugar de token; sheet sin `showResponsiveSheet`; botón solo-icono sin tooltip/Semantics; objetivo táctil < 48; contraste < 4.5:1 en texto normal; monto formateado a mano; mensaje con `$e`; falta estado de carga; inconsistencia con el patrón del módulo. |
| **Menor** | Valor fuera de la escala recomendada (p. ej. padding 14, fuente 12.5); sombras/radios distintos a los vecinos; textos mejorables (tono, longitud); orden de elementos. |

Ante la duda, se sube la severidad.
