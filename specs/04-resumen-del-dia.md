# 04 — Resumen del día

- **Estado:** Borrador <!-- Borrador | En revisión | Aprobado | Implementado | Obsoleto -->
- **Depende de:** 02 (inicio, chip y panel derecho)
- **Fecha:** 2026-11-17
- **Módulo(s):** agente (lee de quebrado, diario, habitos y recordatorios)
- **Objetivo (una frase):** Que, con un botón, Ortiz cuente lo importante de hoy en todas las apps (diario, ánimo, pagos pendientes, cumpleaños, hábitos, recordatorios y tasas), con filas calculadas que no dependen de la IA y un texto redactado por Gemini.

> Decisiones C6, C12–C16. Maqueta: https://claude.ai/artifact/TR22XAWd9anJ6xYLXCVn48

## Alcance
**Entra:**
- `lib/agente/services/daily_briefing_service.dart`: arma un `DailyBriefing` (modelo en `lib/agente/models/daily_briefing.dart`) a partir de los ViewModels, la fecha y la hora. No usa IA.
- `AgenteState.runDailyBriefing()`:
  1. Agrega al chat el mensaje «Resumen del día».
  2. Muestra al instante las filas (`BriefingBlock`).
  3. Envía a Gemini el JSON del resumen con un prompt nuevo y editable, «Resumen del día».
  4. Muestra el texto en streaming encima de las filas.
- **Franja de hoy** en el inicio: hasta 3 etiquetas con lo más relevante del `DailyBriefing`.
- **Panel derecho** en el computador: el `DailyBriefing` completo en filas.
- **Acciones por fila:**

| Fila | Acción |
| --- | --- |
| Diario | Escribir |
| Ánimo | Registrar |
| Pago | Pagar (abre el formulario de pago completo o parcial) |
| Cumpleaños | Ver contacto |
| Hábitos | Marcar |
| Recordatorio | Posponer |
| Tasas | Ver |

**Fuera:**
- Que el resumen se abra solo al entrar (C6: se pide con el botón).
- La lista del mercado (C15).
- Notificaciones push.

## Reglas del resumen (decididas por la persona)
| Regla | Valor | Origen |
| --- | --- | --- |
| Según la hora | Antes de la hora de corte, «lo que viene hoy». Después, «lo que faltó hoy» (sin diario, sin ánimo, hábitos sin hacer) y lo de mañana | C12 (la hora de corte está en PA-01) |
| Gasto pendiente | Ocurrencias de pagos recurrentes **sin pagar** con vencimiento entre hoy y hoy + 7 días, **más las vencidas**. Las parciales cuentan por lo que falta | C13 |
| Cumpleaños | Contactos del Diario con `birthdate` cuyo cumpleaños cae entre hoy y hoy + 7 días | C14 |
| Diario y ánimo | Cuántas entradas hay hoy; si hay ánimo registrado hoy | C15 |
| Hábitos | Hechos y pendientes de hoy entre los hábitos activos programados para hoy | C15 |
| Recordatorios | Los vencidos sin completar y los de hoy | C15 |
| Tasas | BCV, paralelo y euro del día, con la variación respecto al día anterior si hay registro | C15 |
| Montos | En $ con el equivalente en Bs a la tasa BCV del día. Los pagos en Bs se muestran convertidos a $ con su monto en Bs al lado. Los pagos en € se convierten con la tasa euro | C16 |
| Libro | El libro activo | PA-02 |

## Flujo y UX
- **Chip «Resumen del día»:**
  1. La cara pasa a `thinking` y aparece «Revisando tus apps» con las 5 apps encendiéndose (unos 1,5 s como máximo).
  2. Aparecen las filas.
  3. La cara pasa a `talking` mientras llega el texto.
- **Sin Gemini o sin conexión:** se muestran las filas con una frase fija («Esto es lo de hoy:»), sin error.
- **Sin nada pendiente:** «Todo al día: escribiste en el diario, no tienes pagos esta semana y tus hábitos están completos».
- Las filas van sin tarjeta, separadas por líneas finas y con el punto de color de la app (`SuiteApp`).
- **Privacidad:** a Gemini solo se envía el JSON del resumen (conteos, nombres de pagos, montos, nombres de contactos con cumpleaños y títulos de recordatorios), nunca el texto de las entradas del diario.

## Modelo de datos
| Entidad | Campo | Tipo | Notas |
| --- | --- | --- | --- |
| `DailyBriefing` (solo en memoria) | `generatedAt`, `period` (`morning`/`night`), `diario`, `mood`, `payments[]`, `birthdays[]`, `habits`, `reminders[]`, `rates` | modelo Dart | no se persiste |
| prompt «Resumen del día» | — | — | Junto a los prompts editables existentes (`chat_prompts`); el texto por defecto vive en el código |

## Contrato de datos
- Solo lectura, a través de los ViewModels.
- Hoy `AppState.fetchPendingPaymentsForProfile` devuelve **solo los pendientes de hoy** (`_pendingPaymentsToday`). Hace falta un método nuevo para la ventana de 7 días más los vencidos, con su test.
- No hay tablas nuevas. Si el prompt nuevo necesita una fila semilla en `chat_prompts`, se agrega con una migración idempotente.

