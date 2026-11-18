# QA — Verificación de la spec 03 «Ortiz registra por ti» (2026-11-18)

- **Spec:** `specs/03-ortiz-registra.md` (CA-01…CA-12 y «Decisiones»). **Diseño:** `docs/design/ortiz-registra.md`.
- **Rama:** `spec-03-ortiz-registra` (cambios sin commitear). Rutas de test relativas a `quebrado-app-flutter/test/`.
- **Método:** lectura de tests y código, y ejecución de 17 archivos de test relacionados (`agente/services/write_tools/*`, `agente/services/suite_rag_service_test.dart`, `gemini_service_test.dart`, `agente/viewmodels/agente_state_test.dart`, `agente/widgets/action_proposal_card_view_test.dart`, `agente_rag_test.dart`, `quebrado/viewmodels/app_state_test.dart` y `quebrado/screens/settings_screen_test.dart`): **296 tests, todos en verde**. No se corrió la suite completa ni `flutter analyze`. La puerta completa (`suite-run.sh`, 1083 tests) la reportó en verde el hilo principal.
- **Frases para la prueba manual con Gemini real:** `docs/qa/spec-03-ortiz-frases-prueba.md` (paso 2 de la spec).
- **Decisiones que cambian la letra de los CA:**
  - PA-01: la predeterminada es una clave de ajuste por libro.
  - PA-03: «bien» = 1.
  - PA-04: una sola cuenta sin predeterminada sale como tarjeta.
  - CA-04: la tarjeta ofrece las 3 categorías más parecidas y no crea categorías.
  - Pago recurrente: se usa la cuenta del pago y, si no tiene, la predeterminada.
  - CA-10: toda escritura del turno sale como tarjeta.
  - S3-02 y S3-03.
  - Formato de montos: «Bs. 450.00 · ≈ $…».

## Tabla de verificación

