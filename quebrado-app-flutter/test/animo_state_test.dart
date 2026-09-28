import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';

class FakeAnimoService extends AnimoSupabaseService {
  FakeAnimoService() : super.forTesting();

  final Map<String, MoodLog> remote = {};
  bool failWrites = false;
  int saveCalls = 0;

  @override
  bool get isReady => true;

  @override
  Future<List<MoodLog>> getLogs({DateTime? since}) async => remote.values.toList();

  @override
  Future<void> saveLog(MoodLog log) async {
    saveCalls++;
    if (failWrites) throw Exception('sin red');
    remote[log.id] = log;
  }

  @override
  Future<void> deleteLog(String id) async {
    if (failWrites) throw Exception('sin red');
    remote.remove(id);
  }

  @override
  Future<List<MoodTag>> getTags() async => MoodTag.defaultTags();

  @override
  Future<void> saveTag(MoodTag tag) async {}
}

class MemoryPendingStore implements MoodPendingStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String v) async => value = v;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 28, 12, 0);
  late FakeAnimoService service;
  late MemoryPendingStore store;
  late AnimoState state;

  AnimoState buildState() => AnimoState(service: service, pendingStore: store, clock: () => now);

  setUp(() {
    service = FakeAnimoService();
    store = MemoryPendingStore();
    state = buildState();
  });

  group('MoodLog y catálogo', () {
    test('toSupabaseMap / fromMap conservan los datos y la fecha local', () {
      final log = MoodLog(
        id: 'm1',
        valence: 1,
        energy: 4,
        emotions: ['motivado'],
        tagIds: ['mtag_ejercicio'],
        roleIds: ['r1'],
        mentionedContactIds: ['c1'],
        note: '  Buen día  ',
        loggedAt: DateTime(2026, 9, 27, 23, 50),
      );
      final map = log.toSupabaseMap();
      expect(map['log_date'], '2026-09-27');
      expect(map['contact_id'], isNull);
      expect(map['perspective'], 'self');
      expect(map['note'], 'Buen día');

      final back = MoodLog.fromMap(map);
      expect(back.valence, 1);
      expect(back.energy, 4);
      expect(back.emotions, ['motivado']);
      expect(back.tagIds, ['mtag_ejercicio']);
      expect(back.logDateKey, '2026-09-27');
    });

    test('la perspectiva se normaliza según haya contacto o no', () {
      expect(MoodLog(id: 'a', valence: 0, perspective: MoodPerspective.told).perspective, MoodPerspective.self);
      expect(MoodLog(id: 'b', valence: 0, contactId: 'c1').perspective, MoodPerspective.observed);
      expect(MoodLog(id: 'c', valence: 0, contactId: 'c1', perspective: MoodPerspective.told).perspective,
          MoodPerspective.told);
    });

    test('la valencia y la energía se limitan a su rango', () {
      final log = MoodLog(id: 'x', valence: 7, energy: 9);
      expect(log.valence, 2);
      expect(log.energy, 5);
    });

    test('los cuadrantes sugeridos siguen valencia y energía', () {
      expect(MoodCatalog.suggestedQuadrants(valence: 2, energy: 5), [MoodQuadrant.highPleasant]);
      expect(MoodCatalog.suggestedQuadrants(valence: -1, energy: 1), [MoodQuadrant.lowUnpleasant]);
      expect(MoodCatalog.suggestedQuadrants(valence: -2).toSet(),
          {MoodQuadrant.highUnpleasant, MoodQuadrant.lowUnpleasant});
      expect(MoodCatalog.suggestedQuadrants(valence: 0).length, 4);
    });
  });

  group('AnimoState · valor del día y rachas', () {
    test('un balance daily manda sobre el promedio de momentáneos', () async {
      await state.addLog(valence: 2, loggedAt: DateTime(2026, 9, 28, 9));
      await state.addLog(valence: 0, loggedAt: DateTime(2026, 9, 28, 10));
      expect(state.dayValence(now), 1.0);

      await state.addLog(valence: -1, kind: MoodKind.daily, loggedAt: DateTime(2026, 9, 28, 11));
      expect(state.dayValence(now), -1.0);
      expect(state.dayValence(DateTime(2026, 9, 20)), isNull);
    });

    test('un segundo daily el mismo día actualiza el existente', () async {
      await state.addLog(valence: 1, kind: MoodKind.daily);
      await state.addLog(valence: -2, kind: MoodKind.daily, note: 'Cambió el día');
      final dailies = state.logs.where((l) => l.isDaily).toList();
      expect(dailies.length, 1);
      expect(dailies.first.valence, -2);
      expect(dailies.first.note, 'Cambió el día');
    });

    test('el ánimo propio y el de contactos no se mezclan', () async {
      await state.addLog(valence: 2);
      await state.addLog(valence: -2, contactId: 'c1');
      expect(state.dayValence(now), 2.0);
      expect(state.dayValence(now, contactId: 'c1'), -2.0);
      expect(state.todaySelfLogs().length, 1);
      expect(state.latestFor('c1')!.perspective, MoodPerspective.observed);
    });

    test('la racha cuenta hasta hoy o hasta ayer y se corta con un hueco', () async {
      expect(state.selfLoggingStreak, 0);
      await state.addLog(valence: 1, loggedAt: DateTime(2026, 9, 27, 20));
      await state.addLog(valence: 1, loggedAt: DateTime(2026, 9, 26, 20));
      expect(state.selfLoggingStreak, 2, reason: 'hoy aún no hay registro: cuenta desde ayer');

      await state.addLog(valence: 1, loggedAt: DateTime(2026, 9, 24, 20));
      expect(state.selfLoggingStreak, 2, reason: 'el 25 falta: la racha no llega al 24');

      await state.addLog(valence: 1);
      expect(state.selfLoggingStreak, 3);
      expect(state.selfLoggedDaysCount, 4);
    });

    test('los registros de contacto no cuentan para la racha propia', () async {
      await state.addLog(valence: 1, contactId: 'c1');
      expect(state.selfLoggingStreak, 0);
      expect(state.hasSelfLogToday, isFalse);
    });

    test('dailySeries y averageValence respetan la ventana', () async {
      await state.addLog(valence: 2, loggedAt: DateTime(2026, 9, 28, 8));
      await state.addLog(valence: -2, loggedAt: DateTime(2026, 9, 22, 8));
      await state.addLog(valence: -2, loggedAt: DateTime(2026, 9, 1, 8));
      final series = state.dailySeries(days: 7);
      expect(series.keys, ['2026-09-22', '2026-09-28']);
      expect(state.averageValence(days: 7), 0.0);
    });

    test('topEmotions ordena por frecuencia', () async {
      await state.addLog(valence: -1, emotions: ['cansado', 'estresado']);
      await state.addLog(valence: -1, emotions: ['cansado']);
      final top = state.topEmotions();
      expect(top.first.emotion.key, 'cansado');
      expect(top.first.count, 2);
    });
  });

  group('AnimoState · CRUD optimista y cola pendiente', () {
    test('las fechas futuras se limitan a ahora y se guardan máximo 3 emociones', () async {
      final log = await state.addLog(
        valence: 1,
        loggedAt: now.add(const Duration(days: 2)),
        emotions: ['alegre', 'motivado', 'orgulloso', 'inspirado'],
      );
      expect(log.loggedAt, now);
      expect(log.emotions.length, 3);
    });

    test('si falla la red el registro queda en memoria y en la cola, y luego se sincroniza', () async {
      service.failWrites = true;
      final log = await state.addLog(valence: -1, note: 'sin señal');

      expect(state.logs.single.id, log.id);
      expect(state.pendingCount, 1);
      expect(state.isPending(log.id), isTrue);
      expect(store.value, contains(log.id));

      service.failWrites = false;
      final left = await state.syncPending();
      expect(left, 0);
      expect(service.remote.containsKey(log.id), isTrue);
      expect(state.isPending(log.id), isFalse);
    });

    test('loadAll restaura la cola local y la mezcla con lo remoto', () async {
      service.failWrites = true;
      final pendingLog = await state.addLog(valence: 2);
      service.remote['remoto'] = MoodLog(id: 'remoto', valence: -1, loggedAt: DateTime(2026, 9, 27, 10));

      // Nueva instancia (reinicio de la app) con la misma cola persistida.
      final restarted = buildState();
      await restarted.loadAll();
      expect(restarted.logs.map((l) => l.id).toSet(), {pendingLog.id, 'remoto'});
      expect(restarted.pendingCount, 1);

      service.failWrites = false;
      await restarted.syncPending();
      expect(restarted.pendingCount, 0);
    });

    test('eliminar y deshacer', () async {
      final log = await state.addLog(valence: 1);
      final removed = await state.deleteLog(log.id);
      expect(removed?.id, log.id);
      expect(state.logs, isEmpty);
      expect(service.remote.containsKey(log.id), isFalse);

      await state.restoreLog(removed!);
      expect(state.logs.single.id, log.id);
      expect(service.remote.containsKey(log.id), isTrue);
    });

    test('un borrado sin red queda pendiente y no reaparece al recargar', () async {
      final log = await state.addLog(valence: 1);
      service.failWrites = true;
      await state.deleteLog(log.id);
      expect(state.pendingCount, 1);

      final restarted = buildState();
      await restarted.loadAll();
      expect(restarted.logs.where((l) => l.id == log.id), isEmpty);
    });

    test('removeLogsForContact borra su ánimo y lo quita de las menciones', () async {
      await state.addLog(valence: 1, contactId: 'c1');
      await state.addLog(valence: 0, mentionedContactIds: ['c1', 'c2']);
      state.removeLogsForContact('c1');
      expect(state.logsFor(contactId: 'c1'), isEmpty);
      expect(state.logs.single.mentionedContactIds, ['c2']);
    });

    test('addTag no duplica etiquetas con el mismo nombre', () async {
      await state.loadAll();
      final a = await state.addTag(name: 'Terapia');
      final b = await state.addTag(name: 'terapia ');
      expect(a.id, b.id);
    });
  });

  group('Widgets de ánimo', () {
    Widget wrap(Widget child, AnimoState animo, {DiarioState? diario}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AnimoState>.value(value: animo),
          if (diario != null) ChangeNotifierProvider<DiarioState>.value(value: diario),
        ],
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
      );
    }

    testWidgets('MoodQuickBar guarda con un toque y ofrece agregar detalle', (tester) async {
      await tester.pumpWidget(wrap(const MoodQuickBar(), state));
      await tester.tap(find.byKey(const ValueKey('mood_quick_self_2')));
      await tester.pump();

      expect(state.logs.single.valence, 2);
      expect(state.logs.single.isSelf, isTrue);
      expect(find.text('Agregar detalle'), findsOneWidget);
    });

    testWidgets('MoodQuickBar de un contacto registra ánimo percibido', (tester) async {
      await tester.pumpWidget(wrap(const MoodQuickBar(contactId: 'c1'), state));
      await tester.tap(find.byKey(const ValueKey('mood_quick_c1_-1')));
      await tester.pump();

      final log = state.logs.single;
      expect(log.contactId, 'c1');
      expect(log.perspective, MoodPerspective.observed);
    });

    testWidgets('MoodTodayCard no se dibuja sin AnimoState', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MoodTodayCard())));
      expect(find.text('¿Cómo te sientes hoy?'), findsNothing);
    });

    testWidgets('MoodTodayCard muestra el resumen del día', (tester) async {
      await state.addLog(valence: 1);
      await tester.pumpWidget(wrap(const MoodTodayCard(), state));
      expect(find.text('Hoy: Bien'), findsOneWidget);
    });

    testWidgets('MoodCheckinSheet guarda valencia, emoción y balance del día', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ChangeNotifierProvider<AnimoState>.value(
        value: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const Scaffold(body: MoodCheckinSheet())),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Elige cómo te sientes'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mood_sheet_valence_-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cansado'));
      await tester.tap(find.text('Es mi balance del día'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mood_sheet_save')));
      await tester.pumpAndSettle();

      final log = state.logs.single;
      expect(log.valence, -1);
      expect(log.emotions, ['cansado']);
      expect(log.isDaily, isTrue);
      expect(find.byType(MoodCheckinSheet), findsNothing);
    });

    testWidgets('ContactMoodSection muestra el prefijo de ánimo percibido', (tester) async {
      final contact = DiarioContact(id: 'c1', name: 'Mariana Dávila');
      await tester.pumpWidget(wrap(ContactMoodSection(contact: contact), state));
      expect(find.text('Ánimo percibido'), findsOneWidget);
      expect(find.textContaining('¿Cómo viste a Mariana?'), findsOneWidget);
    });
  });
}
