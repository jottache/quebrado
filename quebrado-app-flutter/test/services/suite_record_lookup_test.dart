import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart';
import 'package:quebrado_app_flutter/diario/services/diario_supabase_service.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/habitos/services/habitos_supabase_service.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/notas/viewmodels/notas_state.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';
import 'package:quebrado_app_flutter/quebrado/models/transaction.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';
import 'package:quebrado_app_flutter/recordatorios/services/reminders_supabase_service.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';
import 'package:quebrado_app_flutter/services/suite_record_lookup.dart';

Transaction _mov(String id) => Transaction(
      id: id,
      date: DateTime(2026, 11, 17, 12),
      amount: 12.5,
      currency: CurrencyType.usd,
      note: 'Café',
      type: TransactionType.expense,
      exchangeRate: 1,
    );

/// Diario sin Supabase cuyas entradas llegan cuando el test lo decide.
class _SlowDiarioService extends DiarioSupabaseService {
  _SlowDiarioService() : super.forTesting();

  final Completer<List<DiarioEntry>> entries = Completer<List<DiarioEntry>>();

  @override
  bool get isReady => false;

  @override
  Future<List<DiarioEntry>> getEntries() => entries.future;
}

/// Diario sin Supabase cuyos contactos llegan cuando el test lo decide.
class _SlowContactsService extends DiarioSupabaseService {
  _SlowContactsService() : super.forTesting();

  final Completer<List<DiarioContact>> contacts = Completer<List<DiarioContact>>();

  @override
  bool get isReady => false;

  @override
  Future<List<DiarioContact>> getContacts() => contacts.future;
}

class _SlowHabitosService extends HabitosSupabaseService {
  _SlowHabitosService() : super(client: null);

  final Completer<HabitosBootstrapData> data = Completer<HabitosBootstrapData>();

  @override
  Future<HabitosBootstrapData> bootstrapData() => data.future;
}

class _FakeRemindersService extends RemindersSupabaseService {
  _FakeRemindersService(this.reminders) : super(client: null);

  final List<ReminderModel> reminders;

  @override
  Future<List<ReminderModel>> fetchReminders() async => reminders;
}

class _Loader extends ChangeNotifier {
  bool loading = true;

  bool get listening => hasListeners;

  void finish() {
    loading = false;
    notifyListeners();
  }
}

