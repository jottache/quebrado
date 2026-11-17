# 05 — Nuevo estilo en cada app

- **Estado:** Borrador <!-- Borrador | En revisión | Aprobado | Implementado | Obsoleto -->
- **Depende de:** 01 y 02
- **Fecha:** 2026-11-17
- **Módulo(s):** agente, diario, recordatorios, habitos, notas, quebrado, rich_editor y suite
- **Objetivo (una frase):** Llevar cada app al design system v2 (oscuro, sin tarjetas, con tokens y animaciones) y retirar el launcher y el command center anteriores.

> Decisiones C1, C2, C4 y C10. Maqueta: https://claude.ai/artifact/TR22XAWd9anJ6xYLXCVn48

## Alcance
**Entra:**
- **Componentes compartidos nuevos** (`lib/widgets/ortiz/`):
  - `OrtizSection`: agrupa contenido con un título, espacio y líneas finas, sin tarjeta.
  - `OrtizListRow`: fila con el punto o icono de la app, el texto y una acción.
  - `OrtizPill`: estado o moneda.
  - `OrtizAmount`: monto en JetBrains Mono, con animación de conteo opcional.
  - `showOrtizNotice`: aviso con acción opcional. Reemplaza los SnackBars sueltos de las pantallas que se toquen (avanza P-24).
- **Una app por PR, en este orden:** Ortiz (chat) → Diario (+ Ánimo) → Recordatorios → Hábitos → Notas (+ editor enriquecido) → Quebrado.
- **En cada app:**
  - Quitar las tarjetas: `ClaymorphicCard` y `Card` blancas pasan a `OrtizSection`.
  - Cambiar los colores, tamaños, espaciados y radios literales por tokens.
  - Cambiar `withOpacity` por `withValues` en los archivos tocados.
  - Agregar entradas escalonadas con `flutter_animate` y `OrtizMotion`.
- **Quebrado** (la más grande, con ~97 usos de `ClaymorphicCard`): los montos siguen siendo los protagonistas, ahora con `OrtizAmount`. La confirmación deslizante se mantiene.
- **Cierre:** borrar `AppLauncherScreen`, `LauncherActionHubView`, `DesktopCommandCenterView` y el interruptor de transición de la spec 02, y regenerar `all_imports_test`.

**Fuera:**
- Cambios de funcionalidad dentro de las apps.
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
- **CA-02** Dada cada app terminada, cuando se buscan `Color(0x` y `fontSize:` literales en los archivos tocados, entonces no hay ninguno nuevo y los que había se cambiaron por tokens.
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

**Descartadas (y por qué):**
- Rehacer todo en una sola PR: sería imposible de revisar.

## Riesgos
- **R-01** Es la spec más larga. Para que no se eternice: cada app es su propia PR, y se puede pausar entre apps.
- **R-02** En Quebrado, la estética «claymórfica» le da personalidad a los montos y los bolsillos. Al quitar las tarjetas se puede perder jerarquía. Mitigación: `OrtizAmount` y el color de la app.

## Preguntas abiertas
- **PA-01** ¿Se mantiene la confirmación deslizante en Quebrado, como en la maqueta? Recomendación: sí.
- **PA-02** Los bolsillos (`PocketCard`) tienen color propio elegido por la persona. ¿Ese color se mantiene como acento de cada bolsillo? Recomendación: sí, como punto y barra de progreso, no como fondo.

## Qué NO entra
- Funcionalidad nueva.
- La migración de los 63 `showModalBottomSheet` y 95 `showDialog` que no pasan por `showResponsiveSheet`, salvo los que se toquen.

## Pasos manuales
- Revisión visual de la persona al terminar cada app.
