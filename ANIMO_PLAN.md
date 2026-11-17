# Plan de implementación: Ánimo (registro de estados de ánimo y emociones)

> Feature de OrtizApp. Se registra el ánimo **en Diario Jottache** (el propio y el percibido de los contactos). **Hábitos** lo usa para correlaciones, el **Agente Ortiz** lo lee y lo registra, y la **Agenda Covey** aporta los roles como contexto.
> Backend: `supabase/013_animo_schema.sql` (listo para pegar en el SQL Editor de Supabase web).

---

## 0. Decisiones de diseño

| Decisión | Elección | Por qué |
|---|---|---|
| ¿Dónde vive? | Submódulo dentro de `lib/diario/` con su propio `AnimoState` | Diario ya distingue "yo" de cada contacto, tiene menciones y el detalle de contacto. Con un provider propio, Hábitos y Ortiz lo leen sin cargar `DiarioState` |
| ¿Mini-app nueva en el launcher? | **No.** Solo accesos rápidos en Launcher, Action Hub y Command Center | Evita cablear `SuiteModule` y 6 tiles más. El ánimo es un gesto de 2 segundos, no una app |
| Escala | Valencia de 5 niveles, de **-2 a +2** (Daylio) + energía opcional de 1 a 5 (How We Feel) | Registrar lleva 1 toque; el detalle es opcional |
| Emociones | Catálogo fijo de 32 palabras en 4 cuadrantes (RULER / How We Feel) | Da granularidad sin abrumar; las claves son estables para estadísticas |
| Contexto | Etiquetas (`mood_tags`, editables), roles Covey (`role_ids`) y personas (`@menciones`) | Daylio + Apple State of Mind, más la diferencia de usar los roles Covey |
| Registros por día | Ilimitados (`momentary`) y a lo sumo 1 balance del día (`daily`) por sujeto | Separación momentáneo / diario de Apple |
| Valor del día | Si hay `daily`, manda ese; si no, el promedio de los momentáneos | Regla única, usada igual en la app y en la vista SQL |
| Contactos | `perspective`: `observed` (lo vi) o `told` (me lo dijo) | Es tu percepción, no un auto-reporte. La interfaz siempre dice "percibido" |
| Integridad | Sin FKs (convención de la migración 010); limpieza por triggers | Los contactos, entradas, roles y etiquetas borrados no dejan huérfanos |

---

## 1. Modelo de dominio

### 1.1 Valencia (`valence`)
| Valor | Emoji | Etiqueta | Color |
|---|---|---|---|
| -2 | 😞 | Muy mal | `#7048E8` |
| -1 | 😕 | Mal | `#4DABF7` |
| 0 | 😐 | Normal | `#ADB5BD` |
| 1 | 🙂 | Bien | `#51CF66` |
| 2 | 😄 | Excelente | `#FCC419` |

> Revisa los colores contra `DiarioColors` y valida el contraste en claro y oscuro.

### 1.2 Energía (`energy`, opcional)
Del 1 al 5 ("Batería": Agotado · Baja · Media · Alta · A tope). Se usa para ordenar las emociones sugeridas por cuadrante.

### 1.3 Catálogo de emociones (`mood_catalog.dart`, claves en minúscula y sin tildes)
| Cuadrante | Color | Emociones |
|---|---|---|
| Alta energía · Agradable | amarillo | entusiasmado, alegre, orgulloso, motivado, emocionado, inspirado, optimista, divertido |
| Baja energía · Agradable | verde | tranquilo, relajado, agradecido, satisfecho, en_paz, seguro, comodo, esperanzado |
| Alta energía · Desagradable | rojo | ansioso, estresado, frustrado, enojado, irritable, abrumado, nervioso, celoso |
| Baja energía · Desagradable | azul | triste, cansado, desanimado, solo, aburrido, decepcionado, culpable, agotado |

Reglas del selector:
- Valencia > 0: se muestran primero los cuadrantes agradables. Valencia < 0: primero los desagradables. Valencia 0: todos.
- Energía ≥ 4: primero los de alta energía. Energía ≤ 2: primero los de baja.
- Los demás cuadrantes quedan en "Ver todas".
- Máximo 3 emociones por registro.

