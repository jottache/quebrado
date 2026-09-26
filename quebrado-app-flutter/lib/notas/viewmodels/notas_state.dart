import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note_category.dart';
import '../models/note_block.dart';
import '../models/note_item.dart';
import '../services/notas_supabase_service.dart';

class NotasState extends ChangeNotifier {
  final NotasSupabaseService _service;
  final Uuid _uuid = const Uuid();

  NotasState({NotasSupabaseService? service})
      : _service = service ?? NotasSupabaseService.instance;

  List<NoteCategory> _categories = [];
  List<NoteItem> _notes = [];
  bool _isLoading = false;

  String? _selectedCategoryId; // null = "Todas"
  String _searchQuery = '';

  List<NoteCategory> get categories => List.unmodifiable(_categories);
  List<NoteItem> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;

  NoteCategory? get defaultCategory {
    final systemCat = _categories.firstWhere(
      (c) => c.isSystem,
      orElse: () => _categories.isNotEmpty
          ? _categories.first
          : NoteCategory(id: NoteCategory.generalCategoryId, name: 'General', isSystem: true),
    );
    return systemCat;
  }

  void setSelectedCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  // ===========================================================================
  // CARGA DE DATOS
  // ===========================================================================

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loadedCategories = await _service.getCategories();
      final loadedNotes = await _service.getNotes();

      _categories = loadedCategories;
      _notes = loadedNotes;
    } catch (e) {
      debugPrint('Error cargando notas y categorías: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Alias de conveniencia para cargar todas las notas
  Future<void> loadNotes() => loadAll();

  // ===========================================================================
  // GESTIÓN DE CATEGORÍAS
  // ===========================================================================

  Future<NoteCategory> addCategory({
    required String name,
    String icon = '📁',
    String colorHex = '#6366F1',
  }) async {
    final newCat = NoteCategory(
      id: _uuid.v4(),
      name: name.trim(),
      icon: icon,
      colorHex: colorHex,
      sortOrder: _categories.length,
      isSystem: false,
    );

    _categories.add(newCat);
    notifyListeners();
    await _service.saveCategory(newCat);
    return newCat;
  }

  Future<NoteCategory> createCategory({
    required String name,
    String icon = '📁',
    String colorHex = '#6366F1',
  }) =>
      addCategory(name: name, icon: icon, colorHex: colorHex);

  Future<void> updateCategory(NoteCategory updated) async {
    final index = _categories.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _categories[index] = updated;
      notifyListeners();
      await _service.saveCategory(updated);
    }
  }

  /// Elimina una categoría reasignando previamente todas las notas asociadas
  /// a la categoría predeterminada 'General'. Nunca se pierden notas.
  Future<void> deleteCategory(String categoryId) async {
    final catIndex = _categories.indexWhere((c) => c.id == categoryId);
    if (catIndex == -1) return;

    final targetCat = _categories[catIndex];
    if (targetCat.isSystem) return; // La categoría General no se puede borrar

    final defCat = defaultCategory;
    final fallbackId = defCat?.id ?? NoteCategory.generalCategoryId;

    // 1. Reasignar notas en memoria
    for (int i = 0; i < _notes.length; i++) {
      if (_notes[i].categoryId == categoryId) {
        _notes[i] = _notes[i].copyWith(categoryId: fallbackId);
      }
    }

    // 2. Remover categoría de la lista
    _categories.removeAt(catIndex);
    if (_selectedCategoryId == categoryId) {
      _selectedCategoryId = null;
    }
    notifyListeners();

    // 3. Persistir en Supabase
    await _service.deleteCategory(categoryId, defaultCategoryId: fallbackId);
  }

  // ===========================================================================
  // GESTIÓN DE NOTAS & ACUERDOS
  // ===========================================================================

  Future<NoteItem> createNote({
    required String title,
    String? categoryId,
    String icon = '📝',
    String? emoji,
    String colorHex = '#6366F1',
    List<NoteBlock> blocks = const [],
    String? contentText,
    String? sharedTag,
    bool isPinned = false,
  }) async {
    final effectiveCategoryId = categoryId ?? defaultCategory?.id;

    final newNote = NoteItem(
      id: _uuid.v4(),
      categoryId: effectiveCategoryId,
      title: title.trim().isNotEmpty ? title.trim() : 'Sin título',
      icon: emoji ?? icon,
      colorHex: colorHex,
      blocks: blocks,
      contentText: contentText,
      sharedTag: sharedTag,
      isPinned: isPinned,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _notes.insert(0, newNote);
    notifyListeners();
    await _service.saveNote(newNote);
    return newNote;
  }

  Future<void> updateNote(NoteItem updated) async {
    final index = _notes.indexWhere((n) => n.id == updated.id);
    final noteWithTimestamp = updated.copyWith(updatedAt: DateTime.now());

    if (index != -1) {
      _notes[index] = noteWithTimestamp;
    } else {
      _notes.insert(0, noteWithTimestamp);
    }
    notifyListeners();
    await _service.saveNote(noteWithTimestamp);
  }

  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    notifyListeners();
    await _service.deleteNote(noteId);
  }

  Future<void> togglePin(String noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      final updated = note.copyWith(isPinned: !note.isPinned);
      _notes[index] = updated;
      notifyListeners();
      await _service.saveNote(updated);
    }
  }

  /// Alias de conveniencia
  Future<void> togglePinNote(String noteId) => togglePin(noteId);

  /// Alterna o establece el estado de un checkbox/todo dentro de los bloques de la nota
  Future<void> toggleTodoBlock(String noteId, String blockId, [bool? targetChecked]) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];

    List<NoteBlock> updateBlocks(List<NoteBlock> list) {
      return list.map((b) {
        if (b.id == blockId && b.type == BlockType.todo) {
          final newChecked = targetChecked ?? !b.isChecked;
          return b.copyWith(isChecked: newChecked);
        }
        if (b.children.isNotEmpty) {
          return b.copyWith(children: updateBlocks(b.children));
        }
        return b;
      }).toList();
    }

    final newBlocks = updateBlocks(note.blocks);
    final updatedNote = note.copyWith(blocks: newBlocks, updatedAt: DateTime.now());
    _notes[noteIndex] = updatedNote;
    notifyListeners();
    await _service.saveNote(updatedNote);
  }

  // ===========================================================================
  // FILTRADO Y CONSULTAS
  // ===========================================================================

  List<NoteItem> get filteredNotes {
    return _notes.where((note) {
      if (note.isArchived) return false;

      // Filtro por categoría seleccionada
      if (_selectedCategoryId != null && note.categoryId != _selectedCategoryId) {
        return false;
      }

      // Filtro por búsqueda
      if (_searchQuery.isNotEmpty) {
        final inTitle = note.title.toLowerCase().contains(_searchQuery);
        final inText = (note.contentText ?? '').toLowerCase().contains(_searchQuery);
        final inTag = (note.sharedTag ?? '').toLowerCase().contains(_searchQuery);
        if (!inTitle && !inText && !inTag) return false;
      }

      return true;
    }).toList();
  }

  List<NoteItem> get pinnedNotes => filteredNotes.where((n) => n.isPinned).toList();
  List<NoteItem> get unpinnedNotes => filteredNotes.where((n) => !n.isPinned).toList();

  NoteCategory? getCategoryById(String? id) {
    if (id == null) return null;
    return _categories.firstWhere((c) => c.id == id, orElse: () => defaultCategory!);
  }

  NoteItem? getNoteById(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  int countNotesInCategory(String categoryId) {
    return _notes.where((n) => n.categoryId == categoryId && !n.isArchived).length;
  }
}