void main() {
  group('find', () {
    test('devuelve el registro con ese id', () {
      final result = SuiteRecordLookup.find<Transaction>([_mov('a'), _mov('b')], 'b', (t) => t.id);

      expect(result, isA<SuiteRecordFound<Transaction>>());
      expect((result as SuiteRecordFound<Transaction>).record.id, 'b');
    });

    test('devuelve «no existe» si ningún registro tiene ese id', () {
      final result = SuiteRecordLookup.find<Transaction>([_mov('a')], 'zzz', (t) => t.id);

      expect(result, isA<SuiteRecordMissing<Transaction>>());
    });
  });

  group('findTransaction', () {
    final books = [
      {'id': 'quebrado.db', 'name': 'Personal'},
      {'id': 'negocio.db', 'name': 'Negocio'},
    ];

    test('encuentra el movimiento en el libro activo', () {
      final result = SuiteRecordLookup.findTransaction(
        id: 'm1',
        activeBookId: 'quebrado.db',
        activeBook: [_mov('m1')],
        transactionsByBook: {'negocio.db': [_mov('m2')]},
        books: books,
      );

      expect((result as SuiteRecordFound<Transaction>).record.id, 'm1');
    });

    test('si está en otro libro dice en cuál, con el aviso de P-01', () {
      final result = SuiteRecordLookup.findTransaction(
        id: 'm2',
        activeBookId: 'quebrado.db',
        activeBook: [_mov('m1')],
        transactionsByBook: {
          'quebrado.db': [_mov('m1')],
          'negocio.db': [_mov('m2')],
        },
        books: books,
      );

      expect(result, isA<SuiteRecordInOtherBook<Transaction>>());
      final other = result as SuiteRecordInOtherBook<Transaction>;
      expect(other.bookId, 'negocio.db');
      expect(other.bookName, 'Negocio');
      expect(other.notice, 'Ese movimiento está en el libro Negocio');
    });

    test('no mira la copia en caché del libro activo, sino su lista viva', () {
      final result = SuiteRecordLookup.findTransaction(
        id: 'borrado',
        activeBookId: 'quebrado.db',
        activeBook: [_mov('m1')],
        transactionsByBook: {'quebrado.db': [_mov('borrado')]},
        books: books,
      );

      expect(result, isA<SuiteRecordMissing<Transaction>>());
    });

    test('si no está en ningún libro devuelve «no existe», con el aviso de P-03', () {
      final result = SuiteRecordLookup.findTransaction(
        id: 'nada',
        activeBookId: 'quebrado.db',
        activeBook: [_mov('m1')],
        transactionsByBook: {'negocio.db': [_mov('m2')]},
        books: books,
      );

      expect(result, isA<SuiteRecordMissing<Transaction>>());
      expect(SuiteRecordMissing.notice, 'No encontré ese registro');
    });

    test('sin nombre de libro usa su id', () {
      final result = SuiteRecordLookup.findTransaction(
        id: 'm3',
        activeBookId: 'quebrado.db',
        activeBook: const [],
        transactionsByBook: {'viejo.db': [_mov('m3')]},
        books: books,
      );

      expect((result as SuiteRecordInOtherBook<Transaction>).bookName, 'viejo.db');
    });
  });

  group('waitUntilLoaded', () {
    test('completa enseguida si ya cargó', () async {
      await SuiteRecordLookup.waitUntilLoaded(_Loader()..loading = false, () => false);
    });

    test('espera a que termine la carga y deja de escuchar', () async {
      final loader = _Loader();
      var done = false;
      final future = SuiteRecordLookup.waitUntilLoaded(loader, () => loader.loading)
          .then((_) => done = true);

      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      loader.finish();
      await future;
      expect(done, isTrue);
      expect(loader.listening, isFalse);
    });

    test('tras el tiempo máximo completa aunque siga cargando', () async {
      final loader = _Loader();

      await SuiteRecordLookup.waitUntilLoaded(
        loader,
        () => loader.loading,
        timeout: const Duration(milliseconds: 10),
      );

      expect(loader.loading, isTrue);
      expect(loader.listening, isFalse);
    });
  });

  group('con los ViewModels (sin Supabase)', () {
    setUp(() => AppState.debugLocalDbIsSourceOfTruth = false);
    tearDown(() => AppState.debugLocalDbIsSourceOfTruth = null);

    test('movimiento: espera la carga de AppState y busca en el libro activo', () async {
      final app = AppState();
      await app.loadData();
      final id = 'mov_lookup_${DateTime.now().microsecondsSinceEpoch}';
      app.transactions = [...app.transactions, _mov(id)];

      final found = await SuiteRecordLookup.transaction(app, id);
      final missing = await SuiteRecordLookup.transaction(app, '${id}_no');

      expect((found as SuiteRecordFound<Transaction>).record.id, id);
      expect(missing, isA<SuiteRecordMissing<Transaction>>());
    });

    test('entrada del Diario: no busca hasta que terminó la carga', () async {
      final service = _SlowDiarioService();
      final state = DiarioState(service: service);
      final pending = SuiteRecordLookup.diarioEntry(state, 'e1');

      service.entries.complete([
        DiarioEntry(id: 'e1', contactId: 'c1', categoryId: 'cat_x', title: 'Cena'),
      ]);
      final result = await pending;

      expect((result as SuiteRecordFound<DiarioEntry>).record.title, 'Cena');
      expect(await SuiteRecordLookup.diarioEntry(state, 'e2'), isA<SuiteRecordMissing<DiarioEntry>>());
    });

    test('contacto del Diario: no busca hasta que terminó la carga', () async {
      final service = _SlowContactsService();
      final state = DiarioState(service: service);
      final pending = SuiteRecordLookup.diarioContact(state, 'c_ana');

      service.contacts.complete([DiarioContact(id: 'c_ana', name: 'Ana')]);
      final result = await pending;

      expect((result as SuiteRecordFound<DiarioContact>).record.name, 'Ana');
      expect(
        await SuiteRecordLookup.diarioContact(state, 'c_otro'),
        isA<SuiteRecordMissing<DiarioContact>>(),
      );
    });

    test('hábito: no busca hasta que terminó la carga', () async {
      final service = _SlowHabitosService();
      final state = HabitosState(service: service);
      final pending = SuiteRecordLookup.habit(state, 'h1');

      service.data.complete(HabitosBootstrapData(
        habits: [HabitModel(id: 'h1', title: 'Leer', archived: true)],
        stacks: const [],
        logs: const [],
      ));
      final result = await pending;

      expect((result as SuiteRecordFound<HabitModel>).record.title, 'Leer');
      expect(await SuiteRecordLookup.habit(state, 'h2'), isA<SuiteRecordMissing<HabitModel>>());
    });

    test('recordatorio: encuentra el cargado y «no existe» para otro id', () async {
      final state = RemindersState(
        service: _FakeRemindersService([ReminderModel(id: 'r1', title: 'Pagar luz')]),
      );

      final found = await SuiteRecordLookup.reminder(state, 'r1');
      final missing = await SuiteRecordLookup.reminder(state, 'r2');

      expect((found as SuiteRecordFound<ReminderModel>).record.title, 'Pagar luz');
      expect(missing, isA<SuiteRecordMissing<ReminderModel>>());
    });

    test('nota: «no existe» si no está cargada', () async {
      final state = NotasState()..loadAll();

      final result = await SuiteRecordLookup.note(state, 'nota_que_no_existe');

      expect(state.isLoading, isFalse);
      expect(result, isA<SuiteRecordMissing>());
    });
  });
}
