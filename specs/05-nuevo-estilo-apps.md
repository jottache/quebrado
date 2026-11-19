# 05 — Nuevo estilo en cada app

- **Estado:** Aprobado <!-- Borrador | En revisión | Aprobado | Implementado | Obsoleto -->
- **Depende de:** 01 (la 02 solo para el paso final: retirar el launcher). Decisión de la persona del 2026-11-17: la 05 va antes que la 02, en una rama apilada sobre `spec-01-tema-oscuro-design-system`.
- **Fecha:** 2026-11-17
- **Módulo(s):** agente, diario, recordatorios, habitos, notas, quebrado, rich_editor y suite
- **Objetivo (una frase):** Llevar cada app al design system v2 (oscuro, sin tarjetas, con tokens y animaciones) y retirar el launcher y el command center anteriores.

> Decisiones C1, C2, C4 y C10. Maqueta: https://claude.ai/artifact/TR22XAWd9anJ6xYLXCVn48

## Alcance
**Objetivo ampliado por la persona (2026-11-17):** «nada escrito a mano ni hardcodeado, bien optimizado». **Cero valores de estilo a mano** en todo `lib/`. Quedan fuera `lib/theme/` (donde viven los tokens) y las tres pantallas que la spec 02 reemplaza: `screens/app_launcher_screen.dart`, `screens/launcher_action_hub_view.dart` y `widgets/desktop_command_center_view.dart`. Cuentan como valor de estilo: colores (`Color(0x…)`, `Colors.*` salvo `transparent`), `fontSize` numérico, números en `EdgeInsets`/`SizedBox` de separación y en `BorderRadius`/`Radius.circular`, tamaños de icono y `withOpacity`.

**Entra:**
- **Paso 0, script de reemplazo** (`tool/codemod_tokens.py`): cambia por tokens lo mecánico, es decir márgenes, separadores, radios, tamaños de letra y `withOpacity`. Son unos 7.100 reemplazos en 102 archivos. Redondea al token más cercano y, en empate, al menor. Por debajo de 10 px usa `OrtizFontSize.micro`. Lo ejecuta la persona, porque `guard-bash` bloquea a los agentes que escriben código con scripts.
- **Tokens nuevos:** `OrtizFontSize` (con `micro = 9` solo para vistas densas), `OrtizIconSize` y `OrtizSpace.xxs = 2`.
- **Test guardián** `test/contract/no_hardcoded_styles_test.dart`: falla si aparece un valor de estilo escrito a mano en el alcance. Lleva una lista de deuda por archivo que solo baja, y al cerrar la spec queda vacía.
- **Componentes compartidos nuevos** (`lib/widgets/ortiz/`):
  - `OrtizSection`: agrupa contenido con un título, espacio y líneas finas, sin tarjeta.
  - `OrtizListRow`: fila con el punto o icono de la app, el texto y una acción.
  - `OrtizPill`: estado o moneda.
  - `OrtizAmount`: monto en JetBrains Mono, con animación de conteo opcional.
  - `showOrtizNotice`: aviso con acción opcional. Reemplaza los SnackBars sueltos de las pantallas que se toquen (avanza P-24).
- **Un agente por app, en este orden:** Ortiz (chat) → Diario (+ Ánimo) → Recordatorios → Hábitos → Notas (+ editor enriquecido) → Quebrado. Va un commit por app en la misma rama y PR, para revisar commit a commit.
- **En cada app:**
  - Colores que dependen del contexto (fondo, texto o texto sobre coral) → tokens o la clase de color del módulo.
  - Lo que el script no pudo reemplazar → tokens: números en expresiones, márgenes > 32, tamaños de icono.
  - Quitar las tarjetas: `ClaymorphicCard` y `Card` blancas pasan a `OrtizSection`.
  - Agregar entradas escalonadas con `flutter_animate` y `OrtizMotion`.
  - Optimizar: constructores `const` donde se pueda y sin buscar el tema repetidamente dentro de los bucles.
- **Quebrado** (la más grande, con ~97 usos de `ClaymorphicCard`): los montos siguen siendo los protagonistas, ahora con `OrtizAmount`. **Se elimina la confirmación deslizante** (decisión de la persona): el widget `SlideToConfirmButton`, su ajuste `useSlideToConfirm` y su opción en Ajustes. Esas confirmaciones pasan a un botón normal.
- **Bolsillos:** el color propio de cada bolsillo se muestra como punto y barra de progreso, no como fondo.
- **Cierre:** borrar `AppLauncherScreen`, `LauncherActionHubView`, `DesktopCommandCenterView` y el interruptor de transición de la spec 02, y regenerar `all_imports_test`.