## Impacto
- [ ] Respaldo JSON / importación
- [ ] SQLite local de `quebrado`: solo lectura
- [x] Agente Ortiz: prompt nuevo; datos enviados a Gemini (resumen, sin texto del diario)
- [x] Otras mini-apps: métodos nuevos de lectura en `AppState` (pendientes a 7 días) y quizá en `RemindersState`
- [x] Design system: `BriefingBlock` y la franja de hoy

## Plan de implementación
| Paso | Qué | Archivos | Agente | Verificación |
| --- | --- | --- | --- | --- |
| 1 | Diseño del modelo y de las fuentes de cada regla | `docs/design/resumen-del-dia.md` | architect | revisión de la persona |
| 2 | Pendientes de los próximos 7 días + vencidos | `app_state.dart`, test | flutter-dev | test de ViewModel con fechas límite (día 7, día 8, vencido, parcial) |
| 3 | `DailyBriefing` + `DailyBriefingService` | `daily_briefing.dart`, `daily_briefing_service.dart`, test | flutter-dev | tests por regla y por franja horaria |
| 4 | `runDailyBriefing` + prompt editable | `agente_state.dart`, `gemini_service.dart`, test | flutter-dev | test sin Gemini (solo filas) |
| 5 | `BriefingBlock`, franja de hoy y panel derecho | `lib/agente/widgets/briefing_block.dart`, `ortiz_home_screen.dart`, `suite_today_panel.dart` | flutter-dev | tests de widget compact/expanded |
| 6 | Acciones por fila | `briefing_block.dart` | flutter-dev | tests de widget |
| 7 | Auditoría de los datos enviados a Gemini | — | security-auditor | informe |
| 8 | Revisión | — | revisor + ui-ux-designer | `suite-run.sh` |

## Criterios de aceptación
- **CA-01** Dado un pago recurrente sin pagar que vence en hoy + 7, cuando se genera el resumen, entonces aparece. Si vence en hoy + 8, no aparece.
- **CA-02** Dado un pago vencido ayer y sin pagar, cuando se genera el resumen, entonces aparece como vencido.
- **CA-03** Dado un pago de $40 con $15 abonados, cuando se genera el resumen, entonces muestra «$ 25,00 · Bs {25 × BCV}».
- **CA-04** Dado un pago de Bs 1.000 y una tasa BCV de 250, cuando se genera el resumen, entonces muestra «$ 4,00 · Bs 1.000,00».
- **CA-05** Dado un contacto que cumple años en 7 días, cuando se genera el resumen, entonces aparece. Si cumple en 8 días, no aparece.
- **CA-06** Dada una hora posterior a la de corte y ningún ánimo registrado hoy, cuando se genera el resumen, entonces el periodo es `night` y la fila de ánimo dice que faltó.
- **CA-07** Dado Gemini sin configurar, cuando se toca «Resumen del día», entonces aparecen las filas con la frase fija y no se muestra ningún error.
- **CA-08** Dado el JSON que se envía a Gemini, cuando se inspecciona en el test, entonces no contiene el texto de ninguna entrada del diario.
- **CA-09** Dado un ancho ≥ 840, cuando se abre `/`, entonces el panel derecho muestra las mismas filas que el resumen.
- **CA-10** Dada la fila de un pago, cuando se toca «Pagar» y se confirma, entonces la fila queda marcada como pagada y el aviso ofrece «Ver».
- **CA-11** `flutter analyze` termina con 0 errores y 0 warnings, la suite pasa y la cobertura no baja.

## Decisiones
**Tomadas:**
- C6: el resumen se pide con el botón.
- C12: cambia según la hora.
- C13: pendientes de los próximos 7 días + vencidos, con los parciales por lo que falta.
- C14: cumpleaños con 7 días de anticipación.
- C15: incluye ánimo y hábitos, recordatorios y tasas, sin la lista del mercado.
- C16: $ con Bs al lado.

Las filas no dependen de la IA. Al aprobarse, estas reglas pasan a la tabla «Reglas confirmadas» de `docs/reglas-de-negocio.md`.

**Descartadas (y por qué):**
- Resumen automático al abrir: la persona prefirió la franja de hoy y el botón.
- Lista del mercado: no la eligió.

## Riesgos
- **R-01** Leer los 5 ViewModels requiere que estén cargados. Si alguno no terminó de cargar, su fila dice «Cargando…» y se completa cuando llegan los datos.
- **R-02** La variación de las tasas depende de que haya un registro del día anterior (`exchange_rate_record`). Si no lo hay, se omite la variación.

## Preguntas abiertas
- **PA-01** ¿A qué hora empieza la versión de «noche»? Recomendación: 18:00.
- **PA-02** Si tienes varios libros, ¿el resumen muestra solo el libro activo o suma todos? Recomendación: solo el activo, como el resto de la app.
- **PA-03** ¿Los hábitos negativos (los que estás dejando) entran en el resumen? Por ejemplo, «llevas 12 días sin fumar». Recomendación: sí, solo como racha y sin marcarlos como pendientes.
- **PA-04** De mañana, ¿«lo que viene» también incluye los recordatorios de mañana o solo los de hoy?

## Qué NO entra
- Historial de resúmenes anteriores.
- Enviar el resumen por correo o mensaje.

## Pasos manuales
- Ninguno, salvo que el prompt necesite una fila semilla en `chat_prompts`. En ese caso, ejecutar la migración en el SQL Editor de Supabase.
