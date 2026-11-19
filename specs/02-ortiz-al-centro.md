# 02 — Ortiz al centro: inicio, navegación, URLs, acciones rápidas y cara

- **Estado:** Implementado <!-- Borrador | En revisión | Aprobado | Implementado | Obsoleto -->
- **Depende de:** 01
- **Fecha:** 2026-11-17
- **Módulo(s):** suite (`screens/`, `widgets/`), agente
- **Objetivo (una frase):** Que la app abra en una conversación con Ortiz y que, desde un menú (hamburguesa en el teléfono, riel fijo en el computador), se navegue a cada app por su propia URL y se usen las acciones rápidas de cada app sin salir del chat.

> Maqueta: https://claude.ai/artifact/TR22XAWd9anJ6xYLXCVn48 · Decisiones C3, C5–C8, C11.

## Alcance
**Entra:**
- **Inicio** (`lib/screens/ortiz_home_screen.dart`):
  - El chat de `agente/` a pantalla completa.
  - Saludo según la hora («Buenos días / Buenas tardes / Buenas noches, soy Ortiz»).
  - Un espacio para la franja de hoy (la llena la spec 04).
  - Chips de acción rápida encima del campo de texto.
- **Navegación según el ancho:**
  - `< 840` (`!isDesktop`): botón ☰ que abre un menú lateral en acordeón. Cada app se despliega y muestra «Abrir» más sus acciones rápidas.
  - `≥ 840`: riel fijo a la izquierda con las mismas apps y acciones (que se despliegan o aparecen al pasar el cursor), el chat al centro y un panel a la derecha. El panel muestra el resumen de hoy (spec 04) y en él se abren las acciones rápidas mediante `showResponsiveSheet`.
- **URLs por app:**
  - Apps: `/` (Ortiz), `/finanzas`, `/diario`, `/habitos`, `/recordatorios`, `/notas`.
  - Detalle para «Ver»: `/finanzas/movimientos/:id`, `/finanzas/pagos`, `/diario/entradas/:id`, `/diario/animo`, `/habitos/:id`, `/recordatorios/:id`, `/notas/:id`.
  - Estrategia de URL por ruta (sin `#`). `vercel.json` ya reescribe todo a `index.html`.
- **Catálogo `SuiteAction`** (`lib/widgets/suite_actions.dart`): cada acción tiene app, etiqueta, icono y la función que abre el formulario **existente** de su app. Del mismo catálogo salen el menú, el riel y los chips.

| App | Acción | Abre |
| --- | --- | --- |
| Finanzas | Registrar gasto / ingreso | `AddTransactionDialog` |
| Finanzas | Tasas del día | aviso con BCV, paralelo y euro |
| Finanzas | Pagos pendientes | `PendingConfirmationsDialog` |
| Diario | Nueva entrada | `entry_editor_dialog` |
| Diario | Registrar ánimo | `MoodCheckinSheet` |
| Diario | Nuevo contacto | `ContactEditorDialog` |
| Hábitos | Nuevo hábito | `habit_terminal_editor_dialog` |
| Hábitos | Marcar hábitos de hoy | ver PA-03 |
| Recordatorios | Nuevo recordatorio | `ReminderEditorDialog` |
| Recordatorios | Agenda de la semana | `weekly_schedule_view` en hoja |
| Notas | Nueva nota / Nuevo acuerdo | `NoteEditorScreen` (ver PA-04) |

