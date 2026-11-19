import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/diario_write_tools.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_result.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_specs.dart';
import 'package:quebrado_app_flutter/diario/diario.dart';

/// Servicio sin red con contactos y plantillas inventados.
class _FakeDiarioService extends DiarioSupabaseService {
  _FakeDiarioService() : super.forTesting();

  final Map<String, DiarioEntry> savedEntries = {};
  final Map<String, DiarioContact> savedContacts = {};
  final List<String> deletedEntries = [];
  final List<String> deletedContacts = [];
  bool failEntrySave = false;

  @override
  bool get isReady => false;

  @override
  Future<List<DiarioContact>> getContacts() async => [
        DiarioContact(id: 'c-lucia', name: 'Lucía Pérez', nickname: 'Lu'),
        DiarioContact(id: 'c-mateo-r', name: 'Mateo Rojas'),
        DiarioContact(id: 'c-mateo-s', name: 'Mateo Salas'),
        DiarioContact(id: 'c-andres', name: 'Andrés Vidal'),
        DiarioContact(id: 'c-bruno', name: 'Bruno Díaz'),
      ];

  @override
  Future<List<DiarioTemplate>> getTemplates() async => [
        DiarioTemplate(
          id: 'tpl-regalo',
          name: 'Idea de Regalo / Deseo',
          icon: 'card_giftcard',
          colorHex: '#000000',
          fields: const [],
        ),
      ];

  @override
  Future<List<DiarioEntry>> getEntries() async => [];

  @override
  Future<void> saveEntry(DiarioEntry entry) async {
    if (failEntrySave) throw StateError('sin conexión');
    savedEntries[entry.id] = entry;
  }

  @override
  Future<void> deleteEntry(String id) async => deletedEntries.add(id);

  @override
  Future<void> saveContact(DiarioContact contact, {bool includeAvatar = true}) async =>
      savedContacts[contact.id] = contact;

  @override
  Future<void> deleteContact(String id) async => deletedContacts.add(id);
}

