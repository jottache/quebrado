import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/diario/models/diario_category.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/diario/models/diario_entry.dart';
import 'package:quebrado_app_flutter/diario/models/diario_template.dart';
import 'package:quebrado_app_flutter/diario/services/diario_supabase_service.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';

class FakeDiarioService extends DiarioSupabaseService {
  FakeDiarioService() : super.forTesting();

  bool failContacts = false;
  final Map<String, String> inlineAvatars = {'c2': 'data:image/png;base64,AAAA'};
  final Map<String, String> remoteAvatars = {'c1': 'https://x.supabase.co/storage/v1/object/public/diario-media/avatars/c1.jpg'};
  final List<({String id, bool includeAvatar, String? avatar})> savedContacts = [];
  final List<String> avatarDownloads = [];

  @override
  bool get isReady => true;

  @override
  Future<List<DiarioContact>> getContacts() async {
    if (failContacts) throw Exception('timeout');
    // Igual que la consulta real: sin avatar_url
    return [DiarioContact(id: 'c1', name: 'Ana'), DiarioContact(id: 'c2', name: 'Beto')];
  }

  @override
  Future<Map<String, String>> getRemoteAvatarUrls() async => remoteAvatars;

  @override
  Future<List<String>> getInlineAvatarContactIds() async => inlineAvatars.keys.toList();

  @override
  Future<String?> getContactAvatar(String contactId) async {
    avatarDownloads.add(contactId);
    return inlineAvatars[contactId];
  }

  @override
  Future<bool> updateContactAvatar(String contactId, String? avatarUrl) async => true;

  @override
  Future<List<DiarioCategory>> getCategories() async => [];

  @override
  Future<List<DiarioTemplate>> getTemplates() async => [];

  @override
  Future<List<DiarioEntry>> getEntries() async => [
        DiarioEntry(id: 'e1', contactId: 'personal', categoryId: 'cat_notas_personales', title: 'Mi nota'),
      ];

  @override
  Future<void> saveCategory(DiarioCategory category) async {}

  @override
  Future<void> saveEntry(DiarioEntry entry) async {}

  @override
  Future<void> saveContact(DiarioContact contact, {bool includeAvatar = true}) async {
    savedContacts.add((id: contact.id, includeAvatar: includeAvatar, avatar: contact.avatarUrl));
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('carga los contactos sin foto, agrega las URLs y descarga aparte las fotos embebidas', () async {
    final service = FakeDiarioService();
    final state = DiarioState(service: service);
    await _settle();

    expect(state.contacts.map((c) => c.name), ['Ana', 'Beto']);
    expect(state.getContactById('c1')!.avatarUrl, contains('diario-media'));
    expect(service.avatarDownloads, ['c2'], reason: 'solo la foto embebida, de a una');
    expect(state.getContactById('c2')!.avatarUrl, startsWith('data:image'));
    expect(state.isAvatarPending('c2'), isFalse);
  });

  test('si la consulta de contactos falla, las notas igual se muestran', () async {
    final service = FakeDiarioService()..failContacts = true;
    final state = DiarioState(service: service);
    await _settle();

    expect(state.contacts, isEmpty);
    expect(state.entries.map((e) => e.id), contains('e1'), reason: 'antes una falla dejaba todo Diario vacío');
  });

  test('favorito mientras la foto está pendiente no envía avatar_url', () async {
    final service = _SlowAvatarService();
    final state = DiarioState(service: service);
    await _settle();

    expect(state.isAvatarPending('c2'), isTrue);
    await state.toggleFavoriteContact('c2');
    expect(service.savedContacts.last.includeAvatar, isFalse, reason: 'si se enviara null, se borraría la foto');

    // Elegir una foto nueva sí la envía y deja de estar pendiente
    final c2 = state.getContactById('c2')!;
    await state.updateContact(c2.copyWith(avatarUrl: 'https://otra.com/nueva.jpg'));
    expect(service.savedContacts.last.includeAvatar, isTrue);
    expect(state.isAvatarPending('c2'), isFalse);
  });
}

/// La descarga de la foto nunca termina, para probar el estado "pendiente".
class _SlowAvatarService extends FakeDiarioService {
  final Completer<String?> _never = Completer<String?>();

  @override
  Future<String?> getContactAvatar(String contactId) {
    avatarDownloads.add(contactId);
    return _never.future;
  }
}
