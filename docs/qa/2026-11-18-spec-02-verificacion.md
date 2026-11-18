# QA — Verificación de la spec 02 «Ortiz al centro» (2026-11-18)

- **Spec:** `specs/02-ortiz-al-centro.md` (sección «Criterios de aceptación», CA-01…CA-13).
- **Rama:** `spec-02-ortiz-al-centro` (cambios sin commitear). App en `quebrado-app-flutter/`.
- **Método:** lectura de tests y código. No se volvió a correr la suite. La puerta completa la reportó en verde el hilo principal: analyze 0/0, 797 tests, 2 fallos conocidos y `all_imports_test` regenerado con 233 archivos.
- **Decisiones que cambian la letra de los CA:**
  - PA-02: `Ctrl/⌘+K` abre la paleta.
  - PA-05: el launcher se borró sin interruptor.
  - P-04 revisada: el PIN se pide una vez al día al entrar a la app.
  - Q1 (`docs/design/ortiz-home.md:497`): el panel «Hoy» aparece desde 1200.

Las rutas de test son relativas a `quebrado-app-flutter/test/`.

## Tabla de verificación

| CA | Veredicto | Evidencia |
| --- | --- | --- |
| CA-01 | CUMPLE | `screens/ortiz_home_screen_test.dart::CA-01: en compact se ven ☰, el saludo según la hora, los chips y el campo` (l. 108). `ortizGreeting` (l. 48) y `el saludo sigue al reloj inyectado` (l. 140). `widgets/suite_router_test.dart::en compact muestra los chips del catálogo` (l. 741) y `en compact el ☰ de la barra abre el menú del shell` (l. 760). Launcher: `grep AppLauncherScreen\|LauncherActionHub\|DesktopCommandCenter\|SuiteModule` en `lib/` y `test/` da 0 resultados. En `lib/screens/` solo queda `ortiz_home_screen.dart`, y `/` se resuelve como `SuiteOrtizHome` (`lib/widgets/suite_router.dart:150`). |
| CA-02 (Q1) | CUMPLE | `responsive_suite_test.dart::en desktop/expanded (≥ 840) se ve SuiteRail con las ramas y el pie` (l. 212) y `el riel mide 240 en expanded y 210 entre 840 y 1199` (l. 225). `screens/ortiz_home_screen_test.dart::entre 840 y 1199 no hay ☰ ni panel` (l. 145) y `desde 1200 aparece el panel «Hoy» con su ancho y su fecha` (l. 157; también comprueba que el chat no pasa de `chatMaxWidth`). |
| CA-03 | CUMPLE | `widgets/suite_drawer_test.dart::CA-03 (compact/expanded): tocar Finanzas la despliega y pliega la otra abierta` (l. 37). `widgets/suite_rail_test.dart::CA-03 (…): clic en Finanzas despliega y pliega…` (l. 46). |
| CA-04 | NO VERIFICABLE (sin test de extremo a extremo; hallazgo H-01) | Está cubierto por piezas, pero ningún test une chip → `AddTransactionBottomSheet` → guardar → aviso con el router montado. El formulario devuelve el movimiento con `navigator.pop(newTx)` (`lib/quebrado/dialogs/add_transaction_dialog.dart:404`). El aviso «✓ Gasto registrado» con «Ver» sale de `widgets/suite_actions_test.dart::con registro muestra el aviso con «Ver» y celebra` (l. 148), con una acción falsa. `runSuiteAction` no navega (`lib/widgets/suite_actions.dart:345-375`). Libro activo: `addTransaction` usa `profileId: _activeDbName` (`lib/quebrado/viewmodels/app_state.dart:1256`); no hay test nuevo. |
| CA-05 | CUMPLE | `widgets/suite_actions_test.dart::«Ver» del gasto va al movimiento y sin id no hay «Ver»` (l. 62) y l. 148 (`Ver` → `/finanzas/movimientos/t1`). `widgets/suite_router_test.dart::«Ver» de un movimiento abre su detalle sobre el Historial` (l. 376: URL y `TransactionDetailBottomSheet`). Casos límite: otro libro (l. 395) e inexistente (l. 412). |
| CA-06 | CUMPLE | `widgets/suite_router_test.dart::CA-06: /diario abre el Diario y Atrás del navegador vuelve` (l. 515). Simula `pushRouteInformation`. Falta probarlo a mano en el navegador (ver la sección «Pasos manuales»). |
| CA-07 (P-04 rev.) | CUMPLE | `widgets/suite_router_test.dart`, grupo «PIN una vez al día…»: `un enlace directo pide el PIN y luego abre el movimiento` (l. 594). Además, en el mismo archivo: l. 573 (al arrancar), l. 626 (cancelar), l. 646 (el menú no salta el candado), l. 666 (`siguiente` externo) y l. 703 (A1). Por separado, `widgets/suite_unlock_view_test.dart` (l. 34, l. 53). |
| CA-08 | CUMPLE | `agente/viewmodels/agente_state_test.dart::piensa mientras genera sin texto, habla con el streaming y vuelve al reposo` (l. 46). `screens/ortiz_home_screen_test.dart::la cara refleja el ánimo de AgenteState` (l. 225: thinking → talking → idle en la UI). |
| CA-09 | CUMPLE | `agente/viewmodels/agente_state_test.dart::pone a Ortiz contento ~1,8 s y vuelve al reposo` (l. 84). `widgets/suite_actions_test.dart` l. 148 (happy al aparecer el aviso, idle a los 2 s). `widgets/suite_router_test.dart::la cara de la barra refleja el ánimo de Ortiz` (l. 769). |
| CA-10 (PA-02) | CUMPLE | `widgets/suite_shortcuts_test.dart`: `Ctrl+K abre la paleta y otro Ctrl+K la cierra` (l. 64), ⌘+K (l. 75), `/` fuera de un campo (l. 92), `/` dentro de un campo (l. 103), Esc cierra el menú (l. 127), Esc cierra la paleta (l. 139). Que Esc cierre una hoja de acción no tiene test propio: lo hace el comportamiento estándar de Flutter. |
| CA-11 | CUMPLE en la letra (observación O-01) | `grep "Agente Ortiz"` en `lib/` da 0 resultados. Siguen visibles textos con «Agente»: `lib/agente/dialogs/agente_settings_dialog.dart:67` («Ajustes del Agente IA») y `:185` («Ajustes del Agente guardados correctamente.»), y el tooltip de `lib/agente/screens/agente_home_screen.dart:95` («Ajustes del Agente»). El prompt (`lib/agente/services/gemini_service.dart:35`) no se llama a sí mismo «Ortiz». Ningún test protege el CA. |
| CA-12 | CUMPLE | `agente/widgets/ortiz_face_test.dart`: grupo `ortizFacePose sin animación (CA-12)` (l. 40: cada ánimo tiene su imagen fija; l. 53: no se mueve con el tiempo) y el `testWidgets` de l. 132 con movimiento reducido. |
| CA-13 | CUMPLE (según el informe del hilo principal; no lo volví a ejecutar) | Puerta `suite-run.sh` en verde. `test/all_imports_test.dart` aparece modificado en `git status`. No revisé que `.claude/known-failures` (también modificado) solo baje: queda pendiente para el revisor. |