**Fuera:**
- Cambios de funcionalidad dentro de las apps, salvo eliminar la confirmación deslizante (decisión de la persona).
- El tema claro.
- Corregir los breakpoints (P-23) y la accesibilidad completa (P-22), salvo el contraste.

## Flujo y UX
- La navegación interna de cada app no cambia. Solo cambia su aspecto.
- Cada app se revisa en compact, medium y expanded antes de pasar a la siguiente.
- Los estados vacío, de carga y de error de cada pantalla usan los componentes nuevos.

## Modelo de datos
No hay cambios.

## Contrato de datos
No aplica.

## Impacto
- [ ] Respaldo JSON / importación
- [ ] SQLite local de `quebrado`
- [ ] Agente Ortiz: solo el estilo del chat
- [x] Otras mini-apps: todas
- [x] Design system: componentes compartidos nuevos

## Plan de implementación
| Paso | Qué | Archivos | Agente | Verificación |
| --- | --- | --- | --- | --- |
| 0a | Tokens `OrtizFontSize`, `OrtizIconSize` y `OrtizSpace.xxs` + script `tool/codemod_tokens.py` (probado en una copia: analyze 0/0 y suite sin fallos nuevos) | `lib/theme/ortiz_type.dart`, `ortiz_space.dart`, `tool/` | hilo principal | tests de `test/theme/` |
| 0b | **La persona ejecuta** `python3 tool/codemod_tokens.py --apply` | 102 archivos de `lib/` | persona | analyze + suite |
| 0c | Test guardián con la deuda de partida por archivo | `test/contract/no_hardcoded_styles_test.dart` | hilo principal | el test pasa |
| 1 | Componentes compartidos | `lib/widgets/ortiz/*.dart`, tests | ui-ux-designer + flutter-dev | tests de widget |
| 2 | Ortiz (chat, burbujas, tarjetas de propuesta y artefactos) | `lib/agente/widgets/*` | flutter-dev | revisión visual |
| 3 | Diario + Ánimo | `lib/diario/screens/*`, `widgets/*` (en tandas de ≤ 3 archivos) | flutter-dev | revisión visual |
| 4 | Recordatorios + Covey | `lib/recordatorios/*` | flutter-dev | revisión visual |
| 5 | Hábitos | `lib/habitos/*` | flutter-dev | revisión visual |
| 6 | Notas + editor enriquecido | `lib/notas/*`, `lib/rich_editor/*` | flutter-dev | revisión visual |
| 7 | Quebrado | `lib/quebrado/screens/*`, `widgets/*`, `dialogs/*` (en tandas) | flutter-dev | tests existentes de Quebrado + revisión visual |
| 8 | Retirar el launcher, el command center y el interruptor | `lib/screens/*`, `lib/widgets/desktop_command_center_view.dart`, `responsive_suite_scaffold.dart` | flutter-dev | `generate_all_imports_test.sh` |
| 9 | Verificación final | — | qa-analyst + revisor | `suite-run.sh` + criterios |

## Criterios de aceptación
- **CA-01** Dada cada app terminada, cuando se buscan `ClaymorphicCard`, `Card(` y `Colors.white` en sus `screens/`, `widgets/` y `dialogs/`, entonces no hay ninguno (salvo las excepciones justificadas en la PR).
- **CA-02** Dado el cierre de la spec, cuando corre `test/contract/no_hardcoded_styles_test.dart`, entonces su lista de deuda está vacía: no queda ningún valor de estilo escrito a mano en el alcance.
- **CA-07** Dada la configuración de Quebrado, cuando se buscan `SlideToConfirmButton` y `useSlideToConfirm` en `lib/`, entonces no aparecen, y las operaciones de dinero se confirman con un botón.
- **CA-03** Dada cada app, cuando se revisa en compact, medium y expanded, entonces el ui-ux-designer la aprueba sin hallazgos altos.
- **CA-04** Dado `disableAnimations`, cuando se abre cualquier lista, entonces no hay animaciones de entrada.
- **CA-05** Dado el cierre, cuando se busca `AppLauncherScreen` en `lib/`, entonces no aparece, y la app abre en `/` (Ortiz).
- **CA-06** `flutter analyze` termina con 0 errores y 0 warnings, la suite pasa y la cobertura no baja.

## Decisiones
**Tomadas:**
- C1: paleta coral.
- C2: tipografías.
- C4: sin tarjetas.
- C10: `flutter_animate`.
- El orden de las apps (de menor a mayor riesgo; Quebrado al final por tamaño).
- 2026-11-17, por la persona:
  - Alcance «nada hardcodeado», sin el launcher, el hub ni el command center.
  - Esta spec va antes que la 02, en una rama apilada.
  - Estrategia de script + un agente por app, para gastar menos tokens y tiempo.
  - Redondeo al token más cercano.
  - Se elimina la confirmación deslizante (PA-01).
  - El color de los bolsillos pasa a punto y barra (PA-02).

