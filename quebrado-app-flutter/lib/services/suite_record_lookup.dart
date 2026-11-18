import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diario/models/diario_contact.dart';
import '../diario/models/diario_entry.dart';
import '../diario/viewmodels/diario_state.dart';
import '../habitos/models/habit_model.dart';
import '../habitos/viewmodels/habitos_state.dart';
import '../notas/models/note_item.dart';
import '../notas/viewmodels/notas_state.dart';
import '../quebrado/models/transaction.dart';
import '../quebrado/viewmodels/app_state.dart';
import '../recordatorios/models/reminder_model.dart';
import '../recordatorios/viewmodels/reminders_state.dart';

/// Resultado de buscar un registro por id para abrirlo desde una URL
/// (`docs/design/rutas.md` §2 y §10, P-01/P-03).
sealed class SuiteLookupResult<T> {
  const SuiteLookupResult();
}

/// El registro existe y se puede abrir.
final class SuiteRecordFound<T> extends SuiteLookupResult<T> {
  const SuiteRecordFound(this.record);

  final T record;
}

/// El movimiento existe, pero en otro libro (no el activo). No se cambia de
/// libro: se avisa con [notice] (P-01).
final class SuiteRecordInOtherBook<T> extends SuiteLookupResult<T> {
  const SuiteRecordInOtherBook({required this.bookId, required this.bookName});

  final String bookId;
  final String bookName;

  String get notice => 'Ese movimiento está en el libro $bookName';
}

/// No hay ningún registro con ese id: se avisa con [notice] y se abre la raíz
/// de su app (P-03).
final class SuiteRecordMissing<T> extends SuiteLookupResult<T> {
  const SuiteRecordMissing();

  static const String notice = 'No encontré ese registro';
}

/// Busca registros por id sobre los getters públicos de los ViewModels,
/// esperando antes a que el módulo termine de cargar.
///
/// - Las funciones `find…` son puras y síncronas (para el `pageBuilder` del
///   router, cuando los datos ya están en memoria).
/// - Las funciones asíncronas ([transaction], [diarioEntry], [habit],
///   [reminder], [note]) esperan la carga y luego buscan (para el `redirect`).
abstract final class SuiteRecordLookup {
  /// Tiempo máximo que se espera a que un módulo termine de cargar. Si se
  /// agota, se busca igualmente en lo que haya en memoria.
  static const Duration defaultLoadTimeout = Duration(seconds: 20);

  /// Busca [id] en [records].
  static SuiteLookupResult<T> find<T>(
    Iterable<T> records,
    String id,
    String Function(T record) idOf,
  ) {
    for (final record in records) {
      if (idOf(record) == id) return SuiteRecordFound<T>(record);
    }
    return SuiteRecordMissing<T>();
  }

  /// Busca un movimiento primero en el libro activo y, si no está, en los
  /// demás libros que haya en memoria ([transactionsByBook], id del libro →
  /// movimientos). [books] son los perfiles de `AppState.profiles`
  /// (`{'id': …, 'name': …}`).
  static SuiteLookupResult<Transaction> findTransaction({
    required String id,
    required String activeBookId,
    required List<Transaction> activeBook,
    required Map<String, List<Transaction>> transactionsByBook,
    required List<Map<String, String>> books,
  }) {
    final inActive = find<Transaction>(activeBook, id, (t) => t.id);
    if (inActive is SuiteRecordFound<Transaction>) return inActive;

    for (final entry in transactionsByBook.entries) {
      if (entry.key == activeBookId) continue;
      if (entry.value.any((t) => t.id == id)) {
        return SuiteRecordInOtherBook<Transaction>(
          bookId: entry.key,
          bookName: _bookName(books, entry.key),
        );
      }
    }
    return const SuiteRecordMissing<Transaction>();
  }

  static String _bookName(List<Map<String, String>> books, String bookId) {
    for (final book in books) {
      if (book['id'] == bookId) {
        final name = book['name']?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return bookId;
  }

  /// Completa cuando [isLoading] es `false`, escuchando a [source]. Si ya lo
  /// es, completa enseguida. Tras [timeout] completa igualmente.
  static Future<void> waitUntilLoaded(
    Listenable source,
    bool Function() isLoading, {
    Duration timeout = defaultLoadTimeout,
  }) {
    if (!isLoading()) return Future<void>.value();

    final completer = Completer<void>();
    void check() {
      if (!isLoading() && !completer.isCompleted) completer.complete();
    }

    source.addListener(check);
    return completer.future
        .timeout(timeout, onTimeout: () {})
        .whenComplete(() => source.removeListener(check));
  }

  /// Movimiento de Finanzas. Espera `AppState.loadData()` (idempotente: si la
  /// carga ya está en curso, espera esa misma).
  static Future<SuiteLookupResult<Transaction>> transaction(
    AppState app,
    String id,
  ) async {
    await app.loadData();
    return findTransaction(
      id: id,
      activeBookId: app.activeDbName,
      activeBook: app.transactions,
      transactionsByBook: app.transactionsByBook,
      books: app.profiles,
    );
  }

  /// Entrada del Diario.
  static Future<SuiteLookupResult<DiarioEntry>> diarioEntry(
    DiarioState state,
    String id, {
    Duration timeout = defaultLoadTimeout,
  }) async {
    await waitUntilLoaded(state, () => state.isLoading, timeout: timeout);
    return find<DiarioEntry>(state.entries, id, (e) => e.id);
  }

  /// Contacto del Diario (ficha `/diario/contactos/:id`).
  static Future<SuiteLookupResult<DiarioContact>> diarioContact(
    DiarioState state,
    String id, {
    Duration timeout = defaultLoadTimeout,
  }) async {
    await waitUntilLoaded(state, () => state.isLoading, timeout: timeout);
    return find<DiarioContact>(state.contacts, id, (c) => c.id);
  }

  /// Hábito (también los archivados).
  static Future<SuiteLookupResult<HabitModel>> habit(
    HabitosState state,
    String id, {
    Duration timeout = defaultLoadTimeout,
  }) async {
    await waitUntilLoaded(state, () => state.isLoading, timeout: timeout);
    return find<HabitModel>(state.habits, id, (h) => h.id);
  }

  /// Recordatorio.
  static Future<SuiteLookupResult<ReminderModel>> reminder(
    RemindersState state,
    String id, {
    Duration timeout = defaultLoadTimeout,
  }) async {
    await waitUntilLoaded(state, () => state.isLoading, timeout: timeout);
    return find<ReminderModel>(state.allReminders, id, (r) => r.id);
  }

  /// Nota.
  static Future<SuiteLookupResult<NoteItem>> note(
    NotasState state,
    String id, {
    Duration timeout = defaultLoadTimeout,
  }) async {
    await waitUntilLoaded(state, () => state.isLoading, timeout: timeout);
    final note = state.getNoteById(id);
    return note == null ? SuiteRecordMissing<NoteItem>() : SuiteRecordFound<NoteItem>(note);
  }
}
