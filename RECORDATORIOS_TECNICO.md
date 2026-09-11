# Documentación Técnica: Recordatorios (Reminders App)
**Suite de Productividad OrtizApp**

---

## 1. Visión General y Filosofía de Diseño

**Recordatorios** es un módulo de gestión de tareas y recordatorios de alto rendimiento, diseñado bajo una filosofía **keyboard-first** (prioridad al teclado), con captura ultrarrápida mediante Procesamiento de Lenguaje Natural (NLP), reprogramación inteligente (*Smart Snooze*), alertas persistentes (*Nagging*), recurrencia automática según el estándar RFC 5545 y sincronización reactiva en tiempo real respaldada por **Supabase Realtime**.

### Principios Fundamentales
1. **Fricción Cero en Captura:** Capacidad de registrar cualquier tarea en menos de un segundo escribiendo frases en lenguaje cotidiano en español (ej. `"Pagar tarjeta mañana a las 3pm !urgente #finanzas"`).
2. **Productividad Orientada al Teclado:** Acceso universal a una paleta de comandos global mediante `Cmd+K` (macOS) o `Ctrl+K` (Windows/Linux/Web), permitiendo crear, buscar, filtrar y posponer tareas sin tocar el ratón.
3. **Recurrencia Automática Robusta:** Soporte nativo para tareas repetitivas semanales, quincenales, mensuales y diarias. Al marcar como completada una tarea recurrente, el motor crea y programa de forma autónoma la siguiente ocurrencia.
4. **Sincronización Reactiva:** Suscripción por WebSockets a `supabase_realtime`, garantizando coherencia multi-pestaña y multi-dispositivo instantánea con actualizaciones optimistas en la UI.
5. **Estética Minimalista Unificada:** Identidad visual integrada en la suite OrtizApp con paleta sobria basada en **Slate Indigo** (`#2E5B88`).

---

## 2. Arquitectura del Sistema

El módulo reside en `lib/recordatorios/` dentro de `quebrado-app-flutter` y sigue un patrón de arquitectura **MVVM (Model - View - ViewModel)** desacoplado:

```
lib/recordatorios/
├── dialogs/
│   ├── command_palette_dialog.dart   # Paleta de comandos global (Cmd/Ctrl + K)
│   └── reminder_editor_dialog.dart   # Diálogo modal detallado de edición y creación
├── models/
│   └── reminder_model.dart           # Modelo de dominio, enums (prioridad, estado, recurrencia)
├── screens/
│   └── reminders_home_screen.dart    # Pantalla principal con feed agrupado y captura rápida
├── services/
│   ├── nlp_parser.dart               # Motor léxico y sintáctico de lenguaje natural en español
│   └── reminders_supabase_service.dart # Servicio de persistencia y Supabase Realtime
├── theme/
│   └── reminders_colors.dart         # Tokens de diseño y colores semánticos
├── viewmodels/
│   └── reminders_state.dart          # Gestor de estado reactivo (ChangeNotifier)
└── recordatorios.dart                # Barril de exportación pública del módulo
```

---

## 3. Modelo de Datos y Enums

### 3.1 `ReminderPriority`
Define la criticidad de la tarea:
| Enum Dart | Código DB | Etiqueta | Color UI | Sintaxis NLP |
| :--- | :--- | :--- | :--- | :--- |
| `p1Urgent` | `'p1_urgent'` | P1 Urgente | `#EF4444` (Rojo) | `!p1`, `!urgente`, `!urgent` |
| `p2High` | `'p2_high'` | P2 Alta | `#F97316` (Naranja) | `!p2`, `!alta`, `!high` |
| `p3Medium` | `'p3_medium'` | P3 Media | `#3B82F6` (Azul) | `!p3`, `!media`, `!medium` (Predeterminado) |
| `p4Low` | `'p4_low'` | P4 Baja | `#94A3B8` (Gris) | `!p4`, `!baja`, `!low` |

### 3.2 `ReminderStatus`
Ciclo de vida del recordatorio:
- `pending`: Tarea activa pendiente por vencer o realizar.
- `completed`: Tarea resuelta (conserva `completedAt`).
- `snoozed`: Pospuesta temporalmente.
- `archived`: Descartada o archivada fuera de las vistas principales.

### 3.3 `ReminderRecurrence`
Mapeo estándar iCalendar RFC 5545:
| Enum Dart | Cadena `rrule` | Etiqueta | Cálculo de Siguiente Ocurrencia |
| :--- | :--- | :--- | :--- |
| `none` | `null` | No se repite | Misma fecha |
| `daily` | `'FREQ=DAILY'` | Diario | `baseDate + 1 día` |
| `weekly` | `'FREQ=WEEKLY'` | Semanal | `baseDate + 7 días` |
| `biweekly`| `'FREQ=WEEKLY;INTERVAL=2'`| Quincenal (cada 15 días) | `baseDate + 14 días` |
| `monthly` | `'FREQ=MONTHLY'` | Mensual | `baseDate + 1 mes` (con ajuste de fin de mes) |
| `yearly` | `'FREQ=YEARLY'` | Anual | `baseDate + 1 año` |

