import 'package:flutter/material.dart';

import '../diario/dialogs/entry_reader_dialog.dart';
import '../diario/models/diario_entry.dart';
import '../diario/screens/animo_dashboard_screen.dart';
import '../habitos/dialogs/habit_detail_cli_dialog.dart';
import '../habitos/models/habit_model.dart';
import '../notas/dialogs/note_reader_dialog.dart';
import '../quebrado/dialogs/pending_confirmations_dialog.dart';
import '../quebrado/dialogs/transaction_detail_dialog.dart';
import '../quebrado/models/transaction.dart';
import 'responsive_sheet_helper.dart';

// Detalles ligados a una URL (`docs/design/rutas.md` §2): cada `Page` crea un
// diálogo o una hoja cuyo `settings` es la propia página. Así, debajo se ve la
// pantalla de la app, cerrar hace `pop` (el router deja la URL en el padre) y
// el Atrás del navegador cierra el detalle.

/// Diálogo ligado a una ruta. Equivale a `showDialog(builder: builder)`.
class SuiteDialogPage<T> extends Page<T> {
  const SuiteDialogPage({
    required this.builder,
    this.barrierDismissible = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final WidgetBuilder builder;
  final bool barrierDismissible;

  @override
  Route<T> createRoute(BuildContext context) {
    // Sin color en el tema, `DialogRoute` usa el mismo velo que `showDialog`.
    final themedBarrier = DialogTheme.of(context).barrierColor;
    if (themedBarrier == null) {
      return DialogRoute<T>(
        context: context,
        builder: builder,
        barrierDismissible: barrierDismissible,
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        settings: this,
      );
    }
    return DialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor: themedBarrier,
      barrierDismissible: barrierDismissible,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      settings: this,
    );
  }
}

/// Hoja ligada a una ruta. Es la misma ruta que `showResponsiveSheet`: hoja
/// inferior en `< 840` y panel lateral derecho en `≥ 840`. Con
/// [sidePanelOnDesktop] en `false` es siempre una hoja inferior (como
/// `showModalBottomSheet`).
class SuiteSheetPage<T> extends Page<T> {
  const SuiteSheetPage({
    required this.builder,
    this.sidePanelOnDesktop = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final WidgetBuilder builder;
  final bool sidePanelOnDesktop;

  @override
  Route<T> createRoute(BuildContext context) => buildResponsiveSheetRoute<T>(
        context: context,
        builder: builder,
        sidePanelOnDesktop: sidePanelOnDesktop,
        settings: this,
      );
}

/// Página que delega en una función que ya sabe construir la ruta del detalle
/// (p. ej. el visor de entradas, que decide entre diálogo y hoja).
class _RouteFactoryPage<T> extends Page<T> {
  const _RouteFactoryPage(this.factory, {super.key, super.name});

  final Route<T> Function(BuildContext context, RouteSettings settings) factory;

  @override
  Route<T> createRoute(BuildContext context) => factory(context, this);
}

/// Páginas de detalle de cada app, con la misma vista y la misma forma
/// (diálogo, hoja o página) con que se abren hoy desde la app. Reciben el
/// registro ya buscado con `SuiteRecordLookup`. [key] debe ser el `pageKey`
/// del router.
abstract final class SuiteRoutePages {
  /// `/finanzas/movimientos/:id`: hoja inferior, como desde el Historial.
  static Page<void> movimiento(Transaction transaction, {LocalKey? key, String? name}) =>
      SuiteSheetPage<void>(
        key: key,
        name: name,
        sidePanelOnDesktop: false,
        builder: (_) => TransactionDetailBottomSheet(transaction: transaction),
      );

  /// `/finanzas/pagos`: hoja de pagos pendientes, como al entrar en Finanzas.
  static Page<void> pagos({LocalKey? key, String? name}) => SuiteSheetPage<void>(
        key: key,
        name: name,
        builder: (_) => const PendingConfirmationsBottomSheet(),
      );

  /// `/diario/entradas/:id`: diálogo en desktop u hoja en mobile.
  static Page<void> entrada(DiarioEntry entry, {LocalKey? key, String? name}) =>
      _RouteFactoryPage<void>(
        (context, settings) => buildEntryReaderRoute(context, entry, settings: settings),
        key: key,
        name: name,
      );

  /// `/diario/animo`: página completa.
  static Page<void> animo({LocalKey? key, String? name}) => MaterialPage<void>(
        key: key,
        name: name,
        child: const AnimoDashboardScreen(),
      );

  /// `/habitos/:id`: diálogo de detalle.
  static Page<void> habito(HabitModel habit, {LocalKey? key, String? name}) =>
      SuiteDialogPage<void>(
        key: key,
        name: name,
        builder: (_) => HabitDetailCliDialog(habit: habit),
      );

  /// `/notas/:id`: lector de notas (busca la versión viva por id).
  static Page<void> nota(String noteId, {LocalKey? key, String? name}) =>
      SuiteDialogPage<void>(
        key: key,
        name: name,
        builder: (_) => NoteReaderDialog(noteId: noteId),
      );
}
