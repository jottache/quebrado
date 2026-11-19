// Resumen del día (spec 04, docs/design/resumen-del-dia.md U2, U3, U6, U8):
// filas por sección, montos con el formato de la app (CA-03, CA-04), estados
// (cargando, vencido, pagado, pospuesto, todo al día, resumen viejo), tope de
// filas en el chat y acciones emitidas. Datos inventados.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/daily_briefing.dart';
import 'package:quebrado_app_flutter/agente/widgets/briefing_block.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

import '../../helpers/pump_app.dart';

// Martes 17 de noviembre de 2026, 09:00 (mañana).
final _now = DateTime(2026, 11, 17, 9);
const double _bcv = 250;
const double _euro = 270;

BriefingAmount _amount(double v, CurrencyType c) => BriefingAmount.convert(v, c, bcv: _bcv, euro: _euro);

BriefingPayment _payment(
  String id,
  String name, {
  required DateTime date,
  double amount = 25,
  CurrencyType currency = CurrencyType.usd,
  int overdue = 0,
  double partialPaid = 0,
  BriefingPaymentState state = BriefingPaymentState.pending,
}) =>
    BriefingPayment(
      paymentId: id,
      name: name,
      oldestOccurrenceDate: date,
      remaining: _amount(amount, currency),
      overdueCount: overdue,
      occurrenceCount: overdue > 0 ? overdue : 1,
      partialPaid: partialPaid,
      state: state,
    );

const _ratesReady = BriefingRates(
  status: BriefingStatus.ready,
  bcv: BriefingRate(value: 250, deltaVsPrevious: 2),
  parallel: BriefingRate(value: 298.1),
  euro: BriefingRate(value: 270),
);

/// Mañana con algo en cada sección.
DailyBriefing _full({
  List<BriefingPayment>? payments,
  List<BriefingReminder>? reminders,
  BriefingPeriod period = BriefingPeriod.morning,
}) =>
    DailyBriefing(
      generatedAt: _now,
      period: period,
      bookName: 'Personal',
      bookId: 'libro-personal',
      diario: const BriefingDiario(status: BriefingStatus.ready),
      mood: const BriefingMood(status: BriefingStatus.ready),
      payments: BriefingPayments(
        status: BriefingStatus.ready,
        items: payments ??
            [
              _payment('p-internet', 'Internet', date: DateTime(2026, 11, 19)),
              _payment('p-servicio', 'Servicio de limpieza', date: DateTime(2026, 11, 16), amount: 40, overdue: 1),
              _payment('p-agua', 'Agua', date: DateTime(2026, 11, 20), amount: 1000, currency: CurrencyType.bsBCV),
            ],
      ),
      birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
        BriefingBirthday(contactId: 'c-1', name: 'Andrea', date: DateTime(2026, 11, 20), inDays: 3),
      ]),
      habits: const BriefingHabits(
        status: BriefingStatus.ready,
        scheduled: 5,
        done: 3,
        pending: [BriefingHabitRef(id: 'h-1', title: 'Leer'), BriefingHabitRef(id: 'h-2', title: 'Caminar')],
      ),
      reminders: BriefingReminders(
        status: BriefingStatus.ready,
        items: reminders ??
            [BriefingReminder(id: 'r-1', title: 'Llamar al banco', dueAt: DateTime(2026, 11, 17, 15, 30))],
      ),
      rates: _ratesReady,
    );

/// Todo listo, escribió, sin pagos, hábitos completos, sin recordatorios.
DailyBriefing _allClear() => DailyBriefing(
      generatedAt: _now,
      period: BriefingPeriod.morning,
      bookName: 'Personal',
      diario: const BriefingDiario(status: BriefingStatus.ready, entriesToday: 2),
      mood: const BriefingMood(status: BriefingStatus.ready, loggedToday: true),
      payments: const BriefingPayments(status: BriefingStatus.ready),
      birthdays: const BriefingBirthdays(status: BriefingStatus.ready),
      habits: const BriefingHabits(status: BriefingStatus.ready, scheduled: 2, done: 2),
      reminders: const BriefingReminders(status: BriefingStatus.ready),
      rates: _ratesReady,
    );