### 3.4 `ReminderModel`
Estructura completa de la entidad:
```dart
class ReminderModel {
  final String id;                    // UUID
  final String? userId;               // UUID del usuario autenticado
  final String title;                 // Título limpio de modificadores NLP
  final String? notes;                // Notas secundarias
  final ReminderPriority priority;    // Prioridad (p1 a p4)
  final ReminderStatus status;        // Estado (pending, completed, snoozed, archived)
  final DateTime? dueAt;              // Vencimiento en UTC
  final String clientTimezone;        // Zona horaria de origen (ej. 'America/Caracas')
  final String? rrule;                // Regla de recurrencia RFC 5545
  final String? parentId;             // Enlace a la tarea padre si proviene de recurrencia
  final bool isNagging;               // Alerta persistente activada
  final int nagIntervalMinutes;       // Intervalo de re-notificación
  final DateTime? lastNotifiedAt;     // Última alerta despachada
  final List<String> tags;            // Etiquetas ('finanzas', 'hogar', etc.)
  final DateTime? completedAt;        // Fecha de resolución
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

---

## 4. Motor de Procesamiento de Lenguaje Natural (`NlpParser`)

El servicio [`NlpParser`](file:///Users/jottache/development/quebrado-app/quebrado-app-flutter/lib/recordatorios/services/nlp_parser.dart) analiza texto en español en tiempo real y extrae parámetros estructurados sin librerías externas pesadas.

### 4.1 Fases del Pipeline
1. **Extracción de Etiquetas:** Detecta `#etiqueta` mediante `RegExp(r'#([a-zA-Z0-9_\u00C0-\u00FF]+)')`.
2. **Extracción de Prioridades:** Detecta `!(p1|p2|p3|p4|urgente|alta|media|baja)`.
3. **Extracción de Recurrencia:** Detecta expresiones como `quincenal`, `cada 15 días`, `semanal`, `cada semana`, `mensual`, `cada mes`, `diario`, o tags `#semanal`, `#quincenal`, etc.
4. **Extracción de Duraciones Relativas:** Detecta patrones de anticipación inmediata: `en X minutos`, `en X horas`, `en X días`.
5. **Extracción de Fechas Calendario:**
   - Expresiones relativas: `hoy`, `mañana`, `pasado mañana`, `el lunes`, `el viernes`.
   - Días del mes: `15 de octubre`, `el 24 de dic`.
6. **Extracción de Horas y Momentos del Día:**
   - Horas estándar: `a las 3pm`, `15:30`, `8:00 am`.
   - Bloques contextuales: `en la mañana` (09:00), `a mediodía` (12:00), `en la tarde` (15:00), `esta noche` (20:00).
7. **Limpieza del Título:** Remueve todos los tokens identificados y preserva el nombre legible de la tarea.

---

## 5. Gestión del Estado (`RemindersState`)

Implementado con `ChangeNotifier` para garantizar rendimiento óptimo y reactividad:

### 5.1 Vistas Filtradas Computadas
- `overdueReminders`: Tareas no completadas cuya fecha límite es anterior a `DateTime.now()`.
- `todayReminders`: Tareas programadas para el día calendario actual.
- `upcomingReminders`: Tareas futuras a partir de mañana.
- `noDueDateReminders`: Tareas sin fecha asignada (bandeja de entrada).
- `completedReminders`: Historial de tareas completadas ordenadas por `completedAt DESC`.

### 5.2 Acciones de Negocio
- **`createFromNlp(String rawInput)`:** Analiza el texto con `NlpParser` y almacena el recordatorio de forma optimista en la lista local antes de sincronizar con Supabase.
- **`toggleCompleted(ReminderModel reminder)`:**
  - Si no estaba completada, la marca como `completed` con `completedAt = DateTime.now()`.
  - **Reprogramación Recurrente:** Si `reminder.isRecurring == true`, calcula automáticamente la siguiente fecha límite (`recurrence.calculateNextDueDate(baseDate)`) y registra una nueva tarea pendiente vinculada mediante `parentId = reminder.id`.
- **`quickSnooze(ReminderModel reminder, Duration duration)`:** Aplaza el vencimiento sumando la duración a partir del momento actual o de la fecha original.
- **`snoozeAllOverdueToTomorrow()`:** Acción masiva en lote para mover todas las tareas atrasadas a mañana a las 9:00 AM.

---

## 6. Componentes de Interfaz de Usuario