### 1.4 Tablas (ver el SQL)
- **`mood_logs`**: `id, user_id, contact_id (NULL = yo), perspective, kind, valence, energy, emotions[], tag_ids[], role_ids[], mentioned_contact_ids[], note, diario_entry_id, source, logged_at, log_date, created_at, updated_at`.
- **`mood_tags`**: `id, user_id, name, emoji, group_key, color_hex, sort_order, is_system, archived`. Trae 29 presets globales (`mtag_*`).
- **Vista `mood_daily_summary`**: `user_id, contact_id, log_date, logs_count, day_valence, min/max_valence, avg_energy, emotions[]`.

---

## 2. Backend: pasos en Supabase web

1. Abre **Supabase Dashboard → proyecto → SQL Editor → New query**.
2. Pega el contenido completo de `supabase/013_animo_schema.sql` y pulsa **Run**.
   - Es idempotente: puedes correrlo varias veces.
   - Si aparece un `NOTICE` diciendo que falta `diario_contacts`, `diario_entries` o `roles`, corre antes la migración que falta (004 u 011) y repite la 013.
3. **Verificación.** Pega esto en una query nueva; también está comentado en la sección 6 del script:
   ```sql
   SELECT COUNT(*) FROM public.mood_tags WHERE is_system;                      -- 29
   SELECT tgname FROM pg_trigger WHERE tgname LIKE '%mood%' AND NOT tgisinternal; -- 7
   SELECT * FROM public.mood_daily_summary LIMIT 5;
   ```
4. **Realtime:** en *Database → Publications → supabase_realtime*, confirma que `mood_logs` y `mood_tags` estén activas. El script las agrega, pero conviene revisarlo.
5. **RLS:** en *Authentication → Policies*, confirma que ambas tablas tengan la política `Permitir acceso a …`. Es el mismo patrón que `notas`.
6. **Rollback** (solo si hace falta deshacer): la sección 7 del script, sin comentar.
7. Deja el script versionado en el repo (ya está en `supabase/013_animo_schema.sql`) y anota en `DATABASE_MODELS.md` que ya se aplicó en producción.

> **Ya validado:** el script se ejecutó dos veces seguidas en un Postgres local con stubs de `auth`, `diario_*` y `roles`. Pasó creación e idempotencia, los CHECK rechazan valencia fuera de rango, contacto sin perspectiva y dos `daily` el mismo día, los 4 triggers de limpieza funcionan y la vista agrega bien.
> Diferencia con Supabase: `security_invoker` de la vista requiere Postgres 15 o superior, que es lo que usa Supabase. En la prueba local (PG14) se omitió.

---

## 3. Arquitectura Flutter: archivos nuevos

Todo va dentro de `quebrado-app-flutter/lib/diario/`, siguiendo el patrón de `notas/` (singleton de servicio, `ChangeNotifier`, actualización optimista).

| Archivo | Responsabilidad |
|---|---|
| `models/mood_log.dart` | Clase `MoodLog` con `fromMap`/`toSupabaseMap`/`copyWith`, enums `MoodKind`, `MoodPerspective`, `MoodSource` y getters `isSelf`, `valenceMeta` |
| `models/mood_tag.dart` | `MoodTag` + `MoodTag.defaultTags()` (el mismo set que el SQL, como respaldo offline, igual que `NoteCategory.defaultCategories()`) |
| `models/mood_catalog.dart` | Constantes: `MoodValenceMeta` (emoji, label, color), `MoodEmotion` (key, label, cuadrante), `MoodQuadrant`, helpers `emotionsFor(valence, energy)` |
| `services/animo_supabase_service.dart` | `getLogs({since})`, `saveLog`, `deleteLog`, `getTags`, `saveTag`, `deleteTag`. Asigna `user_id` si hay sesión (igual que `NotasSupabaseService.saveNote`) |
| `viewmodels/animo_state.dart` | Estado, CRUD optimista, cola de pendientes, consultas y cálculos de insights (sección 6) |
| `widgets/mood_quick_bar.dart` | Barra de 5 emojis: 1 toque guarda y abre la hoja "Agregar detalle". Parámetro `contactId` opcional |
| `widgets/mood_checkin_sheet.dart` | Flujo completo en 3 pasos (sección 4.1). Usa `responsive_sheet_helper.dart` para móvil y desktop |
| `widgets/mood_emotion_picker.dart` | Grilla de emociones por cuadrante con chips de color |
| `widgets/mood_log_tile.dart` | Registro en el timeline: emoji, emociones, etiquetas, nota, hora y menú (editar / eliminar) |
| `widgets/mood_month_calendar.dart` | Calendario mensual coloreado por `day_valence` |
| `widgets/mood_year_pixels.dart` | Año en píxeles: 12 columnas × 31 filas |
| `widgets/mood_trend_chart.dart` | `fl_chart` (ya en `pubspec`): línea diaria + media móvil de 7 días, rango de 30/90/365 días |
| `widgets/mood_insights_cards.dart` | Tarjetas "Qué te sube / qué te baja" (etiquetas, hábitos, personas, roles) |
| `widgets/contact_mood_section.dart` | Sección para el detalle de contacto: último ánimo percibido, sparkline de 30 días y botón "¿Cómo viste a X?" |
| `screens/animo_dashboard_screen.dart` | Pantalla "Mi ánimo" (sección 4.3) |
| `dialogs/mood_tag_manager_dialog.dart` | Crear, editar, archivar y ordenar etiquetas (patrón de `notas/dialogs/category_manager_dialog.dart`) |
| `dialogs/mood_settings_dialog.dart` | Horarios de check-in, activar o desactivar recordatorios, energía visible sí/no |

