# Documentación Técnica: Recordatorios y Agenda Semanal (4ta Generación - Hábito 3 de Stephen Covey)
**Suite de Productividad OrtizApp**

---

## 1. Visión General y Filosofía de Diseño

El módulo **Recordatorios & Agenda** es un sistema de gestión personal de alto rendimiento que combina una arquitectura **keyboard-first** (prioridad al teclado) y captura ultrarrápida mediante Procesamiento de Lenguaje Natural (NLP), con la filosofía de **4ta Generación de Gestión del Tiempo (Hábito 3: «Primero lo Primero» / «Put First Things First» de Stephen R. Covey)**.

### Principios Fundamentales
1. **La Brújula precede al Reloj:** Priorizar la dirección, el propósito y el equilibrio de vida antes que la velocidad. La gestión se basa en **Roles Vitales** y sus enunciados de misión.
2. **Las 4 Dimensiones Humanas:** Cobertura equilibrada de las dimensiones Física, Mental, Espiritual y Social/Emocional, con alerta activa de desbalance si algún rol tiene 0 Grandes Rocas.
3. **Grandes Rocas Primero (Cuadrante II):** Identificar de 1 a 3 prioridades no negociables de alta efectividad (C2: Importante, No Urgente) por rol y bloquear su espacio en la semana antes de que la arena y la grava cotidiana ocupen el tiempo.
4. **Marco Semanal Flexible:** Grilla de 7 días (Lunes a Domingo) con reprogramación interactiva mediante **Drag & Drop** y bandeja de tareas semanales sin asignar.
5. **Captura Fricción Cero:** Creación instantánea de tareas enriquecidas con cuadrante (`!c1..c4`), Gran Roca (`*rock*`), rol (`@rol`), duración (`~30m`) y fecha natural en una sola línea.
6. **Coaching Inteligente con Agente Ortiz:** Supervisión continua del balance de roles, auditoría del cronograma semanal y propuesta interactiva de agendamiento en 1 toque mediante Action Proposals.
7. **Sincronización Reactiva:** Respaldado por **Supabase Realtime** y persistencia offline con mutaciones optimistas en la UI.

---

## 2. Arquitectura del Sistema

El módulo reside en `lib/recordatorios/` dentro de `quebrado-app-flutter` bajo una arquitectura **MVVM (Model - View - ViewModel)**:

```
lib/recordatorios/
├── dialogs/
│   ├── command_palette_dialog.dart       # Paleta global (Cmd/Ctrl + K)
│   ├── covey_guide_dialog.dart           # Modal interactivo con guía paso a paso (6 pasos)
│   ├── reminder_editor_dialog.dart       # Modal detallado con selectores de Covey
│   ├── role_manager_dialog.dart          # Gestor de Roles Vitales, colores, iconos y misión
│   └── sunday_planning_wizard_dialog.dart # Asistente de 3 pasos para el Ritual Dominical
├── models/
│   ├── covey_quadrant.dart               # Enum C1..C4, etiquetas, colores y helpers
│   ├── reminder_model.dart               # Entidad principal con campos de Hábito 3
│   ├── role_model.dart                   # Modelo de Rol Vital y semillas de 4 dimensiones
│   └── weekly_plan_model.dart            # Plan semanal normalizado a lunes
├── screens/
│   └── reminders_home_screen.dart        # Vista principal con selector de vistas y banner fijado
├── services/
│   ├── nlp_parser.dart                   # Motor léxico de lenguaje natural y tokens Covey
│   └── reminders_supabase_service.dart   # Servicio de persistencia y Supabase Realtime
├── theme/
│   └── reminders_colors.dart             # Tokens de diseño y colores semánticos
├── viewmodels/
│   └── reminders_state.dart              # Gestor de estado reactivo (ChangeNotifier)
└── widgets/
    ├── covey_matrix_view.dart            # Vista Matriz 2x2 interactiva (Drag & Drop + foco C2)
    └── weekly_schedule_view.dart         # Vista 7 días + Sidebar de Brújula + Drawer inferior
```

---

## 3. Modelo de Datos y Enums

