// Catálogo de acciones rápidas de la suite (spec 02, paso 4;
// docs/design/ortiz-home.md §6–§7).
//
// Una sola lista alimenta el menú ☰, el riel, los chips y la paleta. Cada
// acción abre el formulario EXISTENTE de su app (como se abre hoy: hoja con
// `showResponsiveSheet` o `Dialog` propio con `showDialog`). Al guardar,
// [runSuiteAction] muestra el aviso «… · Ver» y pone contenta la cara de
// Ortiz; la acción no navega (la URL no cambia).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../agente/viewmodels/agente_state.dart';
import '../diario/dialogs/contact_editor_dialog.dart';
import '../diario/models/diario_contact.dart';
import '../diario/models/diario_entry.dart';
import '../diario/models/mood_log.dart';
import '../diario/screens/entry_editor_dialog.dart';
import '../diario/widgets/mood_checkin_sheet.dart';
import '../habitos/dialogs/habit_terminal_editor_dialog.dart';
import '../habitos/models/habit_model.dart';
import '../habitos/widgets/habits_today_sheet.dart';
import '../notas/models/note_category.dart';
import '../notas/models/note_item.dart';
import '../notas/screens/note_editor_screen.dart';
import '../quebrado/dialogs/add_transaction_dialog.dart';
import '../quebrado/dialogs/pending_confirmations_dialog.dart';
import '../quebrado/models/transaction.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../quebrado/widgets/helpers.dart' show formatRate;
import '../recordatorios/dialogs/reminder_editor_dialog.dart';
import '../recordatorios/models/reminder_model.dart';
import '../recordatorios/widgets/weekly_schedule_view.dart';
import '../theme/ortiz_space.dart';
import '../theme/suite_apps.dart';
import 'ortiz/ortiz_notice.dart';
import 'responsive_sheet_helper.dart';
import 'suite_router.dart' show SuiteRoutes;

/// Navega a una ruta de la suite (quien integra hace `context.go(path)`).
typedef SuiteNavigate = void Function(String path);

/// Abre el formulario de una acción. Devuelve el registro guardado, `true`
/// si guardó sin devolver registro, un [SuiteActionInfo] (aviso informativo)
/// o null/`false` si se cerró sin guardar (o si el formulario ya avisó por su
/// cuenta). [go] sirve a los formularios que navegan solos (p. ej. «Abrir
/// Hábitos» dentro de la hoja de hábitos de hoy).
typedef SuiteActionOpener = Future<Object?> Function(
  BuildContext context,
  SuiteNavigate go,
);

/// Aviso informativo (no de éxito) que devuelve una acción sin formulario,
/// como «Tasas del día». No activa la alegría de Ortiz.
@immutable
class SuiteActionInfo {
  const SuiteActionInfo(this.message, {this.viewRoute});

  final String message;

  /// Ruta de «Ver», o null para un aviso sin botón.
  final String? viewRoute;
}

/// Una acción rápida de una app de la suite.
@immutable
class SuiteAction {
  const SuiteAction({
    required this.id,
    required this.app,
    required this.label,
    required this.icon,
    required this.open,
    this.noticeText,
    this.viewRoute,
    this.keywords = '',
    this.chip = false,
  });

  /// Identificador estable (`app.accion`), útil para claves y tests.
  final String id;
  final SuiteApp app;

  /// Etiqueta visible («Registrar gasto»).
  final String label;
  final IconData icon;

  /// Palabras extra para la búsqueda de la paleta (§6).
  final String keywords;

  /// Si sale como chip sobre el campo del chat.
  final bool chip;

  /// Abre el formulario existente de la app.
  final SuiteActionOpener open;

  /// Texto del aviso de éxito según lo devuelto por [open]. Null: la acción
  /// no muestra aviso de éxito (p. ej. «Agenda de la semana», que no guarda).
  final String Function(Object record)? noticeText;

  /// Ruta de «Ver» según el registro devuelto, o null para un aviso sin
  /// «Ver» (registro sin id, o el formulario devolvió `true`).
  final String? Function(Object record)? viewRoute;
}

/// Ruta de la ficha de un contacto de Diario (Q3 de ortiz-home.md).
String suiteContactRoute(String id) => SuiteRoutes.contacto(id);

/// Texto de «Tasas del día» (sin marca de éxito).
String suiteRatesMessage({
  required double bcv,
  required double parallel,
  required double euro,
}) {
  if (bcv <= 0 || parallel <= 0 || euro <= 0) {
    return 'Aún no tengo las tasas de hoy';
  }
  return 'BCV ${formatRate(bcv)} · Paralelo ${formatRate(parallel)} · '
      'Euro ${formatRate(euro)}';
}

/// [build] con [id], o null si el registro no tiene id (guardado local, R-04).
String? _withId(String id, String Function(String id) build) =>
    id.trim().isEmpty ? null : build(id);