### 3.1 `AnimoState`: API pública (esqueleto)
```dart
class AnimoState extends ChangeNotifier {
  // Datos
  List<MoodLog> get logs;                     // orden logged_at DESC
  List<MoodTag> get tags;                     // activas (no archivadas)
  bool get isLoading;

  // Carga (ventana inicial: 400 días, suficiente para la vista anual)
  Future<void> loadAll();

  // CRUD optimista
  Future<MoodLog> addLog({required int valence, String? contactId,
      MoodPerspective perspective = MoodPerspective.self, MoodKind kind = MoodKind.momentary,
      int? energy, List<String> emotions = const [], List<String> tagIds = const [],
      List<String> roleIds = const [], List<String> mentionedContactIds = const [],
      String? note, String? diarioEntryId, MoodSource source = MoodSource.manual,
      DateTime? loggedAt});
  Future<void> updateLog(MoodLog updated);
  Future<void> deleteLog(String id);
  void removeLogsForContact(String contactId); // solo en memoria (el trigger SQL borra en BD)

  // Consultas
  List<MoodLog> logsFor({String? contactId, DateTime? from, DateTime? to});
  List<MoodLog> todaySelfLogs();
  MoodLog? latestFor(String? contactId);
  MoodLog? logForEntry(String diarioEntryId);
  double? dayValence(DateTime date, {String? contactId});       // regla daily > promedio
  Map<String, double> dailySeries({String? contactId, required int days});
  int get selfLoggingStreak;                                    // días seguidos con ≥1 registro propio
  bool get hasSelfLogToday;

  // Insights (sección 6)
  List<MoodEmotionFrequency> topEmotions({int days = 30, String? contactId});
  List<MoodImpact> tagImpact({int days = 90});
  List<MoodImpact> peopleImpact({int days = 90});
  List<MoodImpact> roleImpact({int days = 90});
  List<MoodImpact> habitImpact(HabitosState habitos, {int days = 90}); // recibe el state, sin dependencia circular
  List<ContactMoodAlert> contactsNeedingAttention();
  SelfCareSignal? selfCareSignal();
  MoodWeekComparison weekComparison();

  // Etiquetas
  Future<MoodTag> addTag({required String name, String emoji, String groupKey});
  Future<void> updateTag(MoodTag tag);
  Future<void> archiveTag(String id);
}
```

### 3.2 Sincronización y respuesta inmediata
- **Optimista:** `addLog` inserta en memoria y llama a `notifyListeners()` **antes** de `await _service.saveLog()`. Diario hoy va directo a Supabase sin caché, así que esto es lo que hace que se sienta "de 2 toques".
- **Cola de pendientes:** si `saveLog` falla, el log se guarda en `DatabaseHelper.setSetting('animo_pending_logs', json)` (`quebrado/services/db_helper.dart:720-736`). Se reintenta al final de `loadAll()` y la próxima vez que un guardado salga bien. Los logs pendientes muestran un ícono de nube tachada en `mood_log_tile`.
- **Balance `daily`:** antes de insertar, `addLog(kind: daily)` busca en memoria un `daily` del mismo sujeto y día. Si existe, hace `updateLog`, porque el índice único de la BD lo rechazaría.
- **`log_date`:** se calcula en el cliente con `DateFormat('yyyy-MM-dd').format(loggedAt.toLocal())`. El trigger SQL es solo un respaldo (America/Caracas).

