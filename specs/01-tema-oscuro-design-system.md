# 01 — Tema oscuro y design system v2

- **Estado:** Aprobado <!-- Borrador | En revisión | Aprobado | Implementado | Obsoleto -->
- **Depende de:** ninguna
- **Fecha:** 2026-11-17
- **Módulo(s):** suite (`lib/theme/`, `main.dart`) y las clases de color de todos los módulos
- **Objetivo (una frase):** Dar a OrtizApp (solo web) un tema oscuro ciruela y coral con tokens centralizados de color, tipografía, espaciado, radio y movimiento, con un color por app definido en una sola variable, sin rehacer todavía cada pantalla.

> Parte del rediseño «Ortiz al centro» (specs 01 → 05). Maqueta y decisiones C1–C20: https://claude.ai/artifact/TR22XAWd9anJ6xYLXCVn48

## Alcance
**Entra:**
- `lib/theme/ortiz_tokens.dart`: `ThemeExtension<OrtizTokens>` con `bg`, `surface`, `surfaceHigh`, `line`, `fg`, `muted`, `faint`, `accent`, `onAccent`, `ok`, `warn`, `bad`, `income`, `expense`.
- `lib/theme/suite_apps.dart`: `enum SuiteApp` (finanzas, diario, habitos, recordatorios, notas) con `label`, `route`, `icon` y **un solo** `color`. Los demás tonos se derivan (`tint`, `border`, `strong`).
- `lib/theme/ortiz_type.dart`: escala tipográfica con nombre (`caption 11`, `bodySm 12`, `body 14`, `titleSm 16`, `title 18`, `display 24`, `displayLg 32`). Títulos en Bricolage Grotesque, texto en Manrope y montos en JetBrains Mono con cifras tabulares.
- `lib/theme/ortiz_motion.dart`: duraciones (`fast 180`, `base 320`, `slow 450` ms), curva `Cubic(.2,.8,.2,1)`, `stagger 60` ms y un helper que devuelve `Duration.zero` si `MediaQuery.disableAnimationsOf(context)`.
- Fuentes empaquetadas como assets (sin descarga en tiempo de ejecución).
- `ThemeData` oscuro (Material 3) en `main.dart`. Campos, hojas, diálogos, snackbars y divisores se toman de los tokens, y las tarjetas no tienen elevación.
- Dependencia `flutter_animate`. Se agrega aquí y se usa desde la spec 02.
- `AppColors` (`lib/theme/colors.dart`) y las clases de color de cada módulo (`DiarioColors`, `HabitosColors`, `RemindersColors`, `NotasColors`, `AgenteColors`, `RichEditorColors`) pasan a **leer** los tokens y `SuiteApp`; dejan de definir hex propios.
- `docs/design-system.md` v2 y una skill del proyecto `.claude/skills/ortiz-dark-ui/` con las reglas (tokens, «sin tarjetas», movimiento) para que todos los agentes las apliquen.

**Fuera:**
- Rehacer cada pantalla (quitar tarjetas, cambiar literales): spec 05.
- La pantalla de inicio, la navegación y la cara de Ortiz: spec 02.
- El tema claro (C9: solo oscuro por ahora; los tokens quedan listos para agregarlo después).

## Flujo y UX
- Al abrir la app en el navegador, todo el fondo y los componentes de Material se ven oscuros. Las pantallas con colores literales (por ejemplo, `Colors.white` escrito en el código) siguen claras hasta la spec 05. Esto es esperado y lo cubre el riesgo R-01.
- Paleta (C1, opción C):

| Token | Valor | Uso |
| --- | --- | --- |
| `bg` | `#110E12` | fondo |
| `surface` | `#1A161B` | menú, hojas, campo del chat |
| `surfaceHigh` | `#241E25` | burbuja del usuario, elemento activo |
| `line` | `#352B37` | separadores |
| `fg` / `muted` / `faint` | `#F1E9EE` / `#9C8F98` / `#655A62` | texto |
| `accent` / `onAccent` | `#FF8466` / `#1E0D08` | acción principal y Ortiz |
| `ok` / `warn` / `bad` | `#7CC9A6` / `#E9B65C` / `#EF7B6E` | estados; `income` = `ok`, `expense` = `bad` (ver PA-02) |

- Colores de app (valores de la maqueta, ver PA-03): finanzas `#E7C06A`, diario `#EE8FA6`, hábitos `#6FC3DF`, recordatorios `#A99BFF`, notas `#E9D8A6`.
- Las clases de ventana no cambian en esta spec.

## Modelo de datos
No hay cambios de datos.

## Contrato de datos
No aplica.

## Impacto
- [ ] Respaldo JSON / importación
- [ ] SQLite local de `quebrado`
- [ ] Agente Ortiz
- [x] Otras mini-apps: todas las clases de color cambian de valor
- [x] Design system: tokens nuevos, escala tipográfica y movimiento; `docs/design-system.md` v2