### 3.1 `CoveyQuadrant`
Define los cuadrantes de la matriz de Stephen Covey:
| Enum Dart | Código DB | Etiqueta | Naturaleza | Color UI | Sintaxis NLP |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `q1UrgentImportant` | `'q1_urgent_important'` | C1 Crisis | Urgente & Importante | `#EF4444` (Rojo) | `!c1`, `!q1` |
| `q2ImportantNotUrgent`| `'q2_important_not_urgent'`| C2 Eficacia ★ | Importante, NO Urgente | `#059669` (Esmeralda) | `!c2`, `!q2` (Default) |
| `q3UrgentNotImportant`| `'q3_urgent_not_important'`| C3 Engaño | Urgente, NO Importante | `#F59E0B` (Ámbar) | `!c3`, `!q3` |
| `q4NotUrgentNotImportant`| `'q4_not_urgent_not_important'`| C4 Desperdicio| Ni Urgente ni Importante | `#64748B` (Gris Pizarra)| `!c4`, `!q4` |

### 3.2 `RoleModel` (Tabla: `user_life_roles`)
Representa cada una de las facetas fundamentales de responsabilidad del usuario:
- `id` (`String` / `UUID PRIMARY KEY`): Identificador único.
- `userId` (`String?` / `UUID REFERENCES auth.users(id)`).
- `name` (`String`): Nombre del rol (ej. *"Salud & Vitalidad"*, *"Familia & Pareja"*).
- `purposeStatement` (`String?`): Declaración de misión o propósito de vida para este rol.
- `iconName` (`String`): Identificador del icono Material (ej. `'fitness_center'`, `'favorite'`).
- `colorHex` (`String`): Color distintivo en formato hexadecimal (ej. `'#10B981'`).
- `orderIndex` (`int`): Posición ordinal de visualización.

### 3.3 `WeeklyPlanModel` (Tabla: `weekly_plans`)
Controla el ciclo de planificación semanal:
- `id` (`String` / `UUID PRIMARY KEY`).
- `userId` (`String?` / `UUID REFERENCES auth.users(id)`).
- `weekStartDate` (`DateTime`): Fecha normalizada al **Lunes** de la semana.
- `retrospectiveNotes` (`String?`): Reflexión de logros, lecciones y dificultades.
- `prioritiesNotes` (`String?`): Compromisos prioritarios de la semana.
- `formattedRange`: Helper que retorna el rango legible (ej. *"21 Sep - 27 Sep 2026"*).

### 3.4 `ReminderModel` (Tabla: `reminders`)
Entidad extendida con compatibilidad total:
```dart
class ReminderModel {
  final String id;
  final String? userId;
  final String title;
  final String? notes;
  final ReminderPriority priority;
  final ReminderStatus status;
  final DateTime? dueAt;
  final String clientTimezone;
  final String? rrule;
  final String? parentId;
  final bool isNagging;
  final int nagIntervalMinutes;
  final DateTime? lastNotifiedAt;
  final List<String> tags;
  final bool isPinned;
  final DateTime? completedAt;

  // Extensiones Hábito 3 de Stephen Covey
  final String? roleId;                     // Vinculación a Rol Vital
  final String? weeklyPlanId;               // Enlace al Plan Semanal
  final CoveyQuadrant quadrant;             // C1, C2, C3, C4 (Default: C2)
  final bool isBigRock;                     // Gran Roca semanal no negociable
  final int? scheduledDayOfWeek;            // 0=Lun .. 6=Dom, null=Bandeja sin asignar
  final int? estimatedDurationMinutes;      // Duración estimada (ej. 30, 45, 60 min)
}
```

---

## 4. Motor de Procesamiento de Lenguaje Natural (`NlpParser`)