---

## 4. UX y flujos

### 4.1 Check-in propio (3 pasos, solo el 1 es obligatorio)
1. **"¿Cómo te sientes?"**: 5 emojis. Al tocar uno, **se guarda de inmediato** (`source: checkin` si viene de una notificación, si no `manual`) y aparece un snackbar "Guardado · Agregar detalle".
2. **Detalle (opcional):** un slider de energía y luego las emociones sugeridas (máximo 3).
3. **Contexto (opcional):**
   - Etiquetas agrupadas (Actividad, Social, Salud, Lugar, Finanzas, Clima) con buscador y "+ nueva".
   - Roles Covey como chips, leídos de `Provider.of<RemindersState>().roles`.
   - Nota con `MentionTextField` (`diario/widgets/mention_text_field.dart`), que extrae las `@personas` a `mentionedContactIds` con `DiarioState.extractMentionedContactIds`.
   - Botón de micrófono con `SpeechRecognitionService.instance` (ya existe).
   - Toggle "Es mi balance del día" (`kind: daily`).
4. Editar un registro reabre la misma hoja precargada. Eliminar pide confirmación y ofrece "Deshacer" en un snackbar.

### 4.2 Ánimo percibido de un contacto
- En el detalle de contacto: **"¿Cómo viste a {nombre}?"** Usa la misma barra de 5 emojis, más:
  - Toggle **Lo noté yo / Me lo contó** (`observed` / `told`).
  - Emociones, sin paso de energía (se puede activar en ajustes).
  - Nota.
  - Sin roles. Las etiquetas quedan opcionales y colapsadas.
- La interfaz siempre muestra el prefijo "Percibido" y un ícono de ojo 👁 o de burbuja 💬.

### 4.3 Pantalla "Mi ánimo" (`AnimoDashboardScreen`)
Móvil con scroll vertical; desktop en 2 columnas, como `habitos_metrics_screen`.
1. **Hoy:** barra rápida, timeline de los registros de hoy, racha de registro 🔥 y comparación con la semana pasada.
2. **Calendario:** mes navegable. Al tocar un día se ven sus registros.
3. **Tendencia:** gráfico de 30/90/365 días con media móvil de 7 días.
4. **Año en píxeles.**
5. **Emociones frecuentes:** barras por cuadrante, 30 días.
6. **Qué influye en tu ánimo:** 4 pestañas: Etiquetas · Hábitos · Personas · Roles. Muestra el top 3 de impactos positivos y negativos, con el tamaño de muestra ("basado en 18 días").
7. **Personas:** contactos con ánimo percibido reciente y alertas de "podría necesitar apoyo".
8. **AppBar:** ⚙️ (ajustes y horarios), 🏷️ (etiquetas), 📤 (exportar CSV).
- **Estado vacío:** ilustración + "Registra cómo te sientes durante 7 días para ver tus patrones", con un contador de 0/7.

### 4.4 Estados y bordes
- Sin Supabase (`isReady == false`): funciona en memoria más la cola local, y se muestra un banner "Sin conexión, se sincronizará".
- Contacto eliminado: `DiarioState.deleteContact` (`diario_state.dart:164`) debe llamar también `animoState.removeLogsForContact(id)`. Ver la sección 5.1.
- Registro con fecha pasada: hay un selector de fecha y hora en el paso 3 ("¿Fue en otro momento?"). No se permiten fechas futuras.
- Zona horaria: siempre local. Las pruebas cubren un registro a las 23:50.

---

## 5. Integraciones con archivos concretos