### 6.1 `RemindersHomeScreen`
- **Barra Superior:** Búsqueda rápida, selector de filtros por etiqueta y botón de acceso a la paleta de comandos.
- **Barra de Captura Rápida:** Campo de texto inline con botón de envío y visualización en tiempo real de los chips extraídos (fecha, prioridad, recurrencia, tags).
- **Banner de Vencidos:** Alerta prominente en rojo que se muestra si hay tareas atrasadas, con acceso directo a posponerlas todas a mañana.
- **Feed Seccionado:** Listas colapsables con tarjetas que incluyen:
  - Checkbox interactivo de completitud.
  - Indicador de prioridad mediante barra de color lateral y badge textual.
  - Insignia de recurrencia (`🔁 Semanal`, `🔁 Quincenal`, `🔁 Mensual`).
  - Insignia de alerta persistente (*Nagging*).
  - Menú de Smart Snooze rápido (+15m, +1h, +3h, esta noche, mañana).
  - Menú contextual para editar o eliminar.

### 6.2 `CommandPaletteDialog` (`Cmd/Ctrl + K`)
- Cuadro de diálogo modal estilo *Spotlight*.
- Permite escribir y crear al vuelo con `Enter`.
- Si el texto coincide con recordatorios existentes, los muestra en una lista de resultados con opciones directas de completar o posponer.
- Incluye accesos directos a filtros frecuentes y posposición masiva.

### 6.3 `ReminderEditorDialog`
- Modal para creación o edición detallada con:
  - Título y notas.
  - Selector visual de prioridad (4 niveles con colores semánticos).
  - Selector de fecha y hora interactivo.
  - Selector de frecuencia de recurrencia mediante `ChoiceChips`.
  - Switch de alertas persistentes (*Nagging*) con slider de minutos.
  - Campo de gestión de tags.

---

## 7. Esquema de Base de Datos (Supabase PostgreSQL)

El archivo [`supabase/006_reminders_schema.sql`](file:///Users/jottache/development/quebrado-app/supabase/006_reminders_schema.sql) define el almacenamiento y la seguridad:

```sql
-- Enums
CREATE TYPE reminder_priority AS ENUM ('p1_urgent', 'p2_high', 'p3_medium', 'p4_low');
CREATE TYPE reminder_status AS ENUM ('pending', 'completed', 'snoozed', 'archived');

-- Tabla de Suscripciones Web Push
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla Principal de Recordatorios
CREATE TABLE IF NOT EXISTS public.reminders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  notes TEXT,
  priority reminder_priority DEFAULT 'p3_medium',
  status reminder_status DEFAULT 'pending',
  due_at TIMESTAMPTZ,
  client_timezone TEXT DEFAULT 'UTC',
  rrule TEXT,
  parent_id UUID REFERENCES public.reminders(id) ON DELETE SET NULL,
  is_nagging BOOLEAN DEFAULT FALSE,
  nag_interval_minutes INTEGER DEFAULT 10,
  last_notified_at TIMESTAMPTZ,
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices de Alto Rendimiento
CREATE INDEX IF NOT EXISTS idx_reminders_user_status ON public.reminders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_reminders_due ON public.reminders(due_at) WHERE status IN ('pending', 'snoozed');
CREATE INDEX IF NOT EXISTS idx_push_user ON public.push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_created ON public.reminders(created_at DESC);

-- Políticas de Seguridad (RLS)
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acceso completo a reminders" ON public.reminders
  FOR ALL USING (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL OR auth.uid() IS NULL);

-- Supabase Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.reminders;
```

---

## 8. Calidad, Pruebas y Validación

### 8.1 Pruebas Unitarias (`test/reminders_nlp_test.dart`)
Se cuenta con una suite automatizada de 12 pruebas unitarias que validan:
1. Extracción léxica de prioridad (`!p1`) y etiquetas múltiples (`#finanzas #banco`).
2. Fechas relativas en lenguaje coloquial (*"mañana a las 3pm"*).
3. Offset de tiempo relativo (*"en 30 minutos"*).
4. Momentos del día (*"esta noche"* $\rightarrow$ 20:00).
5. Serialización bidireccional `toMap()` / `fromMap()`.
6. Detección precisa de vencimiento con `isOverdue`.
7. Mapeo y persistencia de reglas RFC 5545 (`weekly`, `biweekly`, `monthly`).
8. Algoritmo de cálculo de siguiente ocurrencia con ajuste de fin de mes.
9. Extracción NLP de recurrencia semanal (*"Reunión de sprint semanal"*).
10. Extracción NLP de recurrencia quincenal (*"Pago nómina quincenal"*, *"cada 15 días"*).
11. Extracción NLP de recurrencia mensual (*"Pagar suscripción mensual"*, *"cada mes"*).
12. Detección alternativa mediante tags de recurrencia (`#semanal`, `#quincenal`).

### 8.2 Comandos de Verificación
```bash
# Ejecución de pruebas unitarias
flutter test test/reminders_nlp_test.dart

# Análisis estático y linter
flutter analyze lib
```
Resultado actual: **0 errores, 0 warnings (clean analysis)**.