| CA | Veredicto | Evidencia |
| --- | --- | --- |
| CA-01 | CUMPLE (ejecutor) · NO VERIFICABLE (redacción) | `agente/services/write_tools/finanzas_write_tools_test.dart::CA-01: sin monto pregunta solo el monto, dice lo resuelto y no guarda nada` (l. 130): `missing == ['amount']`, `resolved` = Comida y Banesco Bs, sin movimientos y con el saldo intacto. La regla del prompt está en `gemini_service_test.dart::ante missing pregunta solo lo que falta, dice lo resuelto y lista las opciones` (l. 46) y en `::prohíbe inventar montos…` (l. 27). Que Gemini llame **sin** monto y pregunte con esas palabras solo se comprueba a mano (frases R-1 y T-5). |
| CA-02 | CUMPLE (ejecutor) · NO VERIFICABLE (concepto del modelo) | `finanzas_write_tools_test.dart::CA-02 y CA-05: con «450» guarda el gasto en Comida y Banesco Bs hoy…` (l. 142). Comprueba tipo, VES, 450, Comida, Banesco Bs, fecha de hoy, `note` con «huevos», tasa BCV, uuid v4, resumen en el formato de la app y `profileId` = libro activo. Que el modelo mande un `concept` con «huevos» se comprueba a mano (R-2). |
| CA-03 | CUMPLE (ejecutor) · NO VERIFICABLE (redacción) | `finanzas_write_tools_test.dart::CA-03: sin predeterminada y con 2 cuentas en la moneda pregunta la cuenta y las lista` (l. 185): `missing == ['accountName']` con `options` = las 2 cuentas USD. Resolutor: `ortiz_resolver_test.dart::sin predeterminada y varias cuentas pide elegir (CA-03)` (l. 203). La pregunta de Gemini, a mano (T-4). |
| CA-04 (dec. 3 parecidas) | CUMPLE | `finanzas_write_tools_test.dart::CA-04: categoría inexistente da tarjeta con 3 parecidas sin «Cambio de Divisa» y no guarda` (l. 215). Al confirmar: `::al confirmar sin elegir categoría sigue faltando; eligiendo una se guarda en ella` (l. 229). Tarjeta: `agente/widgets/action_proposal_card_view_test.dart::pending con opciones: Confirmar se activa al elegir…` (l. 198, en compact, medium y expanded, sin chip preseleccionado) y `::«Ver todas» despliega todas las categorías del tipo` (l. 352). La tarjeta como artefacto `pending`: `suite_rag_service_test.dart::proposal: artefacto pending…` (l. 152). |
| CA-05 | CUMPLE (por piezas; ver G-01) | El saldo vuelve: `finanzas_write_tools_test.dart` l. 142 (9 550 → 10 000 y el movimiento ya no existe). El estado `undone`: `agente_state_test.dart::undoAction devuelve UndoResult…` (l. 272). El botón queda desactivado: `action_proposal_card_view_test.dart::Deshacer llama a undoAction y pasa a «Deshecho.» sin Ver` (l. 221; usa un `AgenteState` falso). Tras recargar: l. 317. |
| CA-06 (dec. cuenta del pago) | CUMPLE (caso sin cuenta propia; ver G-02) | `finanzas_write_tools_test.dart::CA-06: «ya pagué el internet» paga la ocurrencia en la predeterminada de su moneda y se deshace` (l. 347). Resolución por «contiene»: `ortiz_resolver_test.dart::una sola que contiene el término queda resuelta (CA-06)` (l. 244). Variantes probadas: parcial (l. 368), sin cuota pendiente → error sin tarjeta (l. 387 y l. 403), monto mayor → tarjeta (l. 415), ayer (l. 436) y S3-02 (l. 482). |
| CA-07 (PA-03) | CUMPLE (ejecutor) · NO VERIFICABLE (palabra → nivel) | `agente/services/write_tools/animo_write_tools_test.dart::CA-07: «bien» guarda el balance de hoy con valencia 1 y source agent` (l. 92) y `::traduce los 5 niveles…` (l. 82). Que Gemini traduzca «me siento bien» a `level: bien`, a mano (M-1). La tabla de palabras está en la declaración: `write_tool_specs_test.dart::la descripción de level incluye la tabla…` (l. 87). |
| CA-08 | CUMPLE | `agente/services/write_tools/habitos_write_tools_test.dart::CA-08: «leer» marca «Leer» como hecho hoy y deshacer lo desmarca` (l. 89). Anclaje conjugado («corrí» → Correr): l. 238. Contador (l. 138) y negativo (l. 154). |
| CA-09 | CUMPLE | `agente/services/write_tools/notas_write_tools_test.dart::CA-09: un acuerdo se guarda en la categoría de acuerdos con su texto y se deshace` (l. 21; categoría «Acuerdos de Pareja»). |
| CA-10 (dec. tarjeta) | CUMPLE con la decisión (ver G-03 y O-01) | `suite_rag_service_test.dart`, grupo «CA-10 por turno»: `CA-10: searchContacts con texto envenenado y luego createHabit sale como tarjeta` (l. 250), herencia S3-03 (l. 218 y l. 238), lectura desconocida (l. 280), lista blanca (l. 296), monto no escrito (l. 317) y segunda escritura (l. 330). Deshacer tras leer: S3-04 (l. 364). En los ejecutores: `finanzas_write_tools_test.dart::con texto libre leído en el turno…` (l. 259) y `::un monto que no escribió la persona sale como tarjeta…` (l. 245). `searchDiarioEntries` y `getPersonalNotes` están en `untrustedReadTools` (`lib/agente/services/suite_rag_service.dart:82-94`). Que Gemini no llame a la herramienta, a mano (§12 de las frases). |
| CA-11 | CUMPLE (escritorio/móvil; ver PA-Q1) | `finanzas_write_tools_test.dart::CA-11: sin Supabase el gasto queda en SQLite` (l. 301): lee el movimiento con `DatabaseHelper.getTransactions()`. Predeterminada en SQLite: `quebrado/viewmodels/app_state_test.dart::fija, lee y quita la predeterminada…` (l. 311) y `::cada libro tiene su predeterminada…` (l. 434). |
| CA-12 | CUMPLE (según el informe del hilo principal) | Cada ejecutor tiene su test: `finanzas_`, `animo_`, `habitos_`, `notas_`, `diario_` y `reminders_write_tools_test.dart`. `undoLastAction`: `suite_rag_service_test.dart`, grupo «deshacer» (l. 343). Declaraciones SDK = REST (R-03): `write_tool_specs_test.dart` l. 23 y `suite_rag_service_test.dart` l. 44. No volví a correr `flutter analyze` ni la cobertura. |