### 5.1 Diario (captura principal)
| Archivo | Cambio |
|---|---|
| `lib/main.dart:78-85` | Agregar `ChangeNotifierProvider<AnimoState>(create: (_) => AnimoState()..loadAll())` |
| `lib/diario/diario.dart` | Exportar los modelos, `animo_state.dart`, `animo_dashboard_screen.dart`, `mood_quick_bar.dart` y `contact_mood_section.dart` |
| `diario/widgets/personal_notes_view.dart:157` (`_buildHeaderBanner`) | Insertar `MoodQuickBar()` arriba de "Mis notas personales" (se ve en móvil y en desktop). Si `hasSelfLogToday`, mostrar el último registro de hoy + "Registrar otro" |
| `diario/screens/diario_home_screen.dart` | AppBar: acción "Mi ánimo" (`Icons.mood_rounded`) que abre `AnimoDashboardScreen`. En móvil, opcionalmente una 3.ª pestaña "Ánimo" (`TabController(length: 3)` en l.39). Recomiendo empezar con la acción en el AppBar y medir el uso |
| `diario_home_screen.dart:678` (`_buildContactCard`) | Punto de color / emoji del último ánimo percibido (≤14 días) y badge ⚠️ si el contacto está en `contactsNeedingAttention()` |
| `diario/screens/contact_detail_screen.dart:228` | Después de `_buildLinkedHabitsSection`, insertar `ContactMoodSection(contact: contact)` |
| `diario/screens/entry_editor_dialog.dart` | Chip opcional "¿Cómo te sentías?". Al guardar la entrada se crea o actualiza un `MoodLog` con `diarioEntryId` y `source: diario_entry`. En una entrada de contacto es ánimo percibido; en una personal es propio |
| `diario/dialogs/entry_reader_dialog.dart` y la tarjeta de entrada (`contact_detail_screen.dart:747`, `personal_notes_view.dart:307`) | Mostrar el emoji y las emociones si `animoState.logForEntry(entry.id) != null` |
| `diario/dialogs/quick_note_dialog.dart` | Misma barra opcional de 5 emojis debajo del texto |
| `diario/viewmodels/diario_state.dart:164` (`deleteContact`) | Sin cambios en BD (lo hace el trigger). La limpieza en memoria se llama desde la UI que confirma el borrado, o se inyecta un callback `onContactDeleted` para no acoplar los states |
| `diario/screens/diario_search_screen.dart` (fase 3) | Incluir las notas de ánimo en los resultados |

### 5.2 Hábitos (análisis)
| Archivo | Cambio |
|---|---|
| `habitos/screens/habitos_metrics_screen.dart` | Nueva tarjeta `_buildMoodCorrelationCard(context, state)`, ubicada después de `_buildWeekdayCard` (l.450). Lee `Provider.of<AnimoState>` y llama `animo.habitImpact(state)`. Ejemplos: `> meditar  → ánimo +0.9 (n=21)` y `> redes sociales [recaída] → ánimo -0.7`. Debe respetar el estilo de terminal de `habitos_terminal_theme.dart` |
| `habitos/screens/habitos_home_screen.dart` | Junto al selector de fecha, mostrar el ánimo del día seleccionado (`animo.dayValence(selectedDate)`), de solo lectura. Al tocarlo se abre el check-in con esa fecha |
| `habitos_metrics_screen.dart:75` (heatmap, fase 3) | Toggle "Superponer ánimo" que colorea el borde de cada celda según `day_valence` |
| **No** se crea un hábito "registrar ánimo" | El check-in tiene su propia racha en Ánimo, para no contaminar las métricas de hábitos |

### 5.3 Agenda Covey / Recordatorios
- **Roles como contexto:** el paso 3 del check-in lista `RemindersState.roles` (no archivados). Se guardan en `role_ids` como texto.
- **Insight de rol:** `roleImpact()` alimenta la pestaña "Roles" y el snapshot de Ortiz. Por ejemplo: "El rol *Profesional* aparece en el 70% de tus días 😕".
- **Acción sugerida:** en la tarjeta de rol con impacto negativo, un botón "Planear una Gran Roca para este rol" que abre el flujo de `proposeScheduleBigRock` o el planificador semanal.
- **Alerta de contacto:** en la tarjeta ⚠️ de `contactsNeedingAttention`, un botón "Recordarme llamarle" que crea un `ReminderModel` con `RemindersState.saveReminder` (título "Escribirle a {nombre}", mañana a las 10:00, cuadrante II).