/// «Ver» de «Pagos pendientes»: el movimiento si se registró uno solo (con
/// id); si no (varios, ninguno o sin id), la lista de pagos.
String suitePaymentsViewRoute(Object record) {
  if (record is List<Transaction> && record.length == 1) {
    return _withId(record.single.id, SuiteRoutes.movimiento) ??
        SuiteRoutes.pagos;
  }
  return SuiteRoutes.pagos;
}

Future<Object?> _openTransaction(BuildContext context, TransactionType type) =>
    showResponsiveSheet<Transaction>(
      context: context,
      // Solo el aviso «✓ … · Ver», sin el diálogo de éxito de Finanzas (PQ-01).
      builder: (_) => AddTransactionBottomSheet(initialType: type, showSuccessDialog: false),
    );

Future<Object?> _openNote(BuildContext context, {String? categoryId}) =>
    NoteEditorScreen.open(context, initialCategoryId: categoryId);

/// El catálogo completo, en el orden de las apps y de §6.
final List<SuiteAction> suiteActions = List.unmodifiable(<SuiteAction>[
  // --- Finanzas ---
  SuiteAction(
    id: 'finanzas.gasto',
    app: SuiteApp.finanzas,
    label: 'Registrar gasto',
    icon: Icons.arrow_downward_rounded,
    keywords: 'pago compra egreso',
    chip: true,
    open: (context, _) => _openTransaction(context, TransactionType.expense),
    noticeText: (_) => 'Gasto registrado',
    viewRoute: (r) =>
        r is Transaction ? _withId(r.id, SuiteRoutes.movimiento) : null,
  ),
  SuiteAction(
    id: 'finanzas.ingreso',
    app: SuiteApp.finanzas,
    label: 'Registrar ingreso',
    icon: Icons.arrow_upward_rounded,
    keywords: 'cobro sueldo',
    open: (context, _) => _openTransaction(context, TransactionType.income),
    noticeText: (_) => 'Ingreso registrado',
    viewRoute: (r) =>
        r is Transaction ? _withId(r.id, SuiteRoutes.movimiento) : null,
  ),
  SuiteAction(
    id: 'finanzas.tasas',
    app: SuiteApp.finanzas,
    label: 'Tasas del día',
    icon: Icons.currency_exchange_rounded,
    keywords: 'dólar bcv paralelo euro cambio',
    open: (context, _) async {
      final app = context.read<AppState>();
      return SuiteActionInfo(
        suiteRatesMessage(
          bcv: app.bcvRate,
          parallel: app.parallelRate,
          euro: app.euroRate,
        ),
        viewRoute: SuiteApp.finanzas.route,
      );
    },
  ),
  SuiteAction(
    id: 'finanzas.pagos',
    app: SuiteApp.finanzas,
    label: 'Pagos pendientes',
    icon: Icons.pending_actions_rounded,
    // La hoja devuelve los movimientos registrados (vacía si se confirmó con
    // saldo existente) o null si se cerró o solo se omitieron pagos.
    open: (context, _) => showResponsiveSheet<List<Transaction>>(
      context: context,
      builder: (_) => const PendingConfirmationsBottomSheet(),
    ),
    noticeText: (_) => 'Pago confirmado',
    viewRoute: suitePaymentsViewRoute,
  ),
  // --- Diario ---
  SuiteAction(
    id: 'diario.entrada',
    app: SuiteApp.diario,
    label: 'Nueva entrada',
    icon: Icons.edit_rounded,
    keywords: 'diario escribir',
    chip: true,
    open: (context, _) => showDialog<DiarioEntry>(
      context: context,
      builder: (_) => const EntryEditorDialog(),
    ),
    noticeText: (_) => 'Entrada guardada',
    viewRoute: (r) =>
        r is DiarioEntry ? _withId(r.id, SuiteRoutes.entrada) : null,
  ),
  SuiteAction(
    id: 'diario.animo',
    app: SuiteApp.diario,
    label: 'Registrar ánimo',
    icon: Icons.mood_rounded,
    keywords: 'humor emoción',
    chip: true,
    open: (context, _) => showMoodCheckinSheet(context),
    noticeText: (_) => 'Ánimo registrado',
    viewRoute: (r) => r is MoodLog ? SuiteRoutes.animo : null,
  ),
  SuiteAction(
    id: 'diario.contacto',
    app: SuiteApp.diario,
    label: 'Nuevo contacto',
    icon: Icons.person_add_alt_rounded,
    open: (context, _) => showDialog<Object>(
      context: context,
      builder: (_) => const ContactEditorDialog(),
    ),
    noticeText: (_) => 'Contacto guardado',
    viewRoute: (r) =>
        r is DiarioContact ? _withId(r.id, suiteContactRoute) : null,
  ),
  // --- Hábitos ---
  SuiteAction(
    id: 'habitos.nuevo',
    app: SuiteApp.habitos,
    label: 'Nuevo hábito',
    icon: Icons.add_task_rounded,
    open: (context, _) => showDialog<Object>(
      context: context,
      builder: (_) => const HabitTerminalEditorDialog(),
    ),
    noticeText: (_) => 'Hábito creado',
    viewRoute: (r) =>
        r is HabitModel ? _withId(r.id, SuiteRoutes.habito) : null,
  ),
  SuiteAction(
    id: 'habitos.hoy',
    app: SuiteApp.habitos,
    label: 'Marcar hábitos de hoy',
    icon: Icons.checklist_rounded,
    chip: true,
    // La hoja muestra su propio aviso «Hábitos de hoy: {n} de {m} hechos»
    // con «Ver» → /habitos (ortiz-home.md §8); aquí no se repite.
    open: (context, go) async {
      await showHabitsTodaySheet(
        context,
        onOpenHabitos: () => go(SuiteApp.habitos.route),
        onCreateHabit: () =>
            runSuiteAction(context, suiteActionById('habitos.nuevo'), onView: go),
      );
      return null;
    },
  ),
  // --- Recordatorios ---
  SuiteAction(
    id: 'recordatorios.nuevo',
    app: SuiteApp.recordatorios,
    label: 'Nuevo recordatorio',
    icon: Icons.add_alert_rounded,
    keywords: 'tarea pendiente alarma',
    chip: true,
    open: (context, _) => showDialog<Object>(
      context: context,
      builder: (_) => const ReminderEditorDialog(),
    ),
    noticeText: (_) => 'Recordatorio creado',
    viewRoute: (r) =>
        r is ReminderModel ? _withId(r.id, SuiteRoutes.recordatorio) : null,
  ),
  SuiteAction(
    id: 'recordatorios.agenda',
    app: SuiteApp.recordatorios,
    label: 'Agenda de la semana',
    icon: Icons.calendar_view_week_rounded,
    open: (context, _) => showResponsiveSheet<Object>(
      context: context,
      // Mismo ancho que la columna de lectura (720, ortiz-home.md §6).
      desktopWidth: OrtizSize.chatMaxWidth,
      builder: (_) => const WeeklyScheduleView(),
    ),
  ),
  // --- Notas ---
  SuiteAction(
    id: 'notas.nueva',
    app: SuiteApp.notas,
    label: 'Nueva nota',
    icon: Icons.note_add_rounded,
    open: (context, _) => _openNote(context),
    noticeText: (_) => 'Nota guardada',
    viewRoute: (r) => r is NoteItem ? _withId(r.id, SuiteRoutes.nota) : null,
  ),
  SuiteAction(
    id: 'notas.acuerdo',
    app: SuiteApp.notas,
    label: 'Nuevo acuerdo',
    icon: Icons.handshake_rounded,
    keywords: 'reunión compromiso',
    open: (context, _) =>
        _openNote(context, categoryId: NoteCategory.acuerdosCategoryId),
    noticeText: (_) => 'Acuerdo guardado',
    viewRoute: (r) => r is NoteItem ? _withId(r.id, SuiteRoutes.nota) : null,
  ),
]);

