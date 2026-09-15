import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/diario_contact.dart';
import '../models/diario_category.dart';
import '../models/diario_template.dart';
import '../models/diario_entry.dart';
import '../services/diario_supabase_service.dart';

class DiarioSearchResult {
  final List<DiarioContact> matchedContacts;
  final List<DiarioEntry> matchedEntries;

  DiarioSearchResult({
    required this.matchedContacts,
    required this.matchedEntries,
  });

  bool get isEmpty => matchedContacts.isEmpty && matchedEntries.isEmpty;
  int get totalCount => matchedContacts.length + matchedEntries.length;
}

class DiarioState extends ChangeNotifier {
  final DiarioSupabaseService _service = DiarioSupabaseService.instance;
  final _uuid = const Uuid();

  List<DiarioContact> _contacts = [];
  List<DiarioCategory> _categories = [];
  List<DiarioTemplate> _templates = [];
  List<DiarioEntry> _entries = [];

  bool _isLoading = true;
  String? _errorMessage;

  List<DiarioContact> get contacts => _contacts;
  List<DiarioCategory> get categories => _categories;
  List<DiarioTemplate> get templates => _templates;
  List<DiarioEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  DiarioState() {
    loadAll();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getContacts(),
        _service.getCategories(),
        _service.getTemplates(),
        _service.getEntries(),
      ]);

      _contacts = results[0] as List<DiarioContact>;
      _categories = results[1] as List<DiarioCategory>;
      _templates = results[2] as List<DiarioTemplate>;
      _entries = results[3] as List<DiarioEntry>;
    } catch (e) {
      _errorMessage = 'Error al cargar Diario Jottache: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // CONTACTS LOGIC
  // ===========================================================================
  DiarioContact? getContactById(String id) {
    try {
      return _contacts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<DiarioContact> getUpcomingBirthdays({int limit = 5}) {
    final withBday = _contacts.where((c) => c.birthdate != null).toList();
    withBday.sort((a, b) => (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999));
    return withBday.take(limit).toList();
  }

  Future<DiarioContact> addContact({
    required String name,
    String? nickname,
    String? relationship,
    String? avatarUrl,
    String? avatarColor,
    DateTime? birthdate,
    String? phone,
    String? notes,
    bool isFavorite = false,
  }) async {
    final newContact = DiarioContact(
      id: _uuid.v4(),
      name: name.trim(),
      nickname: nickname?.trim(),
      relationship: relationship?.trim(),
      avatarUrl: avatarUrl,
      avatarColor: avatarColor,
      birthdate: birthdate,
      phone: phone?.trim(),
      notes: notes?.trim(),
      isFavorite: isFavorite,
    );

    _contacts.add(newContact);
    _contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();

    await _service.saveContact(newContact);
    return newContact;
  }

  Future<void> updateContact(DiarioContact contact) async {
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    final updated = contact.copyWith(updatedAt: DateTime.now());
    if (index != -1) {
      _contacts[index] = updated;
    } else {
      _contacts.add(updated);
    }
    _contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    await _service.saveContact(updated);
  }

  Future<void> deleteContact(String contactId) async {
    _contacts.removeWhere((c) => c.id == contactId);
    _entries.removeWhere((e) => e.contactId == contactId);
    _categories.removeWhere((cat) => cat.contactId == contactId);
    notifyListeners();
    await _service.deleteContact(contactId);
  }

  Future<void> toggleFavoriteContact(String contactId) async {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      final updated = _contacts[index].copyWith(
        isFavorite: !_contacts[index].isFavorite,
        updatedAt: DateTime.now(),
      );
      _contacts[index] = updated;
      notifyListeners();
      await _service.saveContact(updated);
    }
  }

  // ===========================================================================
  // CATEGORIES LOGIC (JERÁRQUICAS N-NIVELES)
  // ===========================================================================
  DiarioCategory? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<DiarioCategory> getRootCategories(String? contactId) {
    return _categories.where((c) {
      final isRoot = c.parentId == null;
      final isAvailable = c.contactId == null || (contactId != null && c.contactId == contactId);
      return isRoot && isAvailable;
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<DiarioCategory> getSubcategories(String parentId, String? contactId) {
    return _categories.where((c) {
      final isChild = c.parentId == parentId;
      final isAvailable = c.contactId == null || (contactId != null && c.contactId == contactId);
      return isChild && isAvailable;
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> addCategory({
    required String name,
    String? contactId,
    String? parentId,
    String icon = 'folder_outlined',
    String colorHex = '#1F6F5F',
  }) async {
    final newCat = DiarioCategory(
      id: _uuid.v4(),
      name: name.trim(),
      contactId: contactId,
      parentId: parentId,
      icon: icon,
      colorHex: colorHex,
      sortOrder: _categories.length + 1,
    );

    _categories.add(newCat);
    notifyListeners();
    await _service.saveCategory(newCat);
  }

  Future<void> updateCategory(DiarioCategory category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
    } else {
      _categories.add(category);
    }
    notifyListeners();
    await _service.saveCategory(category);
  }

  Future<void> deleteCategory(String categoryId) async {
    // Eliminar subcategorías recursivamente
    final childIds = _categories.where((c) => c.parentId == categoryId).map((c) => c.id).toList();
    for (final cid in childIds) {
      await deleteCategory(cid);
    }

    _categories.removeWhere((c) => c.id == categoryId);
    _entries.removeWhere((e) => e.categoryId == categoryId);
    notifyListeners();
    await _service.deleteCategory(categoryId);
  }

  // ===========================================================================
  // TEMPLATES LOGIC (MODELOS DINÁMICOS REUTILIZABLES)
  // ===========================================================================
  DiarioTemplate? getTemplateById(String id) {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addTemplate({
    required String name,
    String? description,
    String icon = 'extension',
    String colorHex = '#1F6F5F',
    required List<TemplateField> fields,
  }) async {
    final newTpl = DiarioTemplate(
      id: _uuid.v4(),
      name: name.trim(),
      description: description?.trim(),
      icon: icon,
      colorHex: colorHex,
      fields: fields,
      isSystem: false,
    );

    _templates.add(newTpl);
    notifyListeners();
    await _service.saveTemplate(newTpl);
  }

  Future<void> updateTemplate(DiarioTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    final updated = template.copyWith(updatedAt: DateTime.now());
    if (index != -1) {
      _templates[index] = updated;
    } else {
      _templates.add(updated);
    }
    notifyListeners();
    await _service.saveTemplate(updated);
  }

  Future<void> deleteTemplate(String templateId) async {
    _templates.removeWhere((t) => t.id == templateId);
    notifyListeners();
    await _service.deleteTemplate(templateId);
  }

  // ===========================================================================
  // ENTRIES LOGIC (REGISTROS)
  // ===========================================================================
  List<DiarioEntry> getEntriesForCategory(String contactId, String categoryId) {
    // Retorna entradas directas de esta categoría o de sus subcategorías inmediatas
    final childCategoryIds = _categories.where((c) => c.parentId == categoryId).map((c) => c.id).toSet();
    final allCategoryIds = {categoryId, ...childCategoryIds};

    return _entries.where((e) {
      return e.contactId == contactId && allCategoryIds.contains(e.categoryId);
    }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  List<DiarioEntry> getEntriesForContact(String contactId) {
    return _entries.where((e) => e.contactId == contactId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addEntry({
    required String contactId,
    required String categoryId,
    String? templateId,
    String entryType = 'simple_text',
    required String title,
    String? contentText,
    String? photoUrl,
    Map<String, dynamic>? contentData,
    bool isPinned = false,
  }) async {
    final newEntry = DiarioEntry(
      id: _uuid.v4(),
      contactId: contactId,
      categoryId: categoryId,
      templateId: templateId,
      entryType: entryType,
      title: title.trim(),
      contentText: contentText?.trim(),
      photoUrl: photoUrl,
      contentData: contentData ?? {},
      isPinned: isPinned,
    );

    _entries.insert(0, newEntry);
    notifyListeners();
    await _service.saveEntry(newEntry);
  }

  Future<void> updateEntry(DiarioEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    final updated = entry.copyWith(updatedAt: DateTime.now());
    if (index != -1) {
      _entries[index] = updated;
    } else {
      _entries.insert(0, updated);
    }
    notifyListeners();
    await _service.saveEntry(updated);
  }

  Future<void> deleteEntry(String entryId) async {
    _entries.removeWhere((e) => e.id == entryId);
    notifyListeners();
    await _service.deleteEntry(entryId);
  }

  Future<void> togglePinEntry(String entryId) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      final updated = _entries[index].copyWith(
        isPinned: !_entries[index].isPinned,
        updatedAt: DateTime.now(),
      );
      _entries[index] = updated;
      notifyListeners();
      await _service.saveEntry(updated);
    }
  }

  // ===========================================================================
  // BÚSQUEDA GLOBAL CRUZADA (CROSS-ATTRIBUTES SEARCH)
  // ===========================================================================
  DiarioSearchResult searchGlobal(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return DiarioSearchResult(matchedContacts: [], matchedEntries: []);
    }

    // 1. Coincidencias en contactos
    final matchedContacts = _contacts.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.nickname?.toLowerCase().contains(q) ?? false) ||
          (c.relationship?.toLowerCase().contains(q) ?? false) ||
          (c.phone?.toLowerCase().contains(q) ?? false) ||
          (c.notes?.toLowerCase().contains(q) ?? false);
    }).toList();

    // 2. Coincidencias en entradas (título, texto plano o campos JSONB del modelo)
    final matchedEntries = _entries.where((e) {
      if (e.title.toLowerCase().contains(q)) return true;
      if (e.contentText?.toLowerCase().contains(q) ?? false) return true;

      // Buscar dentro de los valores del JSONB contentData (ej: placa, modelo de auto, alimento)
      for (final val in e.contentData.values) {
        if (val != null && val.toString().toLowerCase().contains(q)) {
          return true;
        }
      }
      return false;
    }).toList();

    return DiarioSearchResult(
      matchedContacts: matchedContacts,
      matchedEntries: matchedEntries,
    );
  }
}