### 5.4 Agente Ortiz
| Archivo | Cambio |
|---|---|
| `agente/services/suite_rag_service.dart:21-32` | Agregar `final AnimoState animoState;` al constructor |
| `agente/viewmodels/agente_state.dart:74` (`updateDependencies`) | Nuevo parámetro `required AnimoState animoState` |
| `screens/app_launcher_screen.dart:148-160` | `final animoState = Provider.of<AnimoState>(context);` y pasarlo a `updateDependencies` |
| `suite_rag_service.dart:35` (`generateLiveContextSnapshot`) | Nuevo bloque `- Ánimo (Diario):` con: registros de hoy + último emoji; promedio de 7 días vs la semana anterior; top 3 emociones de 7 días; racha de registro; contactos con alerta (solo nombres); `selfCareSignal` si aplica |
| `suite_rag_service.dart:128` (`getDeclaredTools`, SDK) **y** `:400` (`getToolsJson`, REST) | **Declarar en ambas listas** (la app usa las dos): `getMoodHistory(contactName?, days=14)`, `getMoodInsights(days=90)` y `proposeLogMood(valence, energy?, emotions[]?, note?, contactName?, perspective?, date?)` |
| `suite_rag_service.dart:~764` (dispatch `switch`) | `case 'getMoodHistory'` devuelve la serie diaria y los últimos 10 registros. `case 'getMoodInsights'` devuelve tags/hábitos/personas/roles impact. `case 'proposeLogMood'` genera un `ChatArtifactModel` con `action: 'log_mood'` (mismo patrón que `proposeCreateHabit`, l.1761). Resolver `contactName` con la misma búsqueda que usa `proposeCreateDiarioEntry` |
| `agente/widgets/action_proposal_card_view.dart:33-74` | Agregar `'log_mood'` a `_getActionColor` (`#F59E0B`), `_getActionIcon` (`Icons.mood_rounded`) y `_getActionModuleLabel` ('Ánimo · Diario') |
| `action_proposal_card_view.dart:~90-272` (ejecución) | `case 'log_mood':` → `Provider.of<AnimoState>(context, listen: false).addLog(..., source: MoodSource.agent)` |
| `searchSuiteData` (l.764) | Incluir coincidencias en `note` y en las etiquetas de emociones |
| Instrucciones del sistema | Agregar: "Si el usuario expresa cómo se siente, ofrece registrarlo con `proposeLogMood`. No diagnostiques. Si hay 5 o más días seguidos de ánimo ≤ -1 o menciones de autolesión, responde con empatía y sugiere hablar con alguien de confianza o con un profesional" |
| `test/agente_rag_test.dart` | Casos nuevos: el snapshot incluye el bloque de Ánimo; `proposeLogMood` genera el artefacto correcto |

### 5.5 Launcher, Action Hub y Command Center
- `screens/launcher_action_hub_view.dart`: si `!animo.hasSelfLogToday`, mostrar la tarjeta "¿Cómo te sientes hoy?" con `MoodQuickBar` embebida.
- `widgets/desktop_command_center_view.dart`: widget "Ánimo" con el emoji de hoy, una sparkline de 7 días y la racha.
- `screens/app_launcher_screen.dart`: agregar "Ánimo" como subtítulo o atajo del tile de Diario. **No** se crea un tile nuevo.

### 5.6 Recordatorios de check-in (notificaciones)
- `services/notification_manager.dart`: hoy solo agenda pagos recurrentes. Agregar:
  - `scheduleMoodCheckins(List<TimeOfDay> times)`: `zonedSchedule` diario con `matchDateTimeComponents: DateTimeComponents.time` e IDs reservados 9100-9109.
  - `cancelMoodCheckins()`.
- Configuración por dispositivo con `DatabaseHelper.setSetting('animo_checkin_times', '["13:00","21:00"]')`. Por defecto: desactivado. Se propone activarlo tras el 3.er registro manual.
- Payload `animo_checkin`: al tocar la notificación se abre `MoodCheckinSheet` con `source: checkin`.
- **Web:** existe `push_subscriptions` pero no hay edge function que envíe. Para web queda en fase 3 como mejora; en el MVP, el banner del Action Hub cumple esa función.

### 5.7 Exportar y privacidad
- Exportar CSV (`share_plus` ya está en `pubspec`): `fecha, hora, sujeto, perspectiva, valencia, energia, emociones, etiquetas, roles, nota`. Por defecto **solo los registros propios**; un checkbox aparte permite "Incluir ánimo percibido de contactos".
- El ánimo **no** se incluye en el compartir y exportar a PDF de Notas ni en otras funciones de compartir sin confirmación explícita.
- `BackupService` (Quebrado) no cubre los módulos Supabase, así que no se toca. La fuente de verdad es Supabase.

---

## 6. Algoritmos de insights (en `AnimoState`, puros y testeables)

