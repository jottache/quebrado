import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/note_item.dart';
import '../models/note_block.dart';
import '../models/note_category.dart';
import '../theme/notas_colors.dart';
import '../viewmodels/notas_state.dart';
import '../widgets/note_block_widget.dart';
import '../dialogs/category_manager_dialog.dart';

/// Pantalla / Modal de edición de Notas & Acuerdos al estilo Notion.
/// Permite gestionar bloques interactivos (párrafos, títulos, checklists, desplegables, callouts, divisores).
class NoteEditorScreen extends StatefulWidget {
  final NoteItem? note;
  final String? initialCategoryId;
  final bool isModalDialog;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.initialCategoryId,
    this.isModalDialog = false,
  });

  static Future<bool?> open(BuildContext context, {NoteItem? note, String? initialCategoryId}) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 768;

    if (isDesktop) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final dialogWidth = size.width * 0.90;
          final dialogHeight = size.height * 0.90;
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: EdgeInsets.zero,
            child: Center(
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: NoteEditorScreen(
                  note: note,
                  initialCategoryId: initialCategoryId,
                  isModalDialog: true,
                ),
              ),
            ),
          );
        },
      );
    }

    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          initialCategoryId: initialCategoryId,
          isModalDialog: false,
        ),
      ),
    );
  }

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late String _selectedEmoji;
  late String _selectedCategoryId;
  late bool _isPinned;
  late List<NoteBlock> _blocks;

  bool _isSaving = false;
  bool _hasChanges = false;

  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, TextEditingController> _controllers = {};

  final List<String> _emojiOptions = [
    '📝', '💍', '💡', '📍', '🎯', '🚀', '❤️', '💼',
    '📚', '🏠', '✈️', '🛒', '🎨', '🔒', '⭐', '🔥',
    '📌', '🗓️', '🤝', '💰', '🧠', '✨', '⚡', '☕',
  ];

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleController = TextEditingController(text: n?.title ?? '');
    _selectedEmoji = n?.emoji ?? '📝';
    _selectedCategoryId = n?.categoryId ?? widget.initialCategoryId ?? NoteCategory.generalCategoryId;
    _isPinned = n?.isPinned ?? false;

    if (n != null && n.blocks.isNotEmpty) {
      _blocks = n.blocks.map((b) => b.copyWith()).toList();
    } else {
      // Bloque inicial por defecto
      _blocks = [
        NoteBlock(
          id: NoteBlock.generateId(),
          type: BlockType.paragraph,
          content: '',
        ),
      ];
    }

    _titleController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  FocusNode _getFocusNode(String id, {VoidCallback? onEnter}) {
    var node = _focusNodes[id];
    if (node == null) {
      node = FocusNode(debugLabel: 'block_$id');
      _focusNodes[id] = node;
    }
    node.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        onEnter?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    return node;
  }

  TextEditingController _getController(String id, String initialText) {
    return _controllers.putIfAbsent(id, () {
      final ctrl = TextEditingController(text: initialText);
      ctrl.addListener(_markChanged);
      return ctrl;
    });
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _titleController.dispose();
    super.dispose();
  }

  void _addBlock(BlockType type, {int? atIndex}) {
    final newBlock = NoteBlock(
      id: NoteBlock.generateId(),
      type: type,
      content: type == BlockType.callout ? 'Nota importante...' : '',
      calloutIcon: type == BlockType.callout ? '💡' : null,
      children: type == BlockType.toggle
          ? [
              NoteBlock(
                id: NoteBlock.generateId(),
                type: BlockType.paragraph,
                content: '',
              ),
            ]
          : const [],
    );

    setState(() {
      if (atIndex != null && atIndex >= 0 && atIndex <= _blocks.length) {
        _blocks.insert(atIndex, newBlock);
      } else {
        _blocks.add(newBlock);
      }
      _hasChanges = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newBlock.id]?.requestFocus();
    });
  }

  void _handleEnterPressed(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final block = _blocks[index];
    if (block.type == BlockType.toggle) {
      // Enter en el título del desplegable: inserta el primer elemento dentro y lo enfoca
      _insertToggleChild(index, -1, BlockType.paragraph);
      return;
    }

    BlockType nextType;
    switch (block.type) {
      case BlockType.bulletList:
        nextType = BlockType.bulletList;
        break;
      case BlockType.numberedList:
        nextType = BlockType.numberedList;
        break;
      case BlockType.todo:
        nextType = BlockType.todo;
        break;
      case BlockType.heading1:
      case BlockType.heading2:
      case BlockType.heading3:
        nextType = BlockType.paragraph;
        break;
      case BlockType.paragraph:
      default:
        nextType = BlockType.paragraph;
        break;
    }
    _addBlock(nextType, atIndex: index + 1);
  }

  void _updateBlockContent(int index, String newContent) {
    if (index >= 0 && index < _blocks.length) {
      _blocks[index] = _blocks[index].copyWith(content: newContent);
      _markChanged();
    }
  }

  void _updateBlockType(int index, BlockType newType) {
    if (index >= 0 && index < _blocks.length) {
      setState(() {
        _blocks[index] = _blocks[index].copyWith(
          type: newType,
          calloutIcon: newType == BlockType.callout ? '💡' : null,
          children: newType == BlockType.toggle
              ? [
                  NoteBlock(
                    id: NoteBlock.generateId(),
                    type: BlockType.paragraph,
                    content: '',
                  ),
                ]
              : const [],
        );
        _hasChanges = true;
      });
    }
  }

  void _deleteBlock(int index) {
    if (index >= 0 && index < _blocks.length) {
      final blockId = _blocks[index].id;
      _focusNodes[blockId]?.dispose();
      _focusNodes.remove(blockId);
      _controllers[blockId]?.dispose();
      _controllers.remove(blockId);

      setState(() {
        _blocks.removeAt(index);
        if (_blocks.isEmpty) {
          final fallback = NoteBlock(
            id: NoteBlock.generateId(),
            type: BlockType.paragraph,
            content: '',
          );
          _blocks.add(fallback);
        }
        _hasChanges = true;
      });
    }
  }

  // Métodos para elementos dentro de un desplegable (Toggle)
  void _updateToggleChildContent(int blockIndex, int childIndex, String newContent) {
    if (blockIndex >= 0 && blockIndex < _blocks.length) {
      final parent = _blocks[blockIndex];
      if (childIndex >= 0 && childIndex < parent.children.length) {
        final newChildren = List<NoteBlock>.from(parent.children);
        newChildren[childIndex] = newChildren[childIndex].copyWith(content: newContent);
        _blocks[blockIndex] = parent.copyWith(children: newChildren);
        _markChanged();
      }
    }
  }

  void _toggleChildTodo(int blockIndex, int childIndex, bool checked) {
    if (blockIndex >= 0 && blockIndex < _blocks.length) {
      final parent = _blocks[blockIndex];
      if (childIndex >= 0 && childIndex < parent.children.length) {
        final newChildren = List<NoteBlock>.from(parent.children);
        newChildren[childIndex] = newChildren[childIndex].copyWith(isChecked: checked);
        setState(() {
          _blocks[blockIndex] = parent.copyWith(children: newChildren);
          _hasChanges = true;
        });
      }
    }
  }

  void _updateToggleChildType(int blockIndex, int childIndex, BlockType newType) {
    if (blockIndex >= 0 && blockIndex < _blocks.length) {
      final parent = _blocks[blockIndex];
      if (childIndex >= 0 && childIndex < parent.children.length) {
        final newChildren = List<NoteBlock>.from(parent.children);
        newChildren[childIndex] = newChildren[childIndex].copyWith(
          type: newType,
          calloutIcon: newType == BlockType.callout ? '💡' : null,
        );
        setState(() {
          _blocks[blockIndex] = parent.copyWith(children: newChildren);
          _hasChanges = true;
        });
      }
    }
  }

  void _deleteToggleChild(int blockIndex, int childIndex) {
    if (blockIndex >= 0 && blockIndex < _blocks.length) {
      final parent = _blocks[blockIndex];
      if (childIndex >= 0 && childIndex < parent.children.length) {
        final childId = parent.children[childIndex].id;
        _focusNodes[childId]?.dispose();
        _focusNodes.remove(childId);
        _controllers[childId]?.dispose();
        _controllers.remove(childId);

        final newChildren = List<NoteBlock>.from(parent.children);
        newChildren.removeAt(childIndex);
        setState(() {
          _blocks[blockIndex] = parent.copyWith(children: newChildren);
          _hasChanges = true;
        });
      }
    }
  }

  void _insertToggleChild(int blockIndex, int atChildIndex, BlockType type) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) return;
    final parent = _blocks[blockIndex];
    final newChild = NoteBlock(
      id: NoteBlock.generateId(),
      type: type,
      content: type == BlockType.callout ? 'Nota destacada...' : '',
      calloutIcon: type == BlockType.callout ? '💡' : null,
      children: type == BlockType.toggle
          ? [
              NoteBlock(
                id: NoteBlock.generateId(),
                type: BlockType.paragraph,
                content: '',
              ),
            ]
          : const [],
    );

    final newChildren = List<NoteBlock>.from(parent.children);
    final insertIndex = (atChildIndex + 1).clamp(0, newChildren.length);
    newChildren.insert(insertIndex, newChild);

    setState(() {
      _blocks[blockIndex] = parent.copyWith(children: newChildren);
      _hasChanges = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newChild.id]?.requestFocus();
    });
  }

  void _handleToggleChildEnter(int blockIndex, int childIndex) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) return;
    final parent = _blocks[blockIndex];
    if (childIndex < 0 || childIndex >= parent.children.length) return;
    final child = parent.children[childIndex];

    BlockType nextType;
    switch (child.type) {
      case BlockType.bulletList:
        nextType = BlockType.bulletList;
        break;
      case BlockType.numberedList:
        nextType = BlockType.numberedList;
        break;
      case BlockType.todo:
        nextType = BlockType.todo;
        break;
      case BlockType.heading1:
      case BlockType.heading2:
      case BlockType.heading3:
        nextType = BlockType.paragraph;
        break;
      case BlockType.paragraph:
      default:
        nextType = BlockType.paragraph;
        break;
    }
    _insertToggleChild(blockIndex, childIndex, nextType);
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe un título para la nota'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final notasState = Provider.of<NotasState>(context, listen: false);

    try {
      // Sincronizar textos pendientes de los controladores
      for (int i = 0; i < _blocks.length; i++) {
        final b = _blocks[i];
        if (_controllers.containsKey(b.id)) {
          _blocks[i] = b.copyWith(content: _controllers[b.id]!.text);
        }
        if (_blocks[i].children.isNotEmpty) {
          final updatedChildren = _blocks[i].children.map((c) {
            if (_controllers.containsKey(c.id)) {
              return c.copyWith(content: _controllers[c.id]!.text);
            }
            return c;
          }).toList();
          _blocks[i] = _blocks[i].copyWith(children: updatedChildren);
        }
      }

      // Limpiar bloques vacíos excepto si es el único
      final cleanBlocks = _blocks.where((b) {
        if (b.type == BlockType.divider) return true;
        return b.content.trim().isNotEmpty || b.children.isNotEmpty;
      }).toList();

      final effectiveBlocks = cleanBlocks.isEmpty ? _blocks : cleanBlocks;

      if (widget.note != null) {
        final updated = widget.note!.copyWith(
          title: title,
          emoji: _selectedEmoji,
          categoryId: _selectedCategoryId,
          isPinned: _isPinned,
          blocks: effectiveBlocks,
        );
        await notasState.updateNote(updated);
      } else {
        await notasState.createNote(
          title: title,
          emoji: _selectedEmoji,
          categoryId: _selectedCategoryId,
          isPinned: _isPinned,
          blocks: effectiveBlocks,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(widget.note != null ? 'Nota actualizada' : 'Nota creada exitosamente'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _copyMarkdown() {
    final tempNote = NoteItem(
      id: widget.note?.id ?? 'temp',
      title: _titleController.text.trim().isEmpty ? 'Sin título' : _titleController.text.trim(),
      emoji: _selectedEmoji,
      categoryId: _selectedCategoryId,
      blocks: _blocks,
    );
    final md = tempNote.toMarkdown();
    Clipboard.setData(ClipboardData(text: md));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Contenido copiado en formato Markdown'),
          ],
        ),
        backgroundColor: NotasColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Descartar cambios?'),
        content: const Text('Tienes cambios sin guardar en esta nota. Si sales ahora, se perderán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final notasState = Provider.of<NotasState>(context);
    final categories = notasState.categories;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context, categories),
        body: Column(
          children: [
            // Contenido editable scrolleable
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    children: [
                      // Selector de Categoría y Metadatos
                      _buildCategoryAndPinBar(categories),
                      const SizedBox(height: 16),

                      // Emoji + Título Principal
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEmojiPickerButton(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) {
                                if (_blocks.isNotEmpty) {
                                  _focusNodes[_blocks[0].id]?.requestFocus();
                                }
                              },
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: NotasColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Título de la nota...',
                                hintStyle: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFCBD5E1),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              maxLines: null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 14),

                      // Lista de Bloques interactivos
                      ...List.generate(_blocks.length, (index) {
                        final block = _blocks[index];
                        final node = _getFocusNode(block.id, onEnter: () => _handleEnterPressed(index));
                        final ctrl = _getController(block.id, block.content);

                        return NoteBlockWidget(
                          key: ValueKey(block.id),
                          block: block,
                          index: index,
                          isEditable: true,
                          controller: ctrl,
                          focusNode: node,
                          onContentChanged: (newContent) => _updateBlockContent(index, newContent),
                          onTypeChanged: (newType) => _updateBlockType(index, newType),
                          onDelete: () => _deleteBlock(index),
                          onAddBlockBelowWithType: (type) => _addBlock(type, atIndex: index + 1),
                          onEnterPressed: () => _handleEnterPressed(index),
                          // Handlers para elementos dentro de un desplegable
                          onToggleChildContentChanged: (childIndex, content) =>
                              _updateToggleChildContent(index, childIndex, content),
                          onToggleChildTodo: (childIndex, chk) =>
                              _toggleChildTodo(index, childIndex, chk),
                          onToggleChildTypeChanged: (childIndex, type) =>
                              _updateToggleChildType(index, childIndex, type),
                          onToggleChildDelete: (childIndex) =>
                              _deleteToggleChild(index, childIndex),
                          onToggleChildAddBelow: (childIndex, type) =>
                              _insertToggleChild(index, childIndex, type),
                          onToggleChildEnter: (childIndex) =>
                              _handleToggleChildEnter(index, childIndex),
                          getChildFocusNode: (childId, onEnter) =>
                              _getFocusNode(childId, onEnter: onEnter),
                          getChildController: (childId, content) =>
                              _getController(childId, content),
                        );
                      }),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),

            // Barra inferior con herramientas de inserción rápida de bloques
            _buildBottomBlockToolbar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, List<NoteCategory> categories) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: Icon(
          widget.isModalDialog ? Icons.close_rounded : Icons.arrow_back_rounded,
          color: Colors.black87,
        ),
        tooltip: widget.isModalDialog ? 'Cerrar modal' : 'Volver',
        onPressed: () async {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: Text(
        widget.note != null ? 'Editar Nota' : 'Nueva Nota',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.black54),
          tooltip: 'Copiar como Markdown',
          onPressed: _copyMarkdown,
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveNote,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: NotasColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryAndPinBar(List<NoteCategory> categories) {
    final currentCat = categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => NoteCategory.defaultCategories().first,
    );

    return Row(
      children: [
        // Selector de Categoría
        PopupMenuButton<String>(
          initialValue: _selectedCategoryId,
          onSelected: (val) {
            if (val == '__manage__') {
              CategoryManagerDialog.show(context);
            } else {
              setState(() {
                _selectedCategoryId = val;
                _hasChanges = true;
              });
            }
          },
          itemBuilder: (ctx) => [
            ...categories.map((cat) => PopupMenuItem(
                  value: cat.id,
                  child: Row(
                    children: [
                      Text(cat.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(cat.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: '__manage__',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Administrar categorías...', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: currentCat.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: currentCat.color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentCat.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  currentCat.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: currentCat.color,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: currentCat.color),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Botón Pin
        InkWell(
          onTap: () {
            setState(() {
              _isPinned = !_isPinned;
              _hasChanges = true;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isPinned ? Colors.amber.withOpacity(0.15) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isPinned ? Colors.amber[700]!.withOpacity(0.4) : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 15,
                  color: _isPinned ? Colors.amber[800] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _isPinned ? 'Fijada' : 'Fijar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isPinned ? Colors.amber[800] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiPickerButton() {
    return PopupMenuButton<String>(
      tooltip: 'Seleccionar icono',
      onSelected: (emoji) {
        setState(() {
          _selectedEmoji = emoji;
          _hasChanges = true;
        });
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 240,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiOptions.map((e) {
                return InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _selectedEmoji = e;
                      _hasChanges = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(_selectedEmoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  Widget _buildBottomBlockToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Agregar bloque:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            _buildToolbarItem(
              icon: Icons.title_rounded,
              label: 'H1',
              onTap: () => _addBlock(BlockType.heading1),
            ),
            _buildToolbarItem(
              icon: Icons.format_size_rounded,
              label: 'H2',
              onTap: () => _addBlock(BlockType.heading2),
            ),
            _buildToolbarItem(
              icon: Icons.text_fields_rounded,
              label: 'H3',
              onTap: () => _addBlock(BlockType.heading3),
            ),
            _buildToolbarItem(
              icon: Icons.notes_rounded,
              label: 'Texto',
              onTap: () => _addBlock(BlockType.paragraph),
            ),
            _buildToolbarItem(
              icon: Icons.check_box_outlined,
              label: 'Tarea',
              onTap: () => _addBlock(BlockType.todo),
            ),
            _buildToolbarItem(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Viñetas',
              onTap: () => _addBlock(BlockType.bulletList),
            ),
            _buildToolbarItem(
              icon: Icons.format_list_numbered_rounded,
              label: 'Numerada',
              onTap: () => _addBlock(BlockType.numberedList),
            ),
            _buildToolbarItem(
              icon: Icons.arrow_right_rounded,
              label: 'Desplegable',
              onTap: () => _addBlock(BlockType.toggle),
            ),
            _buildToolbarItem(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Destacado',
              onTap: () => _addBlock(BlockType.callout),
            ),
            _buildToolbarItem(
              icon: Icons.horizontal_rule_rounded,
              label: 'Divisor',
              onTap: () => _addBlock(BlockType.divider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF475569)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