## Plan de implementación
| Paso | Qué | Archivos | Agente | Verificación |
| --- | --- | --- | --- | --- |
| 1 | Tokens de color y `SuiteApp` | `lib/theme/ortiz_tokens.dart`, `lib/theme/suite_apps.dart`, `test/theme/…` | ui-ux-designer | tests de contraste y de derivación |
| 2 | Tipografía, movimiento y fuentes como assets | `lib/theme/ortiz_type.dart`, `lib/theme/ortiz_motion.dart`, `pubspec.yaml` | ui-ux-designer | `flutter analyze` + test del helper de movimiento |
| 3 | `ThemeData` oscuro + `flutter_animate` | `lib/main.dart`, `pubspec.yaml` | flutter-dev | build web local |
| 4 | `AppColors` lee los tokens (decisión PA-01 sobre el color del libro) | `lib/theme/colors.dart`, `lib/quebrado/theme/colors.dart` | flutter-dev | tests existentes de Quebrado |
| 5 | Clases de color de Diario, Hábitos y Recordatorios leen `SuiteApp` y los tokens | `diario_colors.dart`, `habitos_terminal_theme.dart`, `reminders_colors.dart` | flutter-dev | `flutter analyze` |
| 6 | Clases de color de Notas, Agente y el editor | `notas_colors.dart`, `agente_colors.dart`, `rich_editor/rich_editor_colors.dart` | flutter-dev | `flutter analyze` |
| 7 | `design-system.md` v2 + skill `ortiz-dark-ui` | `docs/design-system.md`, `.claude/skills/ortiz-dark-ui/SKILL.md` | ui-ux-designer | lectura de la persona |
| 8 | Revisión de código y visual | — | revisor + ui-ux-designer | `.claude/hooks/suite-run.sh` |

## Criterios de aceptación
- **CA-01** Dada la app abierta en el navegador, cuando carga cualquier módulo, entonces el `ThemeData` es oscuro (`Brightness.dark`) y el `scaffoldBackgroundColor` es `OrtizTokens.bg`.
- **CA-02** Dado que se cambia solo el `color` de `SuiteApp.diario`, cuando se recompila, entonces cambian el primario de `DiarioColors`, su tinte y su borde, sin editar ningún otro archivo (test unitario sobre la derivación).
- **CA-03** Dadas las clases de color de los seis módulos, cuando se inspeccionan, entonces ninguna define un hex propio para su primario: todas lo leen de `SuiteApp` o de `OrtizTokens`.
- **CA-04** Dados los pares de texto `fg`/`muted` sobre `bg`/`surface`/`surfaceHigh`, cuando se calcula el contraste, entonces es ≥ 4,5:1 (test unitario). `faint` solo se usa en texto decorativo, nunca en texto que haya que leer.
- **CA-05** Dada la app web sin conexión a Google Fonts, cuando carga, entonces las tres familias se ven igual porque vienen de los assets.
- **CA-06** Dado `MediaQuery.disableAnimations = true`, cuando se piden las duraciones de `OrtizMotion`, entonces son cero.
- **CA-07** `flutter analyze` termina con 0 errores y 0 warnings, la suite pasa y la cobertura no baja.

## Decisiones
**Tomadas:**
- C1 paleta ciruela y coral.
- C2 tipografías Bricolage, Manrope y JetBrains Mono.
- C4 sin tarjetas.
- C9 solo tema oscuro.
- C10 `flutter_animate`.
- Un color por app en una sola variable.
- La app es solo web.
- PA-01 (resuelta el 2026-11-17): el color del libro solo marca el selector de libro y su indicador; el acento de la suite sigue siendo coral.
- PA-02 (resuelta el 2026-11-17): ingreso `#7CC9A6` y gasto `#EF7B6E`.
- PA-03 (resuelta el 2026-11-17): colores de app de la maqueta (finanzas `#E7C06A`, diario `#EE8FA6`, hábitos `#6FC3DF`, recordatorios `#A99BFF`, notas `#E9D8A6`).

**Descartadas (y por qué):**
- Mantener Josefin Sans: la persona eligió Bricolage.
- Hacer ahora el tema claro: duplica el trabajo de cada pantalla.

## Riesgos
- **R-01** Mientras no termine la spec 05, las pantallas con literales claros (`Colors.white`, `Color(0xFF…)`) se ven inconsistentes sobre el fondo oscuro. Mitigación: no desplegar en Vercel hasta tener al menos la spec 02 y el primer bloque de la 05, o aceptar la transición (PA-04).
- **R-02** Que `CardTheme` no tenga elevación cambia el aspecto de los ~97 `ClaymorphicCard`, que tienen sombra propia. Se revisa visualmente en el paso 8.

## Preguntas abiertas
- ~~PA-01~~, ~~PA-02~~, ~~PA-03~~: resueltas (ver Decisiones).
- **PA-04** ¿Se despliega en Vercel cada spec apenas termina, aceptando la transición, o se espera a que las specs 01, 02 y 05 estén listas?

## Qué NO entra
- Corregir el solape de `isMedium` e `isDesktop` (P-23).
- Accesibilidad completa (P-22). Aquí solo se garantiza el contraste de los tokens.

## Pasos manuales
- Ninguno en Supabase.
- La persona aprueba la skill `ortiz-dark-ui` antes de que la usen las specs 02–05.