- **Valor del día:** `dayValence(d)` es la valencia del `daily` si existe; si no, el promedio de `momentary` de ese día; si no hay registros, `null`.
- **Impacto de un factor X** (etiqueta, persona mencionada, rol) en una ventana de 90 días, sobre los días con valor:
  `Δ = media(valor | días con X) − media(valor | días sin X)`.
  - Se muestra solo si `n_con ≥ 4`, `n_sin ≥ 4` y `|Δ| ≥ 0.3`.
  - Se ordena por `|Δ|` y se muestra el tamaño de muestra.
  - El texto habla siempre de "suele coincidir con", nunca de "causa".
- **Impacto de un hábito:** los mismos días, con X = el hábito tiene `completed` ese día (`HabitosState.isCompleted(id, key)`, l.129).
  - Solo cuenta días en que el hábito existía (`createdAt ≤ d`) y no estaba archivado.
  - En los hábitos negativos, "con X" = días con recaída (`log != null && !log.completed`).
- **Emociones frecuentes:** conteo de claves en la ventana, agrupado por cuadrante.
- **Racha de registro:** días consecutivos hasta hoy (o ayer, si hoy aún no hay) con al menos un registro propio.
- **Comparación semanal:** promedio de los últimos 7 días frente a los 7 anteriores, con flecha ↑↓ si `|Δ| ≥ 0.3`.
- **`contactsNeedingAttention`:** contactos con 3 o más registros en 14 días y promedio ≤ -1, o con el último registro = -2 hace ≤ 3 días.
- **`selfCareSignal`:** 5 o más días seguidos con valor ≤ -1. Muestra una tarjeta cálida: "Llevas unos días difíciles. ¿Quieres escribir sobre ello o hablar con alguien de confianza?". Ofrece abrir una nota personal o proponer un recordatorio para contactar a alguien. **No diagnostica.**

---

## 7. Fases y tareas

### Fase 1: MVP (registro + visualización básica)
- [x] **SQL:** correr `013_animo_schema.sql` en Supabase web y verificar (sección 2).
- [x] Crear `mood_catalog.dart`, `mood_log.dart`, `mood_tag.dart` + `fromMap`/`toSupabaseMap`.
- [x] Crear `animo_supabase_service.dart`.
- [x] Crear `animo_state.dart` con CRUD optimista, cola de pendientes y consultas básicas (`logsFor`, `dayValence`, `dailySeries`, `selfLoggingStreak`, `hasSelfLogToday`).
- [x] Registrar el provider en `main.dart` y los exports en `diario.dart`.
- [x] `MoodQuickBar` + `MoodCheckinSheet` + `MoodEmotionPicker` (incluidos etiquetas, roles, `@menciones`, dictado de voz y fecha pasada).
- [x] Integrar la barra en `personal_notes_view.dart` y la acción "Mi ánimo" en `diario_home_screen.dart`.
- [x] `ContactMoodSection` en `contact_detail_screen.dart` + punto de color en `_buildContactCard`.
- [x] `AnimoDashboardScreen` con Hoy + Calendario + Tendencia + Emociones frecuentes (+ día seleccionado y registros recientes; también sirve para el historial de un contacto).
- [x] `MoodLogTile` con editar, eliminar y deshacer.
- [x] Limpieza en memoria al borrar un contacto.
- [x] Tests: `test/animo_state_test.dart` (sección 8).

**Criterios de aceptación:**
- Registrar el ánimo propio con 1 toque se refleja en menos de 100 ms, sin esperar a la red.
- Registrar el ánimo percibido de un contacto aparece en su detalle y en la tarjeta del directorio.
- Editar y eliminar funcionan; con la red caída, el registro queda pendiente y se sincroniza al volver.
- Un segundo balance `daily` el mismo día actualiza el existente, sin error.
- El calendario y la tendencia coinciden con `mood_daily_summary` en Supabase.

