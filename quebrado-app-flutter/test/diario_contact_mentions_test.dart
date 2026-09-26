import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/diario/widgets/mention_text_field.dart';
import 'package:quebrado_app_flutter/agente/services/suite_rag_service.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';
import 'package:quebrado_app_flutter/quebrado/models/account.dart';
import 'package:quebrado_app_flutter/quebrado/models/recurring_payment.dart';
import 'package:quebrado_app_flutter/habitos/models/habit_model.dart';
import 'package:quebrado_app_flutter/recordatorios/models/reminder_model.dart';

class _MockAppState extends Fake implements AppState {
  @override
  double get totalBalanceUSD => 100.0;
  @override
  double get bcvRate => 42.0;
  @override
  double get euroRate => 45.0;
  @override
  List<Account> get accounts => [];
  @override
  List<PendingOccurrence> get pendingPaymentsToday => [];
}

class _MockHabitosState extends Fake implements HabitosState {
  @override
  double get todayCompletionRate => 0.8;
  @override
  int get bestCurrentStreak => 5;
  @override
  List<HabitModel> get allHabits => [];
}

class _MockRemindersState extends Fake implements RemindersState {
  @override
  int get overdueCount => 0;
  @override
  int get todayCount => 0;
  @override
  List<ReminderModel> get allReminders => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diario Contact Mentions Tests', () {
    test('DiarioEntry serializes and deserializes mentionedContactIds properly', () {
      final entry = DiarioEntry(
        id: 'entry_test_1',
        contactId: 'personal',
        categoryId: 'cat_notas_personales',
        title: 'Reunión de proyecto',
        contentText: 'Hablé con @Carlos Perez sobre el nuevo diseño.',
        mentionedContactIds: const ['carlos_uuid_123'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(entry.hasMentions, isTrue);
      expect(entry.mentionedContactIds, contains('carlos_uuid_123'));

      final map = entry.toMap();
      // Must not be in root map to avoid PostgREST column missing error
      expect(map.containsKey('mentioned_contact_ids'), isFalse);
      expect(map['content_data']['mentioned_contact_ids'], contains('carlos_uuid_123'));

      // Deserialization from map with content_data
      final fromDataMap = DiarioEntry.fromMap(map);
      expect(fromDataMap.hasMentions, isTrue);
      expect(fromDataMap.mentionedContactIds, contains('carlos_uuid_123'));

      // Deserialization from legacy map with root mentioned_contact_ids
      final legacyMap = {
        'id': 'legacy_1',
        'contact_id': 'personal',
        'category_id': 'cat_notas_personales',
        'title': 'Legacy entry',
        'mentioned_contact_ids': ['carlos_uuid_123'],
      };
      final fromLegacyMap = DiarioEntry.fromMap(legacyMap);
      expect(fromLegacyMap.hasMentions, isTrue);
      expect(fromLegacyMap.mentionedContactIds, contains('carlos_uuid_123'));
    });

    test('DiarioState extracts mentions and filters entries mentioning a contact', () async {
      final state = DiarioState();
      await state.loadAll();

      final contact1 = await state.addContact(
        name: 'Maria Rodriguez',
        nickname: 'Mari',
        relationship: 'Colega',
      );

      final contact2 = await state.addContact(
        name: 'Carlos Gomez',
        nickname: 'Carlitos',
        relationship: 'Amigo',
      );

      // Extract mentioned contact IDs by text
      final extracted = state.extractMentionedContactIds(
        'Hoy tuve una sesión con @Maria Rodriguez y revisamos el trabajo con @Carlos Gomez.',
      );
      expect(extracted, contains(contact1.id));
      expect(extracted, contains(contact2.id));

      // Add a personal entry with mentions
      final personalEntry = await state.addPersonalEntry(
        title: 'Nota de sincronización',
        contentText: 'Conversé con @Maria Rodriguez sobre la fecha de entrega.',
      );

      expect(personalEntry.mentionedContactIds, contains(contact1.id));

      // Verify getEntriesMentioningContact finds it for Maria
      final mariaMentions = state.getEntriesMentioningContact(contact1.id);
      expect(mariaMentions.any((e) => e.id == personalEntry.id), isTrue);

      // Verify Carlos doesn't have it
      final carlosMentions = state.getEntriesMentioningContact(contact2.id);
      expect(carlosMentions.any((e) => e.id == personalEntry.id), isFalse);
    });

    test('MentionTextSpanHelper creates bold colored spans with tap handler', () {
      final contacts = [
        DiarioContact(
          id: 'uuid_pedro',
          name: 'Pedro Perez',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      String? tappedContactId;
      final spans = MentionTextSpanHelper.buildSpans(
        text: 'Acuerdo con @Pedro Perez para el lunes.',
        contacts: contacts,
        baseStyle: const TextStyle(fontSize: 14, color: Colors.black),
        onContactTap: (contact) {
          tappedContactId = contact.id;
        },
      );

      expect(spans.length, greaterThanOrEqualTo(2));

      // Find the mention span
      final mentionSpan = spans.firstWhere(
        (span) => span is TextSpan && (span.text ?? '').contains('@Pedro Perez'),
      ) as TextSpan;

      expect(mentionSpan.style?.fontWeight, equals(FontWeight.w900));
      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());

      // Simulate tap
      (mentionSpan.recognizer as TapGestureRecognizer).onTap?.call();
      expect(tappedContactId, equals('uuid_pedro'));
    });

    test('Matches first-name mention @mariana for contact Mariana Davila', () async {
      final state = DiarioState();
      await state.loadAll();

      final mariana = await state.addContact(
        name: 'Mariana Davila',
        nickname: 'Cotiprin',
      );

      // Verify extraction works for @mariana (first name only)
      final extracted = state.extractMentionedContactIds(
        'anoche fue fantastico el momento con @mariana estuve muy feliz.',
      );
      expect(extracted, contains(mariana.id));

      // Verify MentionTextSpanHelper renders @mariana as bold and colored
      String? tappedId;
      final spans = MentionTextSpanHelper.buildSpans(
        text: 'Salí a cenar con @mariana anoche.',
        contacts: [mariana],
        baseStyle: const TextStyle(fontSize: 14, color: Colors.black),
        onContactTap: (c) => tappedId = c.id,
      );

      final mentionSpan = spans.firstWhere(
        (span) => span is TextSpan && (span.text ?? '').contains('@mariana'),
      ) as TextSpan;

      expect(mentionSpan.style?.fontWeight, equals(FontWeight.w900));
      (mentionSpan.recognizer as TapGestureRecognizer).onTap?.call();
      expect(tappedId, equals(mariana.id));

      // Verify getEntriesMentioningContact retrieves entry with @mariana even if mentionedContactIds was empty
      final legacyEntry = DiarioEntry(
        id: 'legacy_entry_1',
        contactId: 'personal',
        categoryId: 'cat_notas_personales',
        title: 'Intimidad intensa',
        contentText: 'anoche fue fantastico con @mariana todo el tiempo',
        mentionedContactIds: const [], // was empty!
      );
      state.entries.insert(0, legacyEntry);

      final mentionsForMariana = state.getEntriesMentioningContact(mariana.id);
      expect(mentionsForMariana.any((e) => e.id == 'legacy_entry_1'), isTrue);
    });

    test('SuiteRagService proposes Diario entry extracting mentions', () async {
      final state = DiarioState();
      await state.loadAll();

      final contact = await state.addContact(
        name: 'Alejandra Gomez',
        relationship: 'Diseñadora',
      );

      final ragService = SuiteRagService(
        appState: _MockAppState(),
        diarioState: state,
        habitosState: _MockHabitosState(),
        remindersState: _MockRemindersState(),
      );

      final res = await ragService.executeFunctionCall(
        'proposeCreateDiarioEntry',
        {
          'title': 'Revisión UI',
          'contactName': 'General',
          'contentText': 'Se discutió el mockup con @Alejandra Gomez para la app.',
        },
        sessionId: 'test-session',
      );

      expect(res.generatedArtifact, isNotNull);
      final artifact = res.generatedArtifact!;
      expect(artifact.type, equals(ArtifactType.actionProposal));
      final data = artifact.metadata['data'] as Map<String, dynamic>;
      expect(data['mentionedContactIds'], contains(contact.id));

      final summaryList = artifact.metadata['summary'] as List;
      final hasMentions = summaryList.any(
        (item) => item is Map && item['label'] == 'Menciones' && (item['value']?.toString().contains('Alejandra Gomez') ?? false),
      );
      expect(hasMentions, isTrue);
    });

    test('Erasing contact A and mentioning contact B preserves ONLY contact B in mentions', () async {
      final state = DiarioState();
      await state.loadAll();

      final contactA = await state.addContact(name: 'Andres Bello');
      final contactB = await state.addContact(name: 'Beatriz Luengo');

      // 1. Crear una nota donde inicialmente se menciona a contacto A, pero luego se borra y se menciona solo a B
      // Simulamos lo que pasaba antes: _mentionedContactIds acumulaba [contactA.id, contactB.id]
      final staleExplicitMentions = [contactA.id, contactB.id];
      final currentText = 'Al final me reuní únicamente con @Beatriz Luengo para avanzar.';

      final entry = await state.addPersonalEntry(
        title: 'Reunión aclaratoria',
        contentText: currentText,
        mentionedContactIds: staleExplicitMentions,
      );

      // Debe contener solo a Beatriz (B) y NO a Andres (A)
      expect(entry.mentionedContactIds, contains(contactB.id));
      expect(entry.mentionedContactIds, isNot(contains(contactA.id)));

      // Verificamos getEntriesMentioningContact
      final mentionsA = state.getEntriesMentioningContact(contactA.id);
      expect(mentionsA.any((e) => e.id == entry.id), isFalse);

      final mentionsB = state.getEntriesMentioningContact(contactB.id);
      expect(mentionsB.any((e) => e.id == entry.id), isTrue);

      // 2. Modificar una nota existente borrando la mención
      final updatedEntry = entry.copyWith(
        contentText: 'Decidí trabajar solo, sin nadie.',
      );
      await state.updateEntry(updatedEntry);

      final reMentionsB = state.getEntriesMentioningContact(contactB.id);
      expect(reMentionsB.any((e) => e.id == entry.id), isFalse);
    });
  });
}