- **Aviso al guardar** (C8): la acción no navega. Al guardar se cierra el formulario y aparece un aviso «✓ Gasto registrado» con el botón **Ver**, que lleva a la URL del registro. Para eso, los formularios tienen que **devolver** el registro creado (hoy hacen `pop()` sin valor).
- **Cara de Ortiz** (`lib/agente/widgets/ortiz_face.dart`):
  - Ánimos: `OrtizMood { idle, thinking, talking, happy }`.
  - Origen del ánimo:
    - `thinking`: `AgenteState.isGenerating` sin texto todavía.
    - `talking`: mientras llega el streaming.
    - `happy`: unos 1,8 s después de guardar algo.
  - En web, los ojos o la cabeza siguen el cursor.
  - Hay dos versiones con la misma interfaz:
    1. **Rive: «Bunny emoji»** de cathy._.linlin, CC BY 4.0 (https://rive.app/marketplace/9058-17308-bunny-emoji/). Es la opción preferida si pasa la validación del paso 1.
    2. **Respaldo vectorial, estilo «Pantalla»** (el de la maqueta), con `CustomPainter`. Se usa si el conejo no pasa la validación y mientras el archivo `.riv` no esté listo.
- **Renombre:** «Agente Ortiz» pasa a «Ortiz» en la UI, en los ajustes y en el prompt de sistema. El módulo de código se sigue llamando `agente`.
- **Atajos de teclado (web):** `Ctrl/⌘+K` abre el menú, `/` lleva al campo del chat y `Esc` cierra la hoja o el menú.
- **Sin interruptor de transición** (PA-05): al terminar, se borran el launcher (`AppLauncherScreen`), el hub de acciones y el command center.
- **Paleta de comandos** (`Ctrl/⌘+K`, PA-02) y **hoja «Marcar hábitos de hoy»** (PA-03).
- **Pantalla de carga web** con texto en lugar del logo verde.

**Fuera:**
- El contenido de la franja de hoy, del panel y del «Resumen del día»: spec 04. Aquí solo están sus espacios y el chip.
- Que Ortiz registre cosas desde el chat: spec 03.
- Rehacer el estilo de las pantallas de cada app: spec 05.

## Flujo y UX
- **Teléfono (compact):** `/` muestra la barra superior (☰, cara + «Ortiz», nueva conversación), el chat, los chips y el campo de texto. ☰ abre el menú; tocar una acción abre el formulario en hoja inferior. Al guardar, aparece el aviso con «Ver».
- **Computador (medium ≥ 840 y expanded):** el riel (210/240 px) y el chat al centro, con un ancho máximo de lectura de unos 720 px. El panel derecho mide 320–380 px. Las acciones se abren en el panel lateral derecho de `showResponsiveSheet`.
- **Estados:**
  - Chat vacío: saludo y chips.
  - Sin Gemini configurado: el chat muestra «Ortiz no está conectado; las acciones rápidas siguen funcionando», y el menú y las acciones funcionan igual.
  - Sin Supabase: cada app usa su respaldo actual.
- **URL desconocida:** redirige a `/` con el aviso «Esa página no existe».
- **Textos clave:**
  - «Pregúntale algo a Ortiz…»
  - «Conectado a 5 apps»
  - «✓ {Gasto|Ingreso} registrado» / «✓ Entrada guardada» / «✓ Ánimo registrado»
  - «Ver»

## Modelo de datos
No hay tablas nuevas. Los formularios devuelven su modelo (`Transaction`, `DiarioEntry`, `MoodLog`, etc.) al cerrarse.

## Contrato de datos
No cambia. Las acciones usan los mismos ViewModels de cada app.

## Impacto
- [ ] Respaldo JSON / importación
- [ ] SQLite local de `quebrado`
- [x] Agente Ortiz: renombre en el prompt de sistema; la cara depende de su estado
- [x] Otras mini-apps: sus formularios devuelven el registro creado
- [x] Design system: menú, riel, chips, aviso y `OrtizFace`

## Plan de implementación
| Paso | Qué | Archivos | Agente | Verificación |
| --- | --- | --- | --- | --- |
| 1 | **Validar el conejo de Rive:** descargarlo, listar los artboards, la state machine y sus entradas; probar el paquete `rive` en el build web (peso y rendimiento); decidir si cubre los 4 ánimos tal cual, si necesita remezcla o si no sirve | informe en `docs/design/ortiz-face.md` | ui-ux-designer + persona | regla de decisión (ver Decisiones) |
| 2 | Diseño del router y de las rutas (`go_router` o `Router` nativo), deep links con PIN/biometría activos | `docs/design/rutas.md` | architect | revisión de la persona |
| 3 | Router y rutas por app | `lib/main.dart`, `lib/widgets/suite_router.dart`, test | flutter-dev | test de rutas |
| 4 | `SuiteAction` + menú en acordeón + riel | `lib/widgets/suite_actions.dart`, `suite_drawer.dart`, `suite_rail.dart` | flutter-dev | tests de widget compact/expanded |
| 5 | `OrtizHomeScreen` + adaptación de `ResponsiveSuiteScaffold` + interruptor de transición | `lib/screens/ortiz_home_screen.dart`, `lib/widgets/responsive_suite_scaffold.dart` | flutter-dev | tests de widget |
| 6 | Formularios que devuelven el registro + aviso con «Ver» | `add_transaction_dialog.dart`, `entry_editor_dialog.dart`, `mood_checkin_sheet.dart` (y en un paso aparte los demás de la tabla) | flutter-dev | tests de widget por formulario |
| 7 | `OrtizFace` (Rive o vectorial «Pantalla») + ánimo desde `AgenteState` | `lib/agente/widgets/ortiz_face.dart`, `agente_state.dart`, test | flutter-dev | test del ánimo según el estado |
| 8 | Renombre a «Ortiz» + atajos de teclado | `lib/agente/…`, `lib/widgets/suite_shortcuts.dart` | flutter-dev | test de atajos |
| 9 | Revisión | — | revisor + ui-ux-designer | `suite-run.sh` + revisión visual en las 3 clases de ventana |

## Criterios de aceptación
- **CA-01** Dado un ancho < 840, cuando se abre `/`, entonces se ven la barra con ☰, el saludo de Ortiz según la hora, los chips y el campo de texto, y no aparece el launcher anterior (con el interruptor apagado).
- **CA-02** Dado un ancho ≥ 840, cuando se abre `/`, entonces se ven el riel con las 5 apps, el chat al centro y el panel derecho.
- **CA-03** Dado el menú abierto, cuando se toca «Finanzas», entonces se despliegan «Abrir Finanzas» y sus acciones, y se pliega cualquier otra app abierta.
- **CA-04** Dado «Registrar gasto» en el menú o en un chip, cuando se guarda el formulario de Quebrado, entonces se cierra, la URL sigue en `/`, aparece «✓ Gasto registrado» con «Ver», y el gasto existe en el libro activo.
- **CA-05** Dado el aviso de CA-04, cuando se toca «Ver», entonces la URL pasa a `/finanzas/movimientos/<id>` y se muestra ese movimiento.
- **CA-06** Dada la URL `/diario` escrita en el navegador, cuando carga, entonces se abre el Diario. El botón Atrás del navegador vuelve a la vista anterior.
- **CA-07** Dado el PIN activado, cuando se abre directamente `/finanzas/movimientos/<id>`, entonces primero se pide el PIN y después se muestra el movimiento.
- **CA-08** Dado que Ortiz está generando una respuesta, cuando todavía no llega texto, entonces la cara está en `thinking`; mientras llega el streaming, en `talking`; al terminar, en `idle`.
- **CA-09** Dado que se guarda una acción rápida, cuando aparece el aviso, entonces la cara pasa a `happy` y vuelve a `idle` en unos 2 s.
- **CA-10** Dado el atajo `/` fuera de un campo de texto, cuando se pulsa, entonces el foco va al campo del chat. Con `Ctrl/⌘+K` se abre el menú y con `Esc` se cierra.
- **CA-11** No queda ningún texto visible «Agente Ortiz»; la UI dice «Ortiz».
- **CA-12** Dado `disableAnimations`, cuando cambia el ánimo, entonces no hay animación, pero el estado sí se refleja.
- **CA-13** `flutter analyze` termina con 0 errores y 0 warnings, la suite pasa y `all_imports_test` está regenerado.

## Decisiones
**Tomadas:**
- C5: teléfono y computador por igual.
- C6: chat + franja de hoy.
- C7: riel fijo + panel.
- C8: formularios propios de cada app, aviso con «Ver» y sin navegar.
- C11: una URL por app.
- C3: personaje de Rive; la persona propone «Bunny emoji» y, si no es posible, el respaldo vectorial «Pantalla».

**Regla de decisión del paso 1** (el conejo «se puede» usar si cumple todo):
- (a) La licencia permite usarlo. Ya se cumple: es CC BY 4.0 y se le da crédito en Ajustes › Acerca de: «Personaje: Bunny emoji de cathy._.linlin (CC BY 4.0)», con el enlace.
- (b) Funciona en el build web de Flutter con un rendimiento aceptable.
- (c) Representa los 4 ánimos, ya sea tal cual o con una remezcla hecha por la persona en el editor de Rive.

Si falla (b), o falla (c) y no hay remezcla, se usa «Pantalla».

**Descartadas (y por qué):**
- Hacer formularios nuevos para las acciones rápidas: la persona quiere los de cada app.
- Navegar a la app al guardar: la persona prefiere el aviso con «Ver».

## Riesgos
- **R-01** El conejo reacciona a pasar el cursor y a hacer clic (es un emoji). Probablemente no tenga los estados «pensando» y «hablando», y haga falta remezclarlo.
- **R-02** El runtime de Rive le suma peso al build web. Se mide en el paso 1.
- **R-03** Cambiar `home:` por un router afecta a toda la navegación. Es posible que haya `Navigator.push` que asumían el launcher. Mitigación: el interruptor de transición y las pruebas por app.
- **R-04** Algunos formularios guardan dentro del propio diálogo y no tienen el id hasta después del guardado en Supabase. Hay que devolverlo sin romper el modo sin Supabase.

## Preguntas abiertas
Todas resueltas por la persona el 2026-11-17:
- ~~PA-01~~ → cara vectorial **«Pantalla» mientras tanto**; `OrtizFace` deja listo el cambio a Rive si la persona remezcla el conejo más adelante.
- ~~PA-02~~ → `Ctrl/⌘+K` abre una **paleta de comandos global** (buscar apps y acciones rápidas), generalizando la de Recordatorios.
- ~~PA-03~~ → **hoja con casillas** con los hábitos de hoy.
- ~~PA-04~~ → «Nueva nota» abre el **editor a pantalla completa** en el teléfono (en escritorio, en el panel).
- ~~PA-05~~ → **sin interruptor**: al terminar la 02 se borran el launcher, el hub de acciones y el command center (cierra el paso 8 de la spec 05).
- Pedido extra de la persona: la pantalla de carga (web) muestra **texto** («Ortiz») en lugar del logo verde de Quebrado, por ahora.

## Qué NO entra
- Notificaciones push.
- Comandos de voz nuevos (el dictado actual se queda como está).

## Pasos manuales
- La persona revisa en Rive el archivo «Bunny emoji» (Preview/Remix) y, si hace falta, hace la remezcla.
- Ninguno en Supabase.

## Implementación (2026-11-18, rama `spec-02-ortiz-al-centro`, apilada sobre `spec-05-nuevo-estilo-apps`)
**Estado real:** implementada. `revisor`: APROBADO en la ronda 3. Auditoría de seguridad: `docs/security/2026-11-18-spec-02-pin.md` (resolución en su §6). Verificación: `docs/qa/2026-11-18-spec-02-verificacion.md`.

**Verificación de criterios**
| CA | Resultado | Evidencia |
| --- | --- | --- |
| CA-01 | CUMPLE | `test/screens/ortiz_home_screen_test.dart` (CA-01) y `suite_router_test.dart` (inicio); el launcher ya no existe (PA-05). |
| CA-02 | CUMPLE (con Q1) | Riel desde 840 (`responsive_suite_test.dart`); panel «Hoy» desde 1200 (`ortiz_home_screen_test.dart`), decisión Q1 de `docs/design/ortiz-home.md`. |
| CA-03 | CUMPLE | `test/widgets/suite_drawer_test.dart`, `suite_rail_test.dart`. |
| CA-04 | NO VERIFICABLE de extremo a extremo | Por piezas: el formulario devuelve el gasto, `runSuiteAction` avisa con «Ver» (`suite_actions_test.dart`), el gasto va al libro activo. Desde una acción rápida ya no sale el diálogo de éxito antiguo (PQ-01, test en `suite_actions_test.dart`). Falta un test chip → guardar → aviso con el router montado (hueco anotado); probar a mano. |
| CA-05 | CUMPLE | `suite_actions_test.dart` («Ver» → `/finanzas/movimientos/<id>`), `suite_router_test.dart` (abre el detalle). |
| CA-06 | CUMPLE | `suite_router_test.dart` (CA-06). Probar también en el navegador. |
| CA-07 | CUMPLE (P-04 revisada) | `suite_router_test.dart`, grupo «PIN una vez al día al entrar a la app». |
| CA-08 | CUMPLE | `test/agente/viewmodels/agente_state_test.dart`, `ortiz_home_screen_test.dart`. |
| CA-09 | CUMPLE | `agente_state_test.dart`, `suite_actions_test.dart` (alegría y vuelta a reposo a los 2 s). |
| CA-10 | CUMPLE (PA-02) | `test/widgets/suite_shortcuts_test.dart`: `/` enfoca el chat, `⌘K` abre la paleta, `Esc` la cierra. |
| CA-11 | CUMPLE | Sin «Agente Ortiz», «del Agente» ni «Agente IA» en textos de `lib/` (test `test/contract/ortiz_name_test.dart`); la instrucción de Gemini empieza por «Eres Ortiz» (PQ-02, `test/agente/services/gemini_service_test.dart`). |
| CA-12 | CUMPLE | `test/agente/widgets/ortiz_face_test.dart` (sin animación). |
| CA-13 | CUMPLE | Puerta verde: analyze 0/0, 801 tests, 2 fallos conocidos (bajó de 3), cobertura 36,82 % ≥ 31,3 %; `all_imports_test` con 233 archivos. |

**Desviaciones**
- **P-04 revisada por la persona (2026-11-18):** el PIN se pide **una vez al día al entrar a la app** (candado `/desbloquear` para toda la suite) y después se permite todo, en vez de «al entrar a Finanzas, una vez por sesión». Límite de 5 intentos con 30 s de espera y título «Desbloquear». Detalle en `docs/design/rutas.md` §10.
- **PQ-01 (2026-11-18):** desde las acciones rápidas no sale el diálogo de éxito de Finanzas, solo el aviso «✓ … · Ver». Dentro de Finanzas se mantiene.
- **PQ-02 (2026-11-18):** «Ajustes de Ortiz» en lugar de «Ajustes del Agente (IA)», y la instrucción de Gemini se presenta como Ortiz.
- Cara «Pantalla» (vectorial) en lugar del conejo de Rive (PA-01); `OrtizFace` queda lista para cambiarla.
- `⌘K` abre la paleta de comandos, no el menú (PA-02). El panel «Hoy» aparece desde 1200 px (Q1).
- Corrección colateral pedida en la spec: `usePinSecurity` no se cargaba desde Supabase.
- Splash web con el texto «Ortiz» (pedido extra).
- `.claude/known-failures` bajó de 3 a 2: el smoke de `widget_test` ya pasa.
- Pendientes nuevos: P-50 (restos del PIN), P-51 (claves de frecuencia de hábitos sin confirmar), P-52 (`Consumer` en `main.dart`), P-53 (espera de la primera carga), P-54 (calculadora en tests).

**Pasos manuales (antes de desplegar, PA-04 de la spec 01)**
- Probar en el navegador: registrar un gasto desde un chip (CA-04, solo el aviso con «Ver»), Atrás del navegador (CA-06), y con el PIN activado, el candado al entrar, recargar el mismo día sin PIN y los 5 intentos (CA-07).
- Revisión visual de la persona (sigue abierta P-49 de la spec 05).
- Ninguno en Supabase.