### Fase 2: Integraciones e insights
- [ ] Insights: `tagImpact`, `peopleImpact`, `roleImpact`, `habitImpact`, `weekComparison`, `contactsNeedingAttention`, `selfCareSignal`.
- [ ] `MoodInsightsCards` (4 pestañas) + la sección Personas en el dashboard.
- [ ] Tarjeta de correlación en `habitos_metrics_screen.dart` y chip de ánimo en `habitos_home_screen.dart`.
- [ ] Agente Ortiz: dependencia, snapshot, 3 herramientas en **las dos listas**, dispatch, tarjeta `log_mood` y prompt de cuidado. Actualizar `agente_rag_test.dart`.
- [ ] Mood opcional en `entry_editor_dialog.dart` y `quick_note_dialog.dart` + visualización en el lector y las tarjetas.
- [ ] Acciones desde los insights: "Recordarme llamarle" (Recordatorios) y "Planear Gran Roca" (Covey).
- [ ] `MoodTagManagerDialog`.

**Criterios de aceptación:**
- Con 30 días de datos de prueba, los impactos coinciden con el cálculo manual (test).
- Ortiz responde "¿cómo he estado esta semana?" usando `getMoodHistory`.
- "Hoy me siento agotado por el trabajo" genera la tarjeta de confirmación y, al confirmar, el registro aparece en Diario.

### Fase 3: Hábito de registrar y pulido
- [ ] Notificaciones de check-in (`NotificationManager` + `MoodSettingsDialog`) y apertura desde la notificación.
- [ ] Año en píxeles, superposición de ánimo en el heatmap de Hábitos y widget en el Command Center y el Action Hub.
- [ ] Exportar CSV con el filtro de privacidad.
- [ ] Notas de ánimo en `diario_search_screen.dart` y `searchSuiteData`.
- [ ] Resumen semanal por Ortiz (prompt rápido "Revisión emocional de la semana" en `009_chat_prompts`).
- [ ] (Opcional) Push web vía edge function + `push_subscriptions`.

### Documentación (en cada fase)
- [x] `DATABASE_MODELS.md`: nueva sección "Ánimo" con ERD (`mood_logs` → `diario_contacts` / `diario_entries` / `roles` / `mood_tags`), modelos y regla del valor del día.
- [ ] Actualizar este archivo marcando las casillas.

---

## 8. Pruebas

**Unitarias (`test/animo_state_test.dart`),** con un servicio falso inyectable (`AnimoState({AnimoSupabaseService? service})`, igual que `NotasState`):
- `dayValence`: un `daily` manda sobre los momentáneos; promedio sin `daily`; `null` sin datos.
- Un registro a las 23:50 hora local cae en el día correcto.
- Racha: con registro hoy, sin registro hoy (cuenta hasta ayer) y con un hueco.
- `tagImpact`: un dataset sintético con Δ conocido; el umbral de n < 4 lo excluye.
- `habitImpact`: un hábito negativo invierte la semántica; se ignoran los días anteriores a su creación.
- `contactsNeedingAttention` y `selfCareSignal` justo en el límite de los umbrales.
- Optimista: si `saveLog` lanza un error, el log sigue en memoria y en la cola de pendientes; el reintento lo limpia.
- Un segundo `daily` el mismo día actualiza el existente, no duplica.

**Widget:**
- `MoodQuickBar`: 1 toque llama `addLog` con la valencia correcta.
- `MoodCheckinSheet`: máximo 3 emociones y fecha futura bloqueada.
- `ContactMoodSection`: muestra el prefijo "Percibido".

**Agente:** el snapshot contiene el bloque Ánimo; el dispatch de `proposeLogMood` resuelve el contacto por nombre.

**QA manual:**
- Web (Chrome), macOS y móvil.
- Con Supabase apagado y encendido.
- Borrar un contacto con registros: desaparecen en la UI y en la BD (trigger).
- Borrar un rol Covey: desaparece de `role_ids`.
- Borrar una entrada de Diario con ánimo: el ánimo se conserva y queda desvinculado.

---

## 9. Riesgos y decisiones abiertas
- **Carga inicial:** 400 días × varios registros por día es poco (menos de 3.000 filas). Si crece, paginar con `since` y usar `mood_daily_summary` para las vistas anuales.
- **RLS permisiva** (`auth.uid() IS NULL` permitido): es consistente con el resto de la suite, pero el ánimo es un dato sensible. Si más adelante se activa auth estricta, endurecer las políticas de `mood_logs` primero.
- **Catálogo fijo vs emociones personalizadas:** el MVP usa un catálogo fijo para que las estadísticas sean consistentes. Se puede evaluar permitir emociones personalizadas en la fase 3.
- **3.ª pestaña en móvil:** decidir después de 2 semanas de uso si se sube de la acción en el AppBar a una pestaña.