Future<DiarioState> _loaded(_FakeDiarioService service) async {
  final state = DiarioState(service: service);
  while (state.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
  return state;
}

final DateTime _now = DateTime(2026, 11, 18, 15, 30);

WriteContext _ctx({
  bool untrustedRead = false,
  bool directWriteDone = false,
  bool confirmed = false,
  // La persona nombra a los contactos que usan los tests (S3-02).
  String userText = 'anota lo de Lucía Pérez y lo de Bruno Díaz',
}) =>
    WriteContext(
      userText: userText,
      untrustedRead: untrustedRead,
      directWriteDone: directWriteDone,
      confirmedByUser: confirmed,
      now: () => _now,
    );

void main() {
  late _FakeDiarioService service;
  late DiarioState state;
  late DiarioWriteTools tools;

  setUp(() async {
    service = _FakeDiarioService();
    state = await _loaded(service);
    tools = DiarioWriteTools(state);
  });

  test('atiende registerDiarioEntry y createContact', () {
    expect(tools.toolNames, {WriteToolNames.registerDiarioEntry, WriteToolNames.createContact});
  });

  group('registerDiarioEntry', () {
    Future<WriteOutcome> register(Map<String, dynamic> args, [WriteContext? ctx]) =>
        tools.execute(WriteToolNames.registerDiarioEntry, args, ctx ?? _ctx());

    test('con un contacto que coincide guarda la entrada en ese contacto, con resumen, ruta y deshacer', () async {
      final out = await register({
        'contentText': 'Le gusta el café sin azúcar',
        'title': 'Café',
        'contactName': 'lucia perez',
      });

      expect(out.result.status, WriteToolStatus.saved);
      final entry = state.entries.firstWhere((e) => e.id == out.result.recordId);
      expect(entry.contactId, 'c-lucia');
      expect(entry.contentText, 'Le gusta el café sin azúcar');
      expect(entry.categoryId, state.getRootCategories('c-lucia').first.id);
      expect(entry.entryType, 'simple_text');
      expect(entry.createdAt, _now);
      expect(service.savedEntries.containsKey(entry.id), isTrue);
      expect(out.summaryTitle, 'Café');
      expect(out.summaryParts.map((p) => p.text), ['Lucía Pérez', 'hoy']);
      expect(out.result.summary, 'Café · Lucía Pérez · hoy');
      expect(out.result.route, '/diario/entradas/${entry.id}');
      expect(out.result.undoId, isNotEmpty);
      expect(out.undoPayload, {'entryId': entry.id});
    });

    test('resuelve el contacto por su apodo exacto', () async {
      final out = await register({'contentText': 'Talla 38', 'contactName': 'Lu'});

      expect(out.result.status, WriteToolStatus.saved);
      expect(state.entries.firstWhere((e) => e.id == out.result.recordId).contactId, 'c-lucia');
    });

    test('sin contacto guarda una entrada personal y usa el texto como título del resumen', () async {
      final out = await register({'contentText': 'Hoy terminé el libro'});

      expect(out.result.status, WriteToolStatus.saved);
      final entry = state.entries.firstWhere((e) => e.id == out.result.recordId);
      expect(entry.contactId, 'personal');
      expect(entry.categoryId, 'cat_notas_personales');
      expect(out.summaryTitle, 'Hoy terminé el libro');
      expect(out.summaryParts.first.text, 'Personal');
    });

    test('con fecha de ayer guarda esa fecha con la hora actual y lo dice en el resumen', () async {
      final out = await register({'contentText': 'Caminé 5 km', 'date': '2026-11-17'});

      final entry = state.entries.firstWhere((e) => e.id == out.result.recordId);
      expect(entry.createdAt, DateTime(2026, 11, 17, 15, 30));
      expect(out.summaryParts.last.text, 'ayer');
    });

    test('con plantilla por nombre la guarda como instancia de esa plantilla', () async {
      final out = await register({
        'contentText': 'Unos audífonos',
        'contactName': 'Bruno Díaz',
        'templateName': 'idea de regalo / deseo',
      });

      final entry = state.entries.firstWhere((e) => e.id == out.result.recordId);
      expect(entry.templateId, 'tpl-regalo');
      expect(entry.entryType, 'template_instance');
    });

    test('sin contentText responde missing y no guarda nada', () async {
      final before = state.entries.length;
      final out = await register({'contactName': 'Lu'});

      expect(out.result.status, WriteToolStatus.missing);
      expect(out.result.missing, ['contentText']);
      expect(out.result.resolved['contactName'], 'Lucía Pérez');
      expect(state.entries.length, before);
    });

    test('una plantilla que no existe pide elegir entre las existentes', () async {
      final out = await register({'contentText': 'x', 'templateName': 'Receta'});

      expect(out.result.status, WriteToolStatus.missing);
      expect(out.result.missing, ['templateName']);
      expect(out.result.options['templateName'], ['Idea de Regalo / Deseo']);
    });

    test('con varios contactos que coinciden pide elegir (missing con opciones)', () async {
      final before = state.entries.length;
      final out = await register({'contentText': 'Cumple el 3', 'contactName': 'Mateo'});

      expect(out.result.status, WriteToolStatus.missing);
      expect(out.result.missing, ['contactName']);
      expect(out.result.options['contactName'], ['Mateo Rojas', 'Mateo Salas']);
      expect(state.entries.length, before);
    });

    group('contacto inexistente', () {
      test('sale como tarjeta con hasta 3 parecidos más «Sin contacto» y no crea el contacto', () async {
        final contactsBefore = state.contacts.length;
        final entriesBefore = state.entries.length;

        final out = await register({'contentText': 'Le debo un favor', 'contactName': 'Mateo Ruiz'});

        expect(out.result.status, WriteToolStatus.proposal);
        expect(out.result.reasons, [DiarioWriteReason.contactNotFound]);
        final options = out.result.options['contactName']!;
        expect(options.length, 4);
        expect(options.last, DiarioWriteTools.noContactOption);
        expect(options.take(3), contains('Mateo Rojas'));
        expect(out.result.resolved['requestedContactName'], 'Mateo Ruiz');
        expect(out.commitArgs?['contactName'], 'Mateo Ruiz');
        expect(state.contacts.length, contactsBefore);
        expect(state.entries.length, entriesBefore);
      });

      test('confirmada con «Sin contacto» guarda una entrada personal sin crear el contacto', () async {
        final contactsBefore = state.contacts.length;
        final first = await register({'contentText': 'Le debo un favor', 'contactName': 'Mateo Ruiz'});
        final args = {...first.commitArgs!, 'contactName': DiarioWriteTools.noContactOption};

        final out = await register(args, _ctx(confirmed: true));

        expect(out.result.status, WriteToolStatus.saved);
        expect(state.entries.firstWhere((e) => e.id == out.result.recordId).contactId, 'personal');
        expect(state.contacts.length, contactsBefore);
      });

      test('confirmada eligiendo un contacto parecido guarda la entrada en ese contacto', () async {
        final first = await register({'contentText': 'Le debo un favor', 'contactName': 'Mateo Ruiz'});
        final args = {...first.commitArgs!, 'contactName': 'Mateo Rojas'};

        final out = await register(args, _ctx(confirmed: true));

        expect(out.result.status, WriteToolStatus.saved);
        expect(state.entries.firstWhere((e) => e.id == out.result.recordId).contactId, 'c-mateo-r');
      });

      test('confirmada sin elegir sigue en missing con las mismas opciones', () async {
        final entriesBefore = state.entries.length;
        final first = await register({'contentText': 'Le debo un favor', 'contactName': 'Mateo Ruiz'});

        final out = await register(first.commitArgs!, _ctx(confirmed: true));

        expect(out.result.status, WriteToolStatus.missing);
        expect(out.result.missing, ['contactName']);
        expect(out.result.options['contactName']!.last, DiarioWriteTools.noContactOption);
        expect(state.entries.length, entriesBefore);
      });

      test('«Sin contacto» sin tarjeta confirmada no se toma como entrada personal', () async {
        final out = await register({'contentText': 'x', 'contactName': DiarioWriteTools.noContactOption});

        expect(out.result.status, WriteToolStatus.proposal);
        expect(out.result.reasons, [DiarioWriteReason.contactNotFound]);
      });
    });

    test('S3-02: un contacto que la persona no nombró sale como tarjeta y no guarda; confirmada, guarda', () async {
      final before = state.entries.length;

      final out = await register(
        {'contentText': 'Le debo dinero', 'contactName': 'Andrés Vidal'},
        _ctx(userText: 'hola'),
      );

      expect(out.result.status, WriteToolStatus.proposal);
      expect(out.result.reasons, [DiarioWriteReason.nameNotInUserText]);
      expect(state.entries.length, before);

      final ok = await register(out.commitArgs!, _ctx(userText: 'hola', confirmed: true));
      expect(ok.result.status, WriteToolStatus.saved);
      expect(state.entries.firstWhere((e) => e.id == ok.result.recordId).contactId, 'c-andres');
    });

    test('S3-09: el término del modelo no ancla («Andrés Vidal hola» con «hola»)', () async {
      final before = state.entries.length;

      final out = await register(
        {'contentText': 'Le debo dinero', 'contactName': 'Andrés Vidal hola'},
        _ctx(userText: 'hola'),
      );

      expect(out.result.status, isNot(WriteToolStatus.saved), reason: out.result.toString());
      expect(state.entries.length, before);
    });

    test('S3-07: commitArgs lleva solo los campos que usa el ejecutor', () async {
      final out = await register(
        {'contentText': 'Talla 38', 'contactName': 'Lu', 'extra': 'inyectado', 'title': 'Ropa'},
        _ctx(untrustedRead: true),
      );

      expect(out.commitArgs, {
        'contentText': 'Talla 38',
        'title': 'Ropa',
        'contactName': 'Lucía Pérez',
        'date': '2026-11-18',
      });
    });

    test('si en el turno se leyó texto libre sale como tarjeta aunque todo esté claro', () async {
      final before = state.entries.length;
      final out = await register(
        {'contentText': 'Talla 38', 'contactName': 'Lu'},
        _ctx(untrustedRead: true),
      );

      expect(out.result.status, WriteToolStatus.proposal);
      expect(out.result.reasons, ['read_untrusted_text']);
      expect(out.commitArgs?['contactName'], 'Lucía Pérez');
      expect(out.summaryTitle, 'Talla 38');
      expect(state.entries.length, before);
    });

    test('si falla el guardado responde error y no deja la entrada en la lista', () async {
      service.failEntrySave = true;
      final before = state.entries.length;

      final out = await register({'contentText': 'Talla 38', 'contactName': 'Lu'});

      expect(out.result.status, WriteToolStatus.error);
      expect(out.result.message, startsWith('No pude registrarlo: '));
      expect(out.result.message, endsWith('No se guardó nada.'));
      expect(state.entries.length, before);
    });

    test('deshacer borra la entrada creada', () async {
      final out = await register({'contentText': 'Talla 38', 'contactName': 'Lu'});
      final id = out.result.recordId!;

      await tools.undo(WriteToolNames.registerDiarioEntry, out.undoPayload!);

      expect(state.entries.any((e) => e.id == id), isFalse);
      expect(service.deletedEntries, [id]);
    });
  });

  group('createContact', () {
    Future<WriteOutcome> create(Map<String, dynamic> args, [WriteContext? ctx]) =>
        tools.execute(WriteToolNames.createContact, args, ctx ?? _ctx());

    test('crea el contacto con sus datos, ruta al contacto y deshacer', () async {
      final out = await create({
        'name': 'Sofía Márquez',
        'relationship': 'Amiga',
        'phone': '0000-0000000',
        'birthdate': '1999-04-02',
      });

      expect(out.result.status, WriteToolStatus.saved);
      final contact = state.getContactById(out.result.recordId!)!;
      expect(contact.name, 'Sofía Márquez');
      expect(contact.relationship, 'Amiga');
      expect(contact.birthdate, DateTime(1999, 4, 2));
      expect(service.savedContacts.containsKey(contact.id), isTrue);
      expect(out.result.route, '/diario/contactos/${contact.id}');
      expect(out.result.summary, 'Sofía Márquez · Contacto nuevo · Amiga');
      expect(out.undoPayload, {'contactId': contact.id});
    });

    test('con solo la edad no inventa la fecha de nacimiento', () async {
      final out = await create({'name': 'Tomás Ibarra', 'age': 30, 'notes': 'Tiene 30 años'});

      final contact = state.getContactById(out.result.recordId!)!;
      expect(contact.birthdate, isNull);
      expect(contact.notes, 'Tiene 30 años');
    });

    test('sin nombre responde missing', () async {
      final out = await create({'relationship': 'Primo'});

      expect(out.result.status, WriteToolStatus.missing);
      expect(out.result.missing, ['name']);
    });

    test('una fecha de nacimiento incompleta pide la fecha (no la completa)', () async {
      final out = await create({'name': 'Tomás Ibarra', 'birthdate': '1990'});

      expect(out.result.status, WriteToolStatus.missing);
      expect(out.result.missing, ['birthdate']);
    });

    test('un nombre duplicado sale como tarjeta y al confirmarla se crea', () async {
      final before = state.contacts.length;

      final first = await create({'name': '  lucia PEREZ ', 'relationship': 'Prima'});
      expect(first.result.status, WriteToolStatus.proposal);
      expect(first.result.reasons, [DiarioWriteReason.duplicateName]);
      expect(state.contacts.length, before);

      final out = await create(first.commitArgs!, _ctx(confirmed: true));
      expect(out.result.status, WriteToolStatus.saved);
      expect(state.contacts.length, before + 1);
      expect(state.getContactById(out.result.recordId!)!.relationship, 'Prima');
    });

    test('la segunda escritura del turno sale como tarjeta', () async {
      final out = await create({'name': 'Elena Mora'}, _ctx(directWriteDone: true));

      expect(out.result.status, WriteToolStatus.proposal);
      expect(out.result.reasons, ['multiple_writes']);
      expect(state.contacts.any((c) => c.name == 'Elena Mora'), isFalse);
    });

    test('deshacer borra el contacto creado', () async {
      final out = await create({'name': 'Elena Mora'});
      final id = out.result.recordId!;

      await tools.undo(WriteToolNames.createContact, out.undoPayload!);

      expect(state.getContactById(id), isNull);
      expect(service.deletedContacts, [id]);
    });
  });

  test('deshacer sin id lanza para que el llamador lo diga', () async {
    expect(
      () => tools.undo(WriteToolNames.registerDiarioEntry, const {}),
      throwsStateError,
    );
  });
}
