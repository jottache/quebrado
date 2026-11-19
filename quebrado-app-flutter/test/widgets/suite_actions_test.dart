import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/ortiz_face.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/notas/models/note_item.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/dialogs/add_transaction_dialog.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/suite_actions.dart';
import 'package:quebrado_app_flutter/widgets/suite_router.dart' show SuiteRoutes;

import '../helpers/pump_app.dart';

Transaction _tx(String id) => Transaction(
      id: id,
      date: DateTime(2026, 11, 17),
      amount: 10,
      currency: CurrencyType.usd,
      note: 'prueba',
      type: TransactionType.expense,
      exchangeRate: 1,
    );

void main() {
  group('catálogo', () {
    test('tiene las 13 acciones con app, etiqueta e icono', () {
      final labels = {for (final a in suiteActions) a.label: a.app};
      expect(labels, {
        'Registrar gasto': SuiteApp.finanzas,
        'Registrar ingreso': SuiteApp.finanzas,
        'Tasas del día': SuiteApp.finanzas,
        'Pagos pendientes': SuiteApp.finanzas,
        'Nueva entrada': SuiteApp.diario,
        'Registrar ánimo': SuiteApp.diario,
        'Nuevo contacto': SuiteApp.diario,
        'Nuevo hábito': SuiteApp.habitos,
        'Marcar hábitos de hoy': SuiteApp.habitos,
        'Nuevo recordatorio': SuiteApp.recordatorios,
        'Agenda de la semana': SuiteApp.recordatorios,
        'Nueva nota': SuiteApp.notas,
        'Nuevo acuerdo': SuiteApp.notas,
      });
      expect(suiteActions.map((a) => a.id).toSet(), hasLength(13));
      expect(suiteActionById('finanzas.gasto').icon,
          Icons.arrow_downward_rounded);
    });

    test('los chips son los cinco de ortiz-home §6', () {
      expect(suiteChipActions.map((a) => a.label), [
        'Registrar gasto',
        'Nueva entrada',
        'Registrar ánimo',
        'Marcar hábitos de hoy',
        'Nuevo recordatorio',
      ]);
    });

    test('«Ver» del gasto va al movimiento y sin id no hay «Ver»', () {
      final gasto = suiteActionById('finanzas.gasto');
      expect(gasto.noticeText!(_tx('abc')), 'Gasto registrado');
      expect(gasto.viewRoute!(_tx('abc')), '/finanzas/movimientos/abc');
      expect(gasto.viewRoute!(_tx('')), isNull);
      expect(gasto.viewRoute!(true), isNull);
    });

    test('«Ver» del contacto va a su ficha', () {
      final contacto = suiteActionById('diario.contacto');
      expect(contacto.viewRoute!(DiarioContact(id: 'c1', name: 'X')),
          '/diario/contactos/c1');
    });

    test('«Ver» de pagos va al movimiento si hay uno solo y si no a la lista',
        () {
      final pagos = suiteActionById('finanzas.pagos');
      expect(pagos.noticeText!(<Transaction>[]), 'Pago confirmado');
      expect(pagos.viewRoute!([_tx('m1')]), '/finanzas/movimientos/m1');
      expect(pagos.viewRoute!([_tx('m1'), _tx('m2')]), '/finanzas/pagos');
      expect(pagos.viewRoute!(<Transaction>[]), '/finanzas/pagos');
      expect(pagos.viewRoute!([_tx('')]), '/finanzas/pagos');
    });

    test('«Ver» de hábito, recordatorio y nota usa el id devuelto', () {
      expect(
        suiteActionById('habitos.nuevo')
            .viewRoute!(HabitModel(id: 'h1', title: 'Leer')),
        SuiteRoutes.habito('h1'),
      );
      expect(
        suiteActionById('recordatorios.nuevo')
            .viewRoute!(ReminderModel(id: 'r1', title: 'Llamar')),
        SuiteRoutes.recordatorio('r1'),
      );
      expect(
        suiteActionById('notas.nueva').viewRoute!(
          NoteItem(id: 'n1', title: 'Idea', categoryId: 'general'),
        ),
        SuiteRoutes.nota('n1'),
      );
    });

    test('tasas: texto con las tres tasas o aviso si falta alguna', () {
      expect(suiteRatesMessage(bcv: 36.5, parallel: 40, euro: 39),
          'BCV Bs. 36.50 · Paralelo Bs. 40.00 · Euro Bs. 39.00');
      expect(suiteRatesMessage(bcv: 0, parallel: 40, euro: 39),
          'Aún no tengo las tasas de hoy');
    });
  });

  group('runSuiteAction', () {
    late AgenteState agente;
    late List<String> visited;

    setUp(() {
      agente = AgenteState(autoInit: false);
      visited = [];
    });

    Future<void> pumpRunner(WidgetTester tester, SuiteAction action) =>
        pumpApp(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    runSuiteAction(context, action, onView: visited.add),
                child: const Text('Ejecutar'),
              ),
            ),
          ),
          providers: [ChangeNotifierProvider<AgenteState>.value(value: agente)],
          window: WindowClass.compact,
        );

    SuiteAction fake(Object? result) => SuiteAction(
          id: 'prueba.fake',
          app: SuiteApp.finanzas,
          label: 'Fake',
          icon: Icons.add,
          open: (_, _) async => result,
          noticeText: (_) => 'Gasto registrado',
          viewRoute: (r) => r is Transaction ? '/finanzas/movimientos/${r.id}' : null,
        );

    testWidgets('con registro muestra el aviso con «Ver» y celebra',
        (tester) async {
      await pumpRunner(tester, fake(_tx('t1')));
      await tester.tap(find.text('Ejecutar'));
      await tester.pumpAndSettle();

      expect(find.text('Gasto registrado'), findsOneWidget);
      expect(agente.ortizMood, OrtizMood.happy);
      await tester.tap(find.text('Ver'));
      expect(visited, ['/finanzas/movimientos/t1']);

      await tester.pump(const Duration(seconds: 2));
      expect(agente.ortizMood, OrtizMood.idle);
    });

    testWidgets('con true muestra el aviso sin «Ver»', (tester) async {
      await pumpRunner(tester, fake(true));
      await tester.tap(find.text('Ejecutar'));
      await tester.pumpAndSettle();

      expect(find.text('Gasto registrado'), findsOneWidget);
      expect(find.text('Ver'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('con null no hay aviso ni alegría', (tester) async {
      await pumpRunner(tester, fake(null));
      await tester.tap(find.text('Ejecutar'));
      await tester.pumpAndSettle();

      expect(find.text('Gasto registrado'), findsNothing);
      expect(agente.ortizMood, OrtizMood.idle);
    });

    testWidgets('un aviso informativo no celebra', (tester) async {
      await pumpRunner(tester,
          fake(const SuiteActionInfo('BCV x', viewRoute: '/finanzas')));
      await tester.tap(find.text('Ejecutar'));
      await tester.pumpAndSettle();

      expect(find.text('BCV x'), findsOneWidget);
      expect(agente.ortizMood, OrtizMood.idle);
      await tester.tap(find.text('Ver'));
      expect(visited, ['/finanzas']);
    });
  });

  // PQ-01 (decisión de la persona del 2026-11-18): desde una acción rápida
  // solo sale el aviso «✓ … · Ver», sin el diálogo de éxito de Finanzas.
  testWidgets('«Registrar gasto» abre el formulario sin el diálogo de éxito antiguo',
      (tester) async {
    final app = _QuietAppState();
    addTearDown(app.dispose);
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => suiteActionById('finanzas.gasto').open(context, (_) {}),
            child: const Text('Ejecutar'),
          ),
        ),
      ),
      providers: [ChangeNotifierProvider<AppState>.value(value: app)],
      window: WindowClass.expanded,
    );

    await tester.tap(find.text('Ejecutar'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<AddTransactionBottomSheet>(
        find.byType(AddTransactionBottomSheet));
    expect(sheet.initialType, TransactionType.expense);
    expect(sheet.showSuccessDialog, isFalse);
  });

  test('dentro de Finanzas el formulario conserva el diálogo de éxito', () {
    expect(const AddTransactionBottomSheet().showSuccessDialog, isTrue);
  });
}

/// AppState sin carga de datos (ni SQLite ni Supabase).
class _QuietAppState extends AppState {
  @override
  Future<void> loadData({bool forceReload = false}) async {}
}