Future<List<BriefingAction>> _pump(
  WidgetTester tester,
  DailyBriefing briefing, {
  BriefingBlockVariant variant = BriefingBlockVariant.chat,
  bool actionsEnabled = true,
  WindowClass window = WindowClass.compact,
  String? activeBookId,
  String? activeBookName,
  double? textScale,
}) async {
  final actions = <BriefingAction>[];
  Widget child = SingleChildScrollView(
    padding: const EdgeInsets.all(OrtizSpace.lg),
    child: BriefingBlock(
      briefing: briefing,
      variant: variant,
      actionsEnabled: actionsEnabled,
      activeBookId: activeBookId,
      activeBookName: activeBookName,
      onAction: actions.add,
    ),
  );
  if (textScale != null) {
    // Copia final: el cierre no debe capturar `child` reasignado (recursión).
    final block = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: block,
      ),
    );
  }
  await pumpApp(tester, child, window: window);
  return actions;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    group('en ${window.name}', () {
      testWidgets('pinta una fila por sección con su etiqueta, en el orden fijo', (tester) async {
        await _pump(tester, _full(), window: window);

        expect(find.text('Lo que viene hoy'), findsOneWidget);
        final labels = [
          'Diario',
          'Ánimo',
          'Pagos pendientes · Personal',
          'Cumpleaños',
          'Hábitos',
          'Recordatorios',
          'Tasas',
        ];
        final dys = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
        for (var i = 1; i < dys.length; i++) {
          expect(dys[i], greaterThan(dys[i - 1]), reason: '${labels[i]} va después de ${labels[i - 1]}');
        }
        expect(find.text('Aún no escribes hoy.'), findsOneWidget);
        expect(find.text('Aún no registras tu ánimo.'), findsOneWidget);
        expect(find.text('Andrea cumple el vie 20'), findsOneWidget);
        expect(find.text('en 3 días'), findsOneWidget);
        expect(find.text('3 de 5 hechos. Te faltan Leer y Caminar.'), findsOneWidget);
        expect(find.text('hoy 15:30'), findsOneWidget);
        expect(find.textContaining('BCV 250.00 (+0.8 %) · Paralelo 298.10 · € 270.00', findRichText: true),
            findsOneWidget);
        // La etiqueta de categoría solo va en la primera fila.
        expect(find.text('Pagos pendientes · Personal'), findsOneWidget);
      });

      testWidgets('muestra los montos con el formato de la app (CA-03, CA-04)', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, _full(), window: window);

        expect(find.text(r'$25.00'), findsOneWidget);
        expect(find.text('· Bs. 6250.00'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'\$25\.00 · Bs\. 6250\.00')), findsOneWidget);
        expect(find.text(r'$4.00'), findsOneWidget);
        expect(find.text('· Bs. 1000.00'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'\$4\.00 · Bs\. 1000\.00')), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('marca el pago vencido con la píldora y va primero', (tester) async {
        await _pump(tester, _full(), window: window);

        expect(find.text('Vencido'), findsOneWidget);
        expect(find.text('venció el lun 16'), findsOneWidget);
        expect(find.text('vence jue 19'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Servicio de limpieza')).dy,
          lessThan(tester.getTopLeft(find.text('Internet')).dy),
        );
      });

      testWidgets('el pago pagado muestra «Pagado» con la marca y sin botón (CA-10)', (tester) async {
        await _pump(
          tester,
          _full(payments: [
            _payment('p-internet', 'Internet', date: DateTime(2026, 11, 19), state: BriefingPaymentState.paid),
          ]),
          window: window,
        );

        expect(find.text('Pagado'), findsOneWidget);
        expect(find.text('Pagar'), findsNothing);
        final mark = find.ancestor(of: find.text('Pagado'), matching: find.byType(Row)).first;
        expect(find.descendant(of: mark, matching: find.byType(OrtizSuccessMark)), findsOneWidget);
        final muted = OrtizTokens.of(tester.element(find.text('Internet'))).muted;
        expect(tester.widget<Text>(find.text('Internet')).style?.color, muted);
      });

      testWidgets('con las secciones cargando pinta «Cargando…» por app y ningún botón', (tester) async {
        await _pump(
          tester,
          DailyBriefing(generatedAt: _now, period: BriefingPeriod.morning, bookName: 'Personal'),
          window: window,
        );

        expect(find.text('Cargando…'), findsNWidgets(7));
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('todo al día muestra la frase con la marca y la fila de tasas', (tester) async {
        await _pump(tester, _allClear(), window: window);

        expect(
          find.text('Todo al día: escribiste en el diario, no tienes pagos esta semana y tus hábitos están completos'),
          findsOneWidget,
        );
        expect(find.byType(OrtizSuccessMark), findsOneWidget);
        expect(find.text('Tasas'), findsOneWidget);
        expect(find.text('Diario'), findsNothing);
        expect(find.text('Hábitos'), findsNothing);
      });

      testWidgets('el panel muestra todas las filas, sin «Y n más»', (tester) async {
        await _pump(
          tester,
          _full(payments: [
            for (var i = 1; i <= 5; i++) _payment('p-$i', 'Pago $i', date: DateTime(2026, 11, 17 + i)),
          ]),
          variant: BriefingBlockVariant.panel,
          window: window,
        );

        for (var i = 1; i <= 5; i++) {
          expect(find.text('Pago $i'), findsOneWidget);
        }
        expect(find.textContaining('Y '), findsNothing);
      });
    });
  }

  group('chat', () {
    testWidgets('muestra hasta 3 pagos y «Y n más · total» con «Ver todos»', (tester) async {
      final actions = await _pump(
        tester,
        _full(payments: [
          for (var i = 1; i <= 5; i++) _payment('p-$i', 'Pago $i', date: DateTime(2026, 11, 17 + i), amount: 10),
        ]),
      );

      expect(find.text('Pago 3'), findsOneWidget);
      expect(find.text('Pago 4'), findsNothing);
      expect(find.text(r'Y 2 más · $20.00'), findsOneWidget);

      await _tapText(tester, 'Ver todos');
      expect(actions.single, isA<BriefingViewAll>().having((a) => a.target, 'target', BriefingViewAllTarget.payments));
    });

    testWidgets('muestra hasta 3 recordatorios y «Y n más»', (tester) async {
      await _pump(
        tester,
        _full(reminders: [
          for (var i = 1; i <= 4; i++)
            BriefingReminder(id: 'r-$i', title: 'Recordatorio $i', dueAt: DateTime(2026, 11, 17, 10 + i)),
        ]),
      );

      expect(find.text('Recordatorio 3'), findsOneWidget);
      expect(find.text('Recordatorio 4'), findsNothing);
      expect(find.text('Y 1 más'), findsOneWidget);
    });

    testWidgets('de noche agrupa en «Lo que faltó hoy» y «Lo que viene»', (tester) async {
      await _pump(
        tester,
        _full(period: BriefingPeriod.night, reminders: [
          BriefingReminder(id: 'r-1', title: 'Llamar al banco', dueAt: DateTime(2026, 11, 17, 15, 30)),
          BriefingReminder(id: 'r-2', title: 'Sacar la basura', dueAt: DateTime(2026, 11, 18, 7), isTomorrow: true),
        ]),
      );

      final faltoDy = tester.getTopLeft(find.text('Lo que faltó hoy')).dy;
      final vieneDy = tester.getTopLeft(find.text('Lo que viene')).dy;
      expect(find.text('Hoy no escribiste en el diario.'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Llamar al banco')).dy, inExclusiveRange(faltoDy, vieneDy));
      expect(tester.getTopLeft(find.text('Internet')).dy, greaterThan(vieneDy));
      expect(tester.getTopLeft(find.text('Sacar la basura')).dy, greaterThan(vieneDy));
      expect(find.text('mañana 07:00'), findsOneWidget);
    });

    testWidgets('de mañana no muestra los recordatorios de mañana (Q4)', (tester) async {
      await _pump(
        tester,
        _full(reminders: [
          BriefingReminder(id: 'r-2', title: 'Sacar la basura', dueAt: DateTime(2026, 11, 18, 7), isTomorrow: true),
        ]),
      );

      expect(find.text('Sacar la basura'), findsNothing);
      expect(find.text('Recordatorios'), findsNothing);
    });

    testWidgets('el recordatorio pospuesto muestra «Pospuesto a…» en lugar del botón', (tester) async {
      await _pump(
        tester,
        _full(reminders: [
          BriefingReminder(
            id: 'r-1',
            title: 'Llamar al banco',
            dueAt: DateTime(2026, 11, 17, 15, 30),
            snoozedUntil: DateTime(2026, 11, 17, 16, 30),
          ),
        ]),
      );

      expect(find.text('Pospuesto a las 16:30'), findsOneWidget);
      expect(find.text('Posponer'), findsNothing);
    });

    testWidgets('el abono muestra «Parcial» y «abonaste …» con lo que falta', (tester) async {
      await _pump(
        tester,
        _full(payments: [
          _payment('p-internet', 'Internet', date: DateTime(2026, 11, 19), amount: 10, partialPaid: 15),
        ]),
      );

      expect(find.text('Parcial'), findsOneWidget);
      expect(find.text(r'vence jue 19 · abonaste $15.00'), findsOneWidget);
      expect(find.text(r'$10.00'), findsOneWidget);
    });

    testWidgets('todo al día con el ánimo sin registrar pone «Todo al día» al final del grupo', (tester) async {
      final base = _allClear();
      final briefing = DailyBriefing(
        generatedAt: base.generatedAt,
        period: base.period,
        bookName: base.bookName,
        diario: base.diario,
        mood: const BriefingMood(status: BriefingStatus.ready),
        payments: base.payments,
        birthdays: base.birthdays,
        habits: base.habits,
        reminders: base.reminders,
        rates: base.rates,
      );
      expect(briefing.isAllClear, isTrue);
      await _pump(tester, briefing);

      final moodDy = tester.getTopLeft(find.text('Aún no registras tu ánimo.')).dy;
      final doneDy = tester.getTopLeft(find.textContaining('Todo al día:')).dy;
      expect(doneDy, greaterThan(moodDy));
      expect(tester.getTopLeft(find.text('Tasas')).dy, greaterThan(doneDy));
    });

    testWidgets('todo al día con el ánimo registrado pone «Todo al día» primero', (tester) async {
      final base = _allClear();
      final briefing = DailyBriefing(
        generatedAt: base.generatedAt,
        period: base.period,
        bookName: base.bookName,
        diario: base.diario,
        mood: base.mood,
        payments: base.payments,
        birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
          BriefingBirthday(contactId: 'c-1', name: 'Andrea', date: DateTime(2026, 11, 20), inDays: 3),
        ]),
        habits: base.habits,
        reminders: base.reminders,
        rates: base.rates,
      );
      expect(briefing.isAllClear, isTrue);
      await _pump(tester, briefing);

      final doneDy = tester.getTopLeft(find.textContaining('Todo al día:')).dy;
      expect(tester.getTopLeft(find.text('Andrea cumple el vie 20')).dy, greaterThan(doneDy));
      expect(find.text('Ánimo'), findsNothing);
    });

    testWidgets('con texto grande la acción baja debajo del texto', (tester) async {
      await _pump(tester, _full(), textScale: 2);

      final button = tester.getTopLeft(find.text('Escribir'));
      final title = tester.getBottomLeft(find.text('Aún no escribes hoy.'));
      expect(button.dy, greaterThan(title.dy));
    });

    testWidgets('con texto normal la acción va a la derecha, a la altura de la fila', (tester) async {
      await _pump(tester, _full());

      final button = tester.getTopLeft(find.text('Escribir'));
      final title = tester.getBottomLeft(find.text('Aún no escribes hoy.'));
      expect(button.dy, lessThan(title.dy));
      expect(button.dx, greaterThan(title.dx));
    });
  });

  group('acciones', () {
    testWidgets('cada botón emite su acción', (tester) async {
      final actions = await _pump(tester, _full(payments: const []));

      await _tapText(tester, 'Escribir');
      await _tapText(tester, 'Registrar');
      await _tapText(tester, 'Marcar');
      await tester.ensureVisible(find.text('Ver').first);
      await tester.tap(find.text('Ver').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver').last);
      await tester.tap(find.text('Ver').last);
      await tester.pumpAndSettle();

      expect(actions[0], isA<BriefingWriteDiary>());
      expect(actions[1], isA<BriefingLogMood>());
      expect(actions[2], isA<BriefingMarkHabits>());
      expect(actions[3], isA<BriefingViewContact>().having((a) => a.contactId, 'contactId', 'c-1'));
      expect(actions[4], isA<BriefingViewRates>());
      expect(actions, hasLength(5));
    });

    testWidgets('«Pagar» abre el menú y emite pagar todo o abonar', (tester) async {
      final actions = await _pump(
        tester,
        _full(payments: [_payment('p-internet', 'Internet', date: DateTime(2026, 11, 19))]),
      );

      await _tapText(tester, 'Pagar');
      expect(find.text(r'Pagar todo · $25.00'), findsOneWidget);
      expect(find.text('Abonar una parte'), findsOneWidget);
      await tester.tap(find.text(r'Pagar todo · $25.00'));
      await tester.pumpAndSettle();

      await _tapText(tester, 'Pagar');
      await tester.tap(find.text('Abonar una parte'));
      await tester.pumpAndSettle();

      expect(actions, hasLength(2));
      expect(
        actions[0],
        isA<BriefingPay>()
            .having((a) => a.paymentId, 'paymentId', 'p-internet')
            .having((a) => a.oldestOccurrenceDate, 'fecha', DateTime(2026, 11, 19))
            .having((a) => a.partial, 'partial', false),
      );
      expect(actions[1], isA<BriefingPay>().having((a) => a.partial, 'partial', true));
    });

    testWidgets('cerrar el menú de «Pagar» sin elegir no emite nada', (tester) async {
      final actions = await _pump(
        tester,
        _full(payments: [_payment('p-internet', 'Internet', date: DateTime(2026, 11, 19))]),
      );

      await _tapText(tester, 'Pagar');
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(actions, isEmpty);
    });

    testWidgets('«Posponer» ofrece solo «1 hora» y «Mañana a esta hora»', (tester) async {
      final actions = await _pump(tester, _full(payments: const []));

      await _tapText(tester, 'Posponer');
      expect(find.byType(PopupMenuItem<BriefingSnoozeOption>), findsNWidgets(2));
      await tester.tap(find.text('1 hora'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Posponer');
      await tester.tap(find.text('Mañana a esta hora'));
      await tester.pumpAndSettle();

      expect(
        actions[0],
        isA<BriefingSnooze>()
            .having((a) => a.reminderId, 'reminderId', 'r-1')
            .having((a) => a.delay, 'delay', const Duration(hours: 1)),
      );
      expect(
        actions[1],
        isA<BriefingSnooze>()
            .having((a) => a.option, 'option', BriefingSnoozeOption.tomorrowSameTime)
            .having((a) => a.untilFrom(_now), 'untilFrom', DateTime(2026, 11, 18, 9)),
      );
    });

    testWidgets('el resumen viejo no tiene botones y dice cómo actuar', (tester) async {
      await _pump(tester, _full(), actionsEnabled: false);

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('Resumen del 17/11/2026 a las 09:00. Pide uno nuevo para actuar.'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
    });

    testWidgets('con otro libro activo (otro id) «Pagar» queda desactivado y lo explica', (tester) async {
      // Mismo nombre, otro libro: decide el id, no el nombre.
      await _pump(
        tester,
        _full(payments: [_payment('p-internet', 'Internet', date: DateTime(2026, 11, 19))]),
        activeBookId: 'libro-otro',
        activeBookName: 'Personal',
      );

      final button = find.ancestor(of: find.text('Pagar'), matching: find.byType(OutlinedButton));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(find.text('Cambia al libro Personal para pagarlo.'), findsOneWidget);
    });

    testWidgets('con el mismo libro (mismo id) «Pagar» sigue activo aunque cambie el nombre', (tester) async {
      await _pump(
        tester,
        _full(payments: [_payment('p-internet', 'Internet', date: DateTime(2026, 11, 19))]),
        activeBookId: 'libro-personal',
        activeBookName: 'Personal renombrado',
      );

      final button = find.ancestor(of: find.text('Pagar'), matching: find.byType(OutlinedButton));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(find.textContaining('Cambia al libro'), findsNothing);
    });

    testWidgets('con varias ocurrencias «Pagar» ofrece pagar la más antigua con su monto', (tester) async {
      await _pump(
        tester,
        _full(payments: [
          BriefingPayment(
            paymentId: 'p-internet',
            name: 'Internet',
            oldestOccurrenceDate: DateTime(2026, 11, 3),
            occurrenceCount: 3,
            overdueCount: 2,
            remaining: _amount(75, CurrencyType.usd),
            oldestRemaining: _amount(25, CurrencyType.usd),
          ),
        ]),
      );

      await _tapText(tester, 'Pagar');
      // Misma fecha que la fila («venció el mar 3»).
      expect(find.text('venció el mar 3'), findsOneWidget);
      expect(find.text(r'Pagar el del mar 3 · $25.00'), findsOneWidget);
      expect(find.text('Abonar al del mar 3'), findsOneWidget);
      expect(find.textContaining('Pagar todo'), findsNothing);
      expect(find.text('Abonar una parte'), findsNothing);
    });

    testWidgets('con varias ocurrencias y sin el monto de la más antigua, la opción va sin monto', (tester) async {
      await _pump(
        tester,
        _full(payments: [
          BriefingPayment(
            paymentId: 'p-internet',
            name: 'Internet',
            oldestOccurrenceDate: DateTime(2026, 11, 3),
            occurrenceCount: 2,
            overdueCount: 2,
            remaining: _amount(50, CurrencyType.usd),
          ),
        ]),
      );

      await _tapText(tester, 'Pagar');
      expect(find.text('Pagar el del mar 3'), findsOneWidget);
      expect(find.text('Abonar al del mar 3'), findsOneWidget);
    });

    testWidgets('un resumen guardado sin datos solo dice de cuándo es y cómo actuar', (tester) async {
      final stored = DailyBriefing.fromArtifactMetadata({
        'generatedAt': _now.toIso8601String(),
        'period': 'morning',
      });
      await _pump(tester, stored, actionsEnabled: false);

      expect(find.text('Resumen del 17/11/2026 a las 09:00. Pide uno nuevo para actuar.'), findsOneWidget);
      expect(find.textContaining('No pude leer'), findsNothing);
      expect(find.text('Tasas'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('un resumen vivo con todas las secciones sin leer pinta «No pude leer…» por app', (tester) async {
      const unavailable = BriefingStatus.unavailable;
      final live = DailyBriefing(
        generatedAt: _now,
        period: BriefingPeriod.morning,
        bookName: 'Personal',
        diario: const BriefingDiario(status: unavailable),
        mood: const BriefingMood(status: unavailable),
        payments: const BriefingPayments(status: unavailable),
        birthdays: const BriefingBirthdays(status: unavailable),
        habits: const BriefingHabits(status: unavailable),
        reminders: const BriefingReminders(status: unavailable),
        rates: const BriefingRates(status: unavailable),
      );
      expect(live.rowsOmitted, isFalse);
      await _pump(tester, live);

      expect(find.textContaining('No pude leer'), findsNWidgets(7));
      expect(find.text('No pude leer las tasas.'), findsOneWidget);
      expect(find.textContaining('Pide uno nuevo para actuar'), findsNothing);
    });

    testWidgets('los cumpleaños salen por cercanía aunque lleguen desordenados', (tester) async {
      final base = _full();
      await _pump(
        tester,
        DailyBriefing(
          generatedAt: base.generatedAt,
          period: base.period,
          bookName: base.bookName,
          diario: base.diario,
          mood: base.mood,
          payments: base.payments,
          birthdays: BriefingBirthdays(status: BriefingStatus.ready, items: [
            BriefingBirthday(contactId: 'c-1', name: 'Andrea', date: DateTime(2026, 11, 20), inDays: 3),
            BriefingBirthday(contactId: 'c-2', name: 'Bruno', date: DateTime(2026, 11, 17), inDays: 0),
          ]),
          habits: base.habits,
          reminders: base.reminders,
          rates: base.rates,
        ),
        variant: BriefingBlockVariant.panel,
      );

      final bruno = tester.getTopLeft(find.text('Bruno cumple hoy')).dy;
      expect(tester.getTopLeft(find.text('Andrea cumple el vie 20')).dy, greaterThan(bruno));
    });

    testWidgets('el botón lleva la etiqueta completa para el lector', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _full());

      expect(find.bySemanticsLabel('Pagar Internet'), findsOneWidget);
      expect(find.bySemanticsLabel('Ver contacto de Andrea'), findsOneWidget);
      expect(find.bySemanticsLabel('Posponer Llamar al banco'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('BriefingSnoozeOption.untilFrom', () {
    test('«1 hora» suma una hora a ahora', () {
      final now = DateTime(2026, 11, 17, 9, 30);
      expect(BriefingSnoozeOption.oneHour.untilFrom(now), DateTime(2026, 11, 17, 10, 30));
    });

    test('«Mañana a esta hora» va al día siguiente a la misma hora de reloj', () {
      expect(
        BriefingSnoozeOption.tomorrowSameTime.untilFrom(DateTime(2026, 11, 17, 9, 30)),
        DateTime(2026, 11, 18, 9, 30),
      );
      // Cambio de mes.
      expect(
        BriefingSnoozeOption.tomorrowSameTime.untilFrom(DateTime(2026, 11, 30, 22, 15)),
        DateTime(2026, 12, 1, 22, 15),
      );
    });

    test('«Mañana a esta hora» conserva la hora de reloj aunque el día no dure 24 h', () {
      // En zonas con horario de verano, el 1 nov 2026 dura 25 h; sumar 24 h
      // daría las 08:30. Donde no hay cambio de hora, el resultado es igual.
      final until = BriefingSnoozeOption.tomorrowSameTime.untilFrom(DateTime(2026, 10, 31, 9, 30));
      expect(until.day, 1);
      expect(until.month, 11);
      expect(until.hour, 9);
      expect(until.minute, 30);
    });
  });

  group('BriefingScanIndicator', () {
    Color? fillOf(WidgetTester tester, SuiteApp app) {
      final container = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.text(app.label), matching: find.byType(AnimatedContainer)),
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    testWidgets('dice «Revisando tus apps» y enciende las 5 apps escalonadas', (tester) async {
      await pumpApp(tester, const BriefingScanIndicator(), settle: false);

      expect(find.text('Revisando tus apps'), findsOneWidget);
      for (final app in SuiteApp.values) {
        expect(find.text(app.label), findsOneWidget);
      }
      expect(fillOf(tester, SuiteApp.notas), isNot(SuiteApp.notas.color));

      await tester.pumpAndSettle();
      for (final app in SuiteApp.values) {
        expect(fillOf(tester, app), app.color, reason: app.label);
      }
    });

    testWidgets('no enciende una app cuyos datos no llegaron', (tester) async {
      await pumpApp(tester, const BriefingScanIndicator(readyApps: {SuiteApp.finanzas, SuiteApp.diario}));

      expect(fillOf(tester, SuiteApp.finanzas), SuiteApp.finanzas.color);
      expect(fillOf(tester, SuiteApp.habitos), isNot(SuiteApp.habitos.color));
    });

    testWidgets('con reducir movimiento aparecen todas encendidas a la vez', (tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const BriefingScanIndicator(),
          ),
        ),
        settle: false,
      );

      for (final app in SuiteApp.values) {
        expect(fillOf(tester, app), app.color, reason: app.label);
      }
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