/// La acción con [id] (`app.accion`). Lanza `StateError` si no existe.
SuiteAction suiteActionById(String id) =>
    suiteActions.firstWhere((a) => a.id == id);

/// Acciones de [app], en el orden del catálogo.
List<SuiteAction> suiteActionsFor(SuiteApp app) =>
    suiteActions.where((a) => a.app == app).toList(growable: false);

/// Acciones que salen como chip sobre el campo del chat.
List<SuiteAction> get suiteChipActions =>
    suiteActions.where((a) => a.chip).toList(growable: false);

/// Ejecuta [action] desde [context] (que debe seguir montado al cerrar el
/// formulario: el del shell o el del riel, no el del drawer):
/// - si se cerró sin guardar (null/`false`), no hace nada;
/// - si devuelve un [SuiteActionInfo], muestra ese aviso informativo;
/// - si guardó, muestra el aviso de éxito con «Ver» (cuando hay ruta) y pone
///   contenta la cara de Ortiz (`AgenteState.celebrate`).
///
/// «Ver» llama a [onView] con la ruta; quien integra hace `context.go(path)`.
Future<void> runSuiteAction(
  BuildContext context,
  SuiteAction action, {
  required SuiteNavigate onView,
}) async {
  final record = await action.open(context, onView);
  if (record == null || record == false || !context.mounted) return;

  if (record is SuiteActionInfo) {
    final route = record.viewRoute;
    showOrtizNotice(
      context,
      record.message,
      actionLabel: route == null ? null : 'Ver',
      onAction: route == null ? null : () => onView(route),
    );
    return;
  }

  final text = action.noticeText?.call(record);
  if (text == null) return;
  final route = action.viewRoute?.call(record);
  showOrtizNotice(
    context,
    text,
    success: true,
    actionLabel: route == null ? null : 'Ver',
    onAction: route == null ? null : () => onView(route),
  );
  context.read<AgenteState>().celebrate();
}
