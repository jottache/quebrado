import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';

/// Servicio sin red: guarda en memoria lo que recibe.
class _FakeDiarioService extends DiarioSupabaseService {
  _FakeDiarioService() : super.forTesting();

  final Map<String, DiarioEntry> saved = {};

  @override
  bool get isReady => false;

  @override
  Future<void> saveEntry(DiarioEntry entry) async => saved[entry.id] = entry;
}

/// Espera a que termine la carga inicial que lanza el constructor (si no, la pisa).
Future<DiarioState> _loaded(_FakeDiarioService service) async {
  final state = DiarioState(service: service);
  while (state.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
  return state;
}

void main() {
  // Spec 02, paso 6: el editor devuelve la entrada guardada para mostrar «Ver».
  test('addEntry devuelve la entrada creada con su id, la misma que queda en la lista y se guarda', () async {
    final service = _FakeDiarioService();
    final state = await _loaded(service);

    final created = await state.addEntry(contactId: 'c1', categoryId: 'cat_gustos', title: ' Cena ');

    expect(created.id, isNotEmpty);
    expect(created.title, 'Cena');
    expect(created.contactId, 'c1');
    expect(state.entries.any((e) => e.id == created.id), isTrue);
    expect(service.saved[created.id]?.title, 'Cena');
  });

  test('addEntry con un id ya presente reemplaza la entrada en lugar de duplicarla', () async {
    final service = _FakeDiarioService();
    final state = await _loaded(service);
    final id = state.newEntryId();
    final before = state.entries.length;

    await state.addEntry(id: id, contactId: 'c1', categoryId: 'cat_gustos', title: 'Cena');
    final retried = await state.addEntry(id: id, contactId: 'c1', categoryId: 'cat_gustos', title: 'Cena 2');

    expect(retried.id, id);
    expect(state.entries.length, before + 1);
    expect(state.entries.where((e) => e.id == id).single.title, 'Cena 2');
    expect(service.saved[id]?.title, 'Cena 2');
  });

  test('updateContact devuelve el contacto guardado, con su fecha de actualización', () async {
    final service = _FakeDiarioService();
    final state = await _loaded(service);
    final created = await state.addContact(name: 'Ana');

    final saved = await state.updateContact(created.copyWith(name: 'Ana María'));

    expect(saved.id, created.id);
    expect(saved.name, 'Ana María');
    expect(saved.updatedAt, isNotNull);
    expect(state.contacts.firstWhere((c) => c.id == created.id).updatedAt, saved.updatedAt);
  });

  test('newEntryId da ids distintos en cada llamada', () async {
    final state = await _loaded(_FakeDiarioService());
    expect(state.newEntryId(), isNot(state.newEntryId()));
  });

  test('updateEntry devuelve la entrada actualizada con el mismo id', () async {
    final service = _FakeDiarioService();
    final state = await _loaded(service);
    final created = await state.addEntry(contactId: 'c1', categoryId: 'cat_gustos', title: 'Cena');

    final updated = await state.updateEntry(created.copyWith(title: 'Almuerzo'));

    expect(updated.id, created.id);
    expect(updated.title, 'Almuerzo');
    expect(updated.updatedAt, isNotNull);
    expect(service.saved[created.id]?.title, 'Almuerzo');
  });
}
