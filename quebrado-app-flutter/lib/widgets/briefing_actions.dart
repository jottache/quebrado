// Acciones por fila del resumen del día (spec 04, paso 6;
// docs/design/resumen-del-dia.md §6 y U6).
//
// Traduce cada `BriefingAction` al formulario propio de su app, abierto
// encima del chat como las acciones rápidas (sin navegar). Solo «Ver
// contacto», «Ver» de tasas y «Ver todos» navegan. Las reglas viven en
// `AppState`, `RemindersState` y `AgenteState`; aquí solo se orquesta.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../agente/models/daily_briefing.dart';
import '../agente/viewmodels/agente_state.dart';
import '../agente/widgets/briefing_block.dart';
import '../quebrado/dialogs/partial_payment_dialog.dart';
import '../quebrado/dialogs/pending_confirmations_dialog.dart';
import '../quebrado/models/recurring_payment.dart';
import '../quebrado/models/transaction.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../quebrado/widgets/helpers.dart' show formatDate;
import '../recordatorios/models/reminder_model.dart' show ReminderStatus;
import '../recordatorios/viewmodels/reminders_state.dart';
import '../theme/suite_apps.dart';
import 'ortiz/ortiz_notice.dart';
import 'responsive_sheet_helper.dart';
import 'suite_actions.dart';
import 'suite_router.dart' show SuiteRoutes;

/// Ejecuta la acción de una fila del resumen del día (spec 04, §6).
///
/// [context] debe seguir montado al cerrar el formulario (el del chat o el
/// del panel, no el de una hoja). «Ver» navega con el `GoRouter` de la suite.
Future<void> runBriefingAction(
  BuildContext context,
  BriefingAction action,
) async {
  void go(String path) {
    if (!context.mounted) return;
    GoRouter.maybeOf(context)?.go(path);
  }

  switch (action) {
    case BriefingWriteDiary():
      await runSuiteAction(context, suiteActionById('diario.entrada'), onView: go);
    case BriefingLogMood():
      await runSuiteAction(context, suiteActionById('diario.animo'), onView: go);
    case BriefingMarkHabits():
      // La hoja de hábitos muestra su propio aviso.
      await runSuiteAction(context, suiteActionById('habitos.hoy'), onView: go);
    case BriefingViewRates():
      // U6: navega; el aviso de «Tasas del día» repetiría lo que ya muestra la fila.
      go(SuiteApp.finanzas.route);
    case BriefingViewContact(:final contactId):
      go(suiteContactRoute(contactId));
    case BriefingViewAll(:final target):
      go(switch (target) {
        BriefingViewAllTarget.payments => SuiteRoutes.pagos,
        BriefingViewAllTarget.reminders => SuiteApp.recordatorios.route,
      });
    case BriefingPay():
      await _pay(context, action, go);
    case BriefingSnooze():
      await _snooze(context, action, go);
  }
}

/// Ocurrencia pendiente de [paymentId] del día [date] en el libro activo, o
/// null si ya no está pendiente.
PendingOccurrence? _findOccurrence(AppState app, String paymentId, DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final daysAhead = math.max(7, DateUtils.dateOnly(date).difference(today).inDays);
  for (final occ in app.pendingPaymentsWithin(daysAhead: daysAhead)) {
    if (occ.payment.id == paymentId && DateUtils.isSameDay(occ.occurrenceDate, date)) {
      return occ;
    }
  }
  return null;
}

Future<void> _pay(BuildContext context, BriefingPay action, SuiteNavigate go) async {
  final app = context.read<AppState>();
  final agente = context.read<AgenteState>();
  final occ = _findOccurrence(app, action.paymentId, action.oldestOccurrenceDate);
  if (occ == null) {
    showOrtizNotice(context, 'Ese pago ya no está pendiente');
    // La fila deja de ofrecer «Pagar» si el pago ya no está en la ventana. No
    // se sabe si se pagó u omitió fuera del resumen: sin ocurrencias, se quita.
    await agente.refreshBriefingPayments(paymentId: action.paymentId, confirmedAs: null);
    return;
  }

  if (!action.partial) {
    // La hoja devuelve los movimientos registrados (vacía si se pagó con
    // saldo existente) o null si se cerró o se omitió el pago.
    final record = await showResponsiveSheet<List<Transaction>>(
      context: context,
      builder: (_) => PendingConfirmationsBottomSheet(filterOccurrence: occ),
    );
    if (record == null) {
      if (app.isOccurrenceConfirmed(action.paymentId, occ.occurrenceDate)) {
        await agente.refreshBriefingPayments(
          paymentId: action.paymentId,
          confirmedAs: BriefingPaymentState.dismissed,
        );
      }
      return;
    }
    // La regla de cuándo la fila pasa a `paid` (sin ocurrencias restantes)
    // vive en AgenteState.refreshBriefingPayments.
    await agente.refreshBriefingPayments(
      paymentId: action.paymentId,
      confirmedAs: BriefingPaymentState.paid,
    );
    if (!context.mounted) return;
    showOrtizNotice(
      context,
      'Pago confirmado',
      success: true,
      actionLabel: 'Ver',
      onAction: () => go(suitePaymentsViewRoute(record)),
    );
    agente.celebrate();
    return;
  }

  final saved = await showResponsiveSheet<bool>(
    context: context,
    builder: (_) => PartialPaymentBottomSheet(occurrence: occ),
  );
  if (saved != true) return;
  await agente.refreshBriefingPayments(paymentId: action.paymentId);
  if (!context.mounted) return;
  showOrtizNotice(
    context,
    'Abono registrado',
    success: true,
    actionLabel: 'Ver',
    onAction: () => go(suitePaymentsViewRoute(true)),
  );
  agente.celebrate();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Aviso al posponer (U10): «Recordatorio pospuesto a las 16:30» si es hoy,
/// «… a mañana 15:30» si es mañana y «… a {dd/MM/yyyy} HH:mm» si no; el
/// mismo «cuándo» que la fila pospuesta («Pospuesto a …»).
@visibleForTesting
String briefingSnoozeNotice(DateTime now, DateTime until) {
  final hm = '${_two(until.hour)}:${_two(until.minute)}';
  final when = switch (briefingCalendarDaysBetween(now, until)) {
    0 => 'las $hm',
    1 => 'mañana $hm',
    _ => '${formatDate(until)} $hm',
  };
  return 'Recordatorio pospuesto a $when';
}

Future<void> _snooze(BuildContext context, BriefingSnooze action, SuiteNavigate go) async {
  final reminders = context.read<RemindersState>();
  final agente = context.read<AgenteState>();
  final reminder = reminders.allReminders.where((r) => r.id == action.reminderId).firstOrNull;
  // Borrado o ya completado/archivado: no se pospone ni se marca la fila.
  if (reminder == null ||
      (reminder.status != ReminderStatus.pending && reminder.status != ReminderStatus.snoozed)) {
    showOrtizNotice(context, 'Ese recordatorio ya no está pendiente.');
    return;
  }
  // Una sola hora objetivo para el recordatorio, la fila y el aviso.
  final now = DateTime.now();
  final until = action.untilFrom(now);
  await reminders.snoozeTo(action.reminderId, until);
  await agente.markBriefingReminderSnoozed(action.reminderId, until);
  if (!context.mounted) return;
  showOrtizNotice(
    context,
    briefingSnoozeNotice(now, until),
    success: true,
    actionLabel: 'Ver',
    onAction: () => go(SuiteRoutes.recordatorio(action.reminderId)),
  );
  agente.celebrate();
}