El servicio [`NlpParser`](file:///Users/jottache/development/quebrado-app/quebrado-app-flutter/lib/recordatorios/services/nlp_parser.dart) extrae parámetros tanto tradicionales como de 4ta generación:

### 4.1 Fases del Pipeline
1. **Tokens Covey de Cuadrante:** `!(c1|c2|c3|c4|q1|q2|q3|q4)` $\rightarrow$ Asigna el cuadrante `CoveyQuadrant`.
2. **Tokens de Gran Roca:** `\*rock\*`, `!rock`, `!piedra`, `!granroca` $\rightarrow$ Marca `isBigRock = true`.
3. **Tokens de Rol Vital:** `@([a-zA-Z0-9_\u00C0-\u00FF]+)` $\rightarrow$ Extrae el nombre del rol a vincular.
4. **Tokens de Duración:** `~([0-9]+(?:\.[0-9]+)?)(m|h)` $\rightarrow$ Convierte a minutos (`~45m` $\rightarrow$ 45, `~1h` $\rightarrow$ 60).
5. **Etiquetas y Prioridades Clásicas:** `#tag`, `!urgente`, `!p1`, `!p2`, `!p3`, `!p4`.
6. **Recurrencia RFC 5545:** `diario`, `semanal`, `quincenal`, `mensual`, `cada 15 días`.
7. **Fechas Relativas y Horas:** `mañana a las 8am`, `el viernes a las 3pm`, `en 30 minutos`, `esta noche`.
8. **Limpieza del Título:** Retira todos los modificadores y conserva el texto limpio.

**Ejemplo completo:**
```text
Entrenar pesas y movilidad *rock* !c2 @Salud ~1h mañana a las 7am
```
- Título: *"Entrenar pesas y movilidad"*
- Cuadrante: `q2ImportantNotUrgent`
- Gran Roca: `true`
- Rol: *"Salud"*
- Duración: 60 minutos
- Fecha límite: Mañana a las 07:00

---

## 5. Gestión del Estado (`RemindersState`)

El ViewModel reactivo provee los siguientes cálculos y mutaciones:

### 5.1 Getters Computados de 4ta Generación
- `remindersForDay(int dayOfWeek)`: Recordatorios agendados para un día específico (0=Lunes .. 6=Domingo).
- `unscheduledWeeklyReminders`: Tareas asignadas a la semana pero sin día fijo (bandeja semanal).
- `bigRocksForRole(String roleId)`: Lista de Grandes Rocas asociadas a un rol en la semana activa.
- `unaddressedRoles`: Lista de roles vitales activos que tienen **0 Grandes Rocas** programadas.
- `remindersForQuadrant(CoveyQuadrant q)`: Tareas activas clasificadas en dicho cuadrante.
- `q2FocusPercentage`: Porcentaje de tareas en Cuadrante II sobre el total activo.

### 5.2 Mutaciones Optimistas
- **`moveReminderToDay(String reminderId, int? dayOfWeek)`:** Asigna o mueve una tarea a un día de la semana (o a la bandeja si `dayOfWeek == null`).
- **`moveReminderToQuadrant(String reminderId, CoveyQuadrant quadrant)`:** Reubica una tarea entre cuadrantes.
- **`toggleBigRock(String reminderId)`:** Alterna la marca de Gran Roca.
- **`saveRole(RoleModel role)` / `deleteRole(String roleId)`:** Gestión completa de roles vitales.
- **`saveWeeklyPlanNotes({String? retrospective, String? priorities})`:** Actualiza las notas del ritual dominical.

---

## 6. Vistas y Componentes de Interfaz de Usuario

### 6.1 `WeeklyScheduleView` (Agenda Semanal)
- **Barra Lateral de Brújula:** Roles vitales con misión, contador de rocas y alerta de desbalance. Incluye botón al Ritual Dominical y a la Guía Paso a Paso.
- **Grilla de 7 Días (Lunes a Domingo):** Columnas con encabezado de fecha, indicador de día actual y drop-targets.
- **Drag & Drop:** Implementación con `Draggable` y `DragTarget` para reprogramar tareas entre días con feedback táctil y visual.
- **Bandeja Semanal Sin Asignar:** Drawer deslizable inferior para tareas capturadas pendientes de día.

### 6.2 `CoveyMatrixView` (Matriz 2x2)
- Disposición de 4 cuadrantes con foco y borde destacado en **Cuadrante II**.
- Barra superior con porcentaje de enfoque en C2 y felicitación al superar el **60%**.
- Drag & Drop interactivo para mover tareas entre cuadrantes.

### 6.3 `SundayPlanningWizardDialog` (El Ritual Dominical)
- Flujo en 3 pasos:
  1. *Retrospectiva:* Evaluación de la semana y conexión con la misión.
  2. *Grandes Rocas:* Selección de 1 a 3 prioridades no negociables por rol.
  3. *Agendamiento:* Asignación a días de la semana y reserva de bloques de tiempo.

### 6.4 `RoleManagerDialog` (Gestor de Roles Vitales)
- Diálogo modal para crear, editar, reordenar y eliminar roles vitales con selector de iconos y colores.

### 6.5 `CoveyGuideDialog` (Modal de Guía Paso a Paso)
- Modal grande de 6 pasos pedagógicos que explica la filosofía y el uso de cada feature. Accesible desde la barra superior (`¿Cómo organizarme?`), el AppBar (`?`) y la barra lateral.

---

## 7. Integración con el Agente Ortiz (Coaching y Herramientas)

El chatbot asistente inteligente (**Agente Ortiz**) actúa como un coach proactivo de Hábito 3:

### 7.1 Live Context Snapshot (`SuiteRagService`)
Inyecta en tiempo real el estado de la semana:
- Rango de fechas de la semana activa.
- Porcentaje de enfoque en Cuadrante II.
- Desglose de Grandes Rocas por rol y estado de balance.
- Advertencia explícita si existen roles desatendidos (0 rocas).

### 7.2 Herramientas Disponibles
1. **`getWeeklySchedule`:** Retorna el cronograma semanal organizado por día y la bandeja sin asignar.
2. **`getRolesCompass`:** Retorna la lista de roles, sus propósitos, el conteo de rocas y roles en riesgo.
3. **`proposeScheduleBigRock`:** Genera un artefacto de propuesta de acción interactiva (`ActionProposalCardView`) con `isBigRock: true`, `quadrant: 'q2_important_not_urgent'`, `roleId`, `scheduledDayOfWeek` y `estimatedDurationMinutes`, permitiendo confirmar la creación en 1 solo toque.

---

## 8. Esquema de Base de Datos SQL (`011_agenda_covey_system.sql`)

```sql
-- Tabla de Roles Vitales
CREATE TABLE IF NOT EXISTS public.user_life_roles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  purpose_statement TEXT,
  icon_name TEXT DEFAULT 'star',
  color_hex TEXT DEFAULT '#3B82F6',
  position INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de Planes Semanales
CREATE TABLE IF NOT EXISTS public.weekly_plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  week_start_date DATE NOT NULL,
  retrospective_notes TEXT,
  priorities_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, week_start_date)
);

-- Columnas añadidas a reminders
ALTER TABLE public.reminders
  ADD COLUMN IF NOT EXISTS role_id UUID REFERENCES public.user_life_roles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS weekly_plan_id UUID REFERENCES public.weekly_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS covey_quadrant TEXT DEFAULT 'q2_important_not_urgent',
  ADD COLUMN IF NOT EXISTS is_big_rock BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS scheduled_day_of_week INTEGER,
  ADD COLUMN IF NOT EXISTS estimated_duration_minutes INTEGER;

-- Índices de alto rendimiento
CREATE INDEX IF NOT EXISTS idx_reminders_covey_quadrant ON public.reminders(covey_quadrant);
CREATE INDEX IF NOT EXISTS idx_reminders_role_id ON public.reminders(role_id);
CREATE INDEX IF NOT EXISTS idx_reminders_weekly_plan_id ON public.reminders(weekly_plan_id);
CREATE INDEX IF NOT EXISTS idx_reminders_big_rock ON public.reminders(is_big_rock) WHERE is_big_rock = TRUE;

-- Seguridad a nivel de fila (RLS)
ALTER TABLE public.user_life_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_plans ENABLE ROW LEVEL SECURITY;
```

---

## 9. Calidad y Suite de Pruebas Automatizadas

```bash
# Ejecución de la suite completa de Agenda y Recordatorios
flutter test \
  test/covey_weekly_planner_test.dart \
  test/covey_agent_rag_test.dart \
  test/reminders_nlp_test.dart \
  test/reminders_pinned_banner_and_sync_test.dart \
  test/agente_rag_test.dart

# Análisis estático y linter
flutter analyze lib
```
Estado actual: **38 pruebas aprobadas (100% éxito), 0 errores, 0 warnings (clean analysis)**.