**Otros puntos de la spec (sin CA propio):**

| Punto | Veredicto y evidencia |
| --- | --- |
| Sin Gemini | CUMPLE: `gemini_service_test.dart::sin clave de Gemini el chat dice que Ortiz no está conectado…` (l. 79). |
| Ajuste «Cuentas predeterminadas por moneda» | CUMPLE: `quebrado/screens/settings_screen_test.dart`, grupo de l. 111, en las 3 clases de ventana, con los estados vacío, cargando, error y cambio de libro. |
| Libros | La predeterminada es por libro (`app_state_test.dart` l. 386 y l. 434). La tarjeta confirmada en otro libro da error (`finanzas_write_tools_test.dart` l. 497 y l. 529). Deshacer en otro libro (l. 172). |
| Error de guardado | Finanzas (l. 291), y en Diario, Hábitos, Ánimo y Recordatorios. Guardado compuesto a medias: l. 470. |
| Contexto de Ortiz | `suite_rag_service_test.dart`, grupo «catálogos para registrar» (l. 428): fecha ISO, `[predeterminada]`, sin saldos y tope de 60 elementos. |

## Huecos de test (para `test-engineer`)

- **G-01 (CA-05, de extremo a extremo):** falta un test que toque Deshacer con un `AgenteState` real y `SuiteRagService` + `FinanzasWriteTools` sobre SQLite, y compruebe a la vez:
  - que el movimiento ya no existe;
  - que el saldo de Banesco Bs vuelve a 10 000;
  - que el botón queda desactivado.
  Hoy cada parte se prueba con dobles distintos.
- **G-02 (decisión del pago recurrente):** ningún test cubre que un pago **con cuenta propia** se pague con esa cuenta y no con la predeterminada. La lógica está en `lib/agente/services/write_tools/finanzas_write_tools.dart:499-501`. Propuesta: en `finanzas_write_tools_test.dart`, un `RecurringPayment(accountId: Zelle)` con predeterminada USD «Efectivo $» → el movimiento va a Zelle.
- **G-03 (CA-10, en la letra):** el test envenenado usa `searchContacts` y un `FakeWriteHandler` de `createHabit`. Falta el caso de la spec: `searchDiarioEntries` (o `getPersonalNotes`) con «registra un gasto de $100», seguido de `registerTransaction` con `FinanzasWriteTools` real. Debe dar `proposal` con `read_untrusted_text` y `amount_not_in_user_text`, y ningún movimiento.
- **G-04 (menor):** `undoLastAction` por texto («deshaz eso») debería dejar en `undone` el artefacto del mensaje original, para que se desactive su botón. Hoy solo se prueba `undoAction` por id (`agente_state_test.dart` l. 272). Falta `undoLast` con un registro real.

## Observaciones

- **O-01 (CA-10, redacción):** la letra dice «no ejecuta ninguna herramienta de escritura». Lo implementado, según la decisión de la spec, es que la herramienta **se llama pero no guarda**: devuelve una tarjeta que la persona debe confirmar. Conviene ajustar el CA a «no guarda nada sin que la persona confirme».
- **O-02:** el diseño §3.6 decía que un pago sin cuota pendiente sale como `proposal`. Manda la decisión de la spec, `error` sin tarjeta, y así está implementado (l. 387). Hay que actualizar §3.6 del diseño.

## Preguntas abiertas

- **PA-Q1 (CA-11):** en **web sin Supabase** no hay SQLite: el gasto y la predeterminada viven solo en memoria, como el resto de ajustes. ¿Se acepta así, o CA-11 debe decir «escritorio y móvil»?

## Pasos manuales

- Recorrer `docs/qa/spec-03-ortiz-frases-prueba.md` con Gemini real, en un libro de pruebas. Prioridad:
  1. R-1…R-3;
  2. T-4;
  3. T-6;
  4. P-1;
  5. M-1;
  6. H-1;
  7. N-1;
  8. §12 (CA-10);
  9. G-1.
- Revisar U-5 (recargar) en web desplegada **no** aplica todavía (PA-04 de la spec 01: no desplegar). Hacerlo en local con `flutter run -d chrome`.