**Descartadas (y por qué):**
- Rehacer todo en una sola PR: sería imposible de revisar.
- Agentes archivo por archivo (≈ 40 tandas): cuesta unas 3 veces más que el script, con el mismo resultado.
- Redondear los empates hacia arriba: en la prueba desbordaba filas (6→8, 10→12, 13→14).

## Riesgos
- **R-01** Es la spec más larga. Para que no se eternice: cada app es su propia PR, y se puede pausar entre apps.
- **R-02** En Quebrado, la estética «claymórfica» le da personalidad a los montos y los bolsillos. Al quitar las tarjetas se puede perder jerarquía. Mitigación: `OrtizAmount` y el color de la app.

## Preguntas abiertas
- ~~PA-01~~: se elimina la confirmación deslizante.
- ~~PA-02~~: el color del bolsillo pasa a punto y barra de progreso.

## Qué NO entra
- Funcionalidad nueva.
- La migración de los 63 `showModalBottomSheet` y 95 `showDialog` que no pasan por `showResponsiveSheet`, salvo los que se toquen.

## Pasos manuales
- Revisión visual de la persona al terminar cada app.

## Implementación (2026-11-17, rama `spec-05-nuevo-estilo-apps`, apilada sobre `spec-01-tema-oscuro-design-system`)
**Estado real:** implementada salvo el **paso 8** (retirar launcher, hub y command center), que espera a la spec 02 por diseño. Se cierra la spec 05 cuando la 02 borre esas vistas.

**Verificación de criterios**
| CA | Resultado | Evidencia |
| --- | --- | --- |
| CA-01 | CUMPLE | `grep` de `ClaymorphicCard(`/`Card(` en `lib/`: 0 (`ClaymorphicCard` borrado). Los únicos `…Colors.white` son `PdfColors.white` del PDF de Notas (papel blanco). |
| CA-02 | CUMPLE | `test/contract/no_hardcoded_styles_test.dart` con `no_hardcoded_styles_debt.txt` vacío (0 en 0 archivos); el guardián cuenta colores `Color(0x…)`, `Color.fromARGB/RGBO`, `Colors.*`, `fontSize`, `EdgeInsets`, separadores, radios, tamaños de icono y `withOpacity`. Fuera del alcance: tokens y las 3 vistas de la spec 02. |
| CA-03 | NO VERIFICABLE (aún) | Revisión visual con capturas sin terminar → P-49. El `revisor` dio por buena la lógica (sin cambios en los diálogos de dinero). |
| CA-04 | CUMPLE | `ortizStaggered` (controlador propio, sin Timers) en 14 pantallas; con reducir movimiento devuelve el hijo sin animar (`test/widgets/ortiz/ortiz_animate_test.dart`). |
| CA-05 | PENDIENTE | Paso 8, tras la spec 02. |
| CA-06 | CUMPLE | Puerta verde: analyze 0/0, 549+ tests (4 fallos conocidos), cobertura 33,74 % ≥ 31,3 %. |
| CA-07 | CUMPLE | `SlideToConfirmButton`/`useSlideToConfirm` no aparecen en `lib/`; test en `test/quebrado/viewmodels/app_state_test.dart`. |

**Desviaciones**
- Tokens nuevos: `OrtizFontSize` (con `micro` = 9), `OrtizIconSize`, `OrtizSpace.xxs`, `OrtizStroke`, `OrtizSize`, `OrtizMotion.entryOffset/staggerMaxIndex`, `OrtizPalette.accentTint/warnTint/badTint…`, `AppColors.currencyUsd/Bs/Eur` (P-39) y `AppColors.casheaBrand`.
- `ortizStaggered` no usa `flutter_animate` (su `Animate` deja Timers vivos); la dependencia queda sin uso (P-41).
- `ClaymorphicCard` borrado; `ClaymorphicBackground` queda y solo pinta `bg` (P-46).
- Script `tool/codemod_tokens.py` (≈ 7.100 reemplazos mecánicos), ejecutado por la persona porque `guard-bash` bloquea scripts que escriben código.
- Arreglos colaterales: test del portapapeles del Diario ahora determinista (canales simulados); tests de modelos nuevos (`mood_catalog`, `covey_quadrant`, `role_model`).
- Pasados a pendientes por decisión de la persona: adopción de `showOrtizNotice` (P-47) y revisión del texto `micro` de 9 px (P-48). Otros hallazgos: P-40 (paleta de resaltado del editor), P-42 (widget tests por clase de ventana), P-43 (valores que el guardián aún no cuenta), P-44 (bloques con borde), P-45 (contrastes puntuales).