## Hallazgos

- **H-01 (CA-04 / C8): doble confirmación al registrar un gasto.**
  - Después de `navigator.pop(newTx)`, el formulario sigue abriendo el diálogo modal anterior `TransactionSuccessDialog` con `barrierDismissible: false` (`add_transaction_dialog.dart:406-413`).
  - Desde un chip o el menú, la persona ve ese modal **además** del aviso «✓ Gasto registrado · Ver». Puede que el aviso caduque mientras el modal lo tapa.
  - C8 dice: «se cierra el formulario y aparece un aviso». Queda como pregunta para la persona (PQ-01). No se cambia código.
- **O-01 (CA-11): quedan «Agente» y «Agente IA» en los ajustes.** La spec pide el renombre «en la UI, en los ajustes y en el prompt». Pregunta PQ-02.

## Gaps (propuestas para `test-engineer`)

1. **CA-04 de extremo a extremo.** Montar `buildSuiteRouter` en `/` con un `AppState` falso y libro activo `quebrado.db`. Tocar el chip «Registrar gasto», rellenar y guardar `AddTransactionBottomSheet`. Esperar: la URL sigue en `/`, aparece «Gasto registrado» con «Ver», el `addTransaction` falso recibe el movimiento con el libro activo y el ánimo es `happy`. Si se mantiene H-01, el test debe fijar si el modal aparece o no.
2. **CA-05 encadenado.** El mismo test sigue: tocar «Ver» lleva a `/finanzas/movimientos/<id>` y se ve `TransactionDetailBottomSheet`.
3. **CA-11 por contrato.** Un test en `test/contract/` que recorra `lib/**/*.dart` y falle si aparece el literal «Agente Ortiz». Si la persona lo decide en PQ-02, también «Agente IA».
4. **CA-10, Esc con una hoja abierta.** Abrir una acción en `showResponsiveSheet`, pulsar Esc y comprobar que la hoja se cierra.

## Pasos manuales (dispositivo o navegador)

- **CA-06:** en el build web, escribir `/diario` en la barra y pulsar Atrás del navegador.
- **CA-07:** activar el PIN y abrir `/finanzas/movimientos/<id>` en una pestaña nueva. Repetirlo el mismo día y comprobar que no se vuelve a pedir.
- **CA-04:** registrar un gasto desde el chip en compact y en expanded, y observar H-01.
- **CA-02:** revisar a ojo los anchos 840, 1199 y 1200.

## Preguntas abiertas

- **PQ-01:** ¿Se quita el modal `TransactionSuccessDialog` cuando el gasto se registra desde una acción rápida (o siempre), y solo queda el aviso con «Ver»?
- **PQ-02:** ¿«Ajustes del Agente IA», «Ajustes del Agente guardados correctamente.» y el tooltip «Ajustes del Agente» pasan a «Ajustes de Ortiz»? ¿El prompt de sistema debe presentarse como «Ortiz»?
