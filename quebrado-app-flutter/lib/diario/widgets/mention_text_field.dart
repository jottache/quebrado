import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/diario_contact.dart';
import '../theme/diario_colors.dart';
import 'diario_image_helper.dart';
import '../../notas/models/note_item.dart';
import '../../notas/theme/notas_colors.dart';

/// Controlador de texto que resalta en tiempo real:
/// 1. Menciones a contactos (@Nombre) con color primario del Diario.
/// 2. Menciones a Notas & Acuerdos (#TituloNota) con color primario de Notas.
class MentionTextEditingController extends TextEditingController {
  final List<DiarioContact> Function() getContacts;
  final List<NoteItem> Function()? getNotes;
  final TextStyle? customMentionStyle;
  final TextStyle? customNoteMentionStyle;

  MentionTextEditingController({
    super.text,
    required this.getContacts,
    this.getNotes,
    this.customMentionStyle,
    this.customNoteMentionStyle,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = style ?? const TextStyle(fontSize: 14, color: DiarioColors.textPrimary);
    final mentionStyle = customMentionStyle ??
        effectiveStyle.copyWith(
          color: DiarioColors.primary,
          fontWeight: FontWeight.w800,
          backgroundColor: DiarioColors.primaryLight.withOpacity(0.55),
        );
    final noteStyle = customNoteMentionStyle ??
        effectiveStyle.copyWith(
          color: NotasColors.primary,
          fontWeight: FontWeight.w800,
          backgroundColor: NotasColors.primaryLight.withOpacity(0.65),
        );

    final rawText = text;
    final hasAt = rawText.contains('@');
    final hasHash = rawText.contains('#') && getNotes != null;

    if (rawText.isEmpty || (!hasAt && !hasHash)) {
      return TextSpan(text: rawText, style: effectiveStyle);
    }

    final contacts = getContacts();
    final notes = getNotes != null ? getNotes!() : <NoteItem>[];

    final contactPatterns = _buildMentionPatterns(contacts);
    final notePatterns = _buildNotePatterns(notes);

    final children = <InlineSpan>[];
    int currentIndex = 0;

    while (currentIndex < rawText.length) {
      final atIndex = rawText.indexOf('@', currentIndex);
      final hashIndex = hasHash ? rawText.indexOf('#', currentIndex) : -1;

      // Determinar cuál símbolo aparece primero
      int nextTriggerIndex = -1;
      String? activeChar;

      if (atIndex != -1 && hashIndex != -1) {
        if (atIndex < hashIndex) {
          nextTriggerIndex = atIndex;
          activeChar = '@';
        } else {
          nextTriggerIndex = hashIndex;
          activeChar = '#';
        }
      } else if (atIndex != -1) {
        nextTriggerIndex = atIndex;
        activeChar = '@';
      } else if (hashIndex != -1) {
        nextTriggerIndex = hashIndex;
        activeChar = '#';
      }

      if (nextTriggerIndex == -1) {
        children.add(TextSpan(text: rawText.substring(currentIndex), style: effectiveStyle));
        break;
      }

      // Agregar texto previo al trigger
      if (nextTriggerIndex > currentIndex) {
        children.add(TextSpan(text: rawText.substring(currentIndex, nextTriggerIndex), style: effectiveStyle));
      }

      final remainingLower = rawText.substring(nextTriggerIndex).toLowerCase();

      if (activeChar == '@') {
        String? matchedPattern;
        for (final entry in contactPatterns.entries) {
          if (remainingLower.startsWith(entry.key)) {
            final patternLen = entry.key.length;
            if (patternLen == remainingLower.length ||
                RegExp(r'[\s,.;:!?\n\r\)]').hasMatch(remainingLower[patternLen])) {
              matchedPattern = entry.key;
              break;
            }
          }
        }

        if (matchedPattern != null) {
          final mentionEnd = nextTriggerIndex + matchedPattern.length;
          final actualMentionText = rawText.substring(nextTriggerIndex, mentionEnd);
          children.add(TextSpan(text: actualMentionText, style: mentionStyle));
          currentIndex = mentionEnd;
        } else {
          children.add(TextSpan(text: '@', style: effectiveStyle.copyWith(color: DiarioColors.primary, fontWeight: FontWeight.bold)));
          currentIndex = nextTriggerIndex + 1;
        }
      } else if (activeChar == '#') {
        String? matchedPattern;
        for (final entry in notePatterns.entries) {
          if (remainingLower.startsWith(entry.key)) {
            final patternLen = entry.key.length;
            if (patternLen == remainingLower.length ||
                RegExp(r'[\s,.;:!?\n\r\)]').hasMatch(remainingLower[patternLen])) {
              matchedPattern = entry.key;
              break;
            }
          }
        }

        if (matchedPattern != null) {
          final mentionEnd = nextTriggerIndex + matchedPattern.length;
          final actualMentionText = rawText.substring(nextTriggerIndex, mentionEnd);
          children.add(TextSpan(text: actualMentionText, style: noteStyle));
          currentIndex = mentionEnd;
        } else {
          children.add(TextSpan(text: '#', style: effectiveStyle.copyWith(color: NotasColors.primary, fontWeight: FontWeight.bold)));
          currentIndex = nextTriggerIndex + 1;
        }
      }
    }

    return TextSpan(children: children);
  }
}

/// Helper privado para extraer patrones de mención de contactos ordenados
Map<String, DiarioContact> _buildMentionPatterns(List<DiarioContact> contacts) {
  final patterns = <String, DiarioContact>{};
  for (final c in contacts) {
    // 1. Nombre completo: "@mariana davila"
    final fullNameKey = '@${c.name.trim().toLowerCase()}';
    if (fullNameKey.length > 1) {
      patterns[fullNameKey] = c;
    }
    // 2. Primer nombre: "@mariana"
    final parts = c.name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      final first = parts.first.trim().toLowerCase();
      if (first.length >= 3) {
        patterns.putIfAbsent('@$first', () => c);
      }
    }
    // 3. Apodo / alias: "@cotiprin"
    if (c.nickname != null && c.nickname!.trim().isNotEmpty) {
      final nickKey = '@${c.nickname!.trim().toLowerCase()}';
      if (nickKey.length > 1) {
        patterns.putIfAbsent(nickKey, () => c);
      }
    }
  }

  // Ordenar por longitud descendente para que los nombres más largos tengan prioridad
  final sortedEntries = patterns.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  return Map.fromEntries(sortedEntries);
}

/// Helper privado para extraer patrones de mención de notas ordenados
Map<String, NoteItem> _buildNotePatterns(List<NoteItem> notes) {
  final patterns = <String, NoteItem>{};
  for (final n in notes) {
    final title = n.title.trim().toLowerCase();
    if (title.isNotEmpty) {
      patterns['#$title'] = n;
    }
  }
  final sortedEntries = patterns.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  return Map.fromEntries(sortedEntries);
}

/// Helper para construir InlineSpans interactivos en modo lectura o tarjetas
class MentionTextSpanHelper {
  static List<InlineSpan> buildSpans({
    required String text,
    required List<DiarioContact> contacts,
    List<NoteItem> notes = const [],
    required TextStyle baseStyle,
    TextStyle? mentionStyle,
    TextStyle? noteMentionStyle,
    void Function(DiarioContact contact)? onContactTap,
    void Function(NoteItem note)? onNoteTap,
  }) {
    final hasAt = text.contains('@') && contacts.isNotEmpty;
    final hasHash = text.contains('#') && notes.isNotEmpty;

    if (text.isEmpty || (!hasAt && !hasHash)) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final effectiveMentionStyle = mentionStyle ??
        baseStyle.copyWith(
          color: DiarioColors.primary,
          fontWeight: FontWeight.w900,
          backgroundColor: DiarioColors.primaryLight.withOpacity(0.7),
          decoration: TextDecoration.underline,
          decorationColor: DiarioColors.primary.withOpacity(0.4),
        );

    final effectiveNoteStyle = noteMentionStyle ??
        baseStyle.copyWith(
          color: NotasColors.primary,
          fontWeight: FontWeight.w900,
          backgroundColor: NotasColors.primaryLight.withOpacity(0.8),
          decoration: TextDecoration.underline,
          decorationColor: NotasColors.primary.withOpacity(0.4),
        );

    final contactPatterns = _buildMentionPatterns(contacts);
    final notePatterns = _buildNotePatterns(notes);

    final children = <InlineSpan>[];
    int currentIndex = 0;

    while (currentIndex < text.length) {
      final atIndex = text.indexOf('@', currentIndex);
      final hashIndex = hasHash ? text.indexOf('#', currentIndex) : -1;

      int nextTriggerIndex = -1;
      String? activeChar;

      if (atIndex != -1 && hashIndex != -1) {
        if (atIndex < hashIndex) {
          nextTriggerIndex = atIndex;
          activeChar = '@';
        } else {
          nextTriggerIndex = hashIndex;
          activeChar = '#';
        }
      } else if (atIndex != -1) {
        nextTriggerIndex = atIndex;
        activeChar = '@';
      } else if (hashIndex != -1) {
        nextTriggerIndex = hashIndex;
        activeChar = '#';
      }

      if (nextTriggerIndex == -1) {
        children.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
        break;
      }

      if (nextTriggerIndex > currentIndex) {
        children.add(TextSpan(text: text.substring(currentIndex, nextTriggerIndex), style: baseStyle));
      }

      final remainingLower = text.substring(nextTriggerIndex).toLowerCase();

      if (activeChar == '@') {
        String? matchedPattern;
        DiarioContact? matchedContact;

        for (final entry in contactPatterns.entries) {
          if (remainingLower.startsWith(entry.key)) {
            final patternLen = entry.key.length;
            if (patternLen == remainingLower.length ||
                RegExp(r'[\s,.;:!?\n\r\)]').hasMatch(remainingLower[patternLen])) {
              matchedPattern = entry.key;
              matchedContact = entry.value;
              break;
            }
          }
        }

        if (matchedPattern != null && matchedContact != null) {
          final mentionEnd = nextTriggerIndex + matchedPattern.length;
          final targetContact = matchedContact;
          final actualMentionText = text.substring(nextTriggerIndex, mentionEnd);

          children.add(
            TextSpan(
              text: actualMentionText,
              style: effectiveMentionStyle,
              recognizer: onContactTap != null
                  ? (TapGestureRecognizer()
                    ..onTap = () {
                      onContactTap(targetContact);
                    })
                  : null,
            ),
          );
          currentIndex = mentionEnd;
        } else {
          children.add(TextSpan(text: '@', style: baseStyle));
          currentIndex = nextTriggerIndex + 1;
        }
      } else if (activeChar == '#') {
        String? matchedPattern;
        NoteItem? matchedNote;

        for (final entry in notePatterns.entries) {
          if (remainingLower.startsWith(entry.key)) {
            final patternLen = entry.key.length;
            if (patternLen == remainingLower.length ||
                RegExp(r'[\s,.;:!?\n\r\)]').hasMatch(remainingLower[patternLen])) {
              matchedPattern = entry.key;
              matchedNote = entry.value;
              break;
            }
          }
        }

        if (matchedPattern != null && matchedNote != null) {
          final mentionEnd = nextTriggerIndex + matchedPattern.length;
          final targetNote = matchedNote;
          final actualMentionText = text.substring(nextTriggerIndex, mentionEnd);

          children.add(
            TextSpan(
              text: actualMentionText,
              style: effectiveNoteStyle,
              recognizer: onNoteTap != null
                  ? (TapGestureRecognizer()
                    ..onTap = () {
                      onNoteTap(targetNote);
                    })
                  : null,
            ),
          );
          currentIndex = mentionEnd;
        } else {
          children.add(TextSpan(text: '#', style: baseStyle));
          currentIndex = nextTriggerIndex + 1;
        }
      }
    }

    return children;
  }
}

/// Widget contenedor con Overlay inteligente para autocompletar menciones:
/// - '@' para autocompletar contactos del Diario
/// - '#' para autocompletar notas y acuerdos de Notas & Acuerdos
class MentionAutocompleteField extends StatefulWidget {
  final MentionTextEditingController controller;
  final List<DiarioContact> contacts;
  final List<NoteItem> notes;
  final void Function(DiarioContact contact)? onMentionSelected;
  final void Function(NoteItem note)? onNoteMentionSelected;
  final InputDecoration? decoration;
  final int maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const MentionAutocompleteField({
    super.key,
    required this.controller,
    required this.contacts,
    this.notes = const [],
    this.onMentionSelected,
    this.onNoteMentionSelected,
    this.decoration,
    this.maxLines = 4,
    this.minLines,
    this.focusNode,
    this.onChanged,
  });

  @override
  State<MentionAutocompleteField> createState() => _MentionAutocompleteFieldState();
}

class _MentionAutocompleteFieldState extends State<MentionAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  late FocusNode _focusNode;
  bool _internalFocus = false;
  OverlayEntry? _overlayEntry;
  final ScrollController _scrollController = ScrollController();

  String? _activeTrigger; // '@' o '#'
  String? _activeQuery;
  int _triggerCharIndex = -1;
  int _lastValidTriggerIndex = -1;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _internalFocus = true;
    }

    _focusNode.onKeyEvent = _handleKeyEvent;
    widget.controller.addListener(_handleTextOrSelectionChange);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(MentionAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (_internalFocus) {
        _focusNode.dispose();
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _internalFocus = false;
      } else {
        _focusNode = FocusNode();
        _internalFocus = true;
      }
      _focusNode.onKeyEvent = _handleKeyEvent;
      _focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    widget.controller.removeListener(_handleTextOrSelectionChange);
    _focusNode.removeListener(_handleFocusChange);
    _scrollController.dispose();
    if (_internalFocus) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_overlayEntry == null) return KeyEventResult.ignored;

    final totalCount = _activeTrigger == '#'
        ? _getFilteredNotes().length
        : _getFilteredContacts().length;

    if (totalCount == 0) return KeyEventResult.ignored;

    final isArrowDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isArrowUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter;
    final isEscape = event.logicalKey == LogicalKeyboardKey.escape;
    final isTab = event.logicalKey == LogicalKeyboardKey.tab;

    if (!isArrowDown && !isArrowUp && !isEnter && !isEscape && !isTab) {
      return KeyEventResult.ignored;
    }

    if (event is KeyUpEvent) {
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (isArrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % totalCount;
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToSelected();
        return KeyEventResult.handled;
      }

      if (isArrowUp) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + totalCount) % totalCount;
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToSelected();
        return KeyEventResult.handled;
      }

      if (isEnter || isTab) {
        if (_activeTrigger == '#') {
          final notes = _getFilteredNotes();
          if (_selectedIndex >= 0 && _selectedIndex < notes.length) {
            _selectNote(notes[_selectedIndex]);
            return KeyEventResult.handled;
          }
        } else {
          final contacts = _getFilteredContacts();
          if (_selectedIndex >= 0 && _selectedIndex < contacts.length) {
            _selectContact(contacts[_selectedIndex]);
            return KeyEventResult.handled;
          }
        }
      }

      if (isEscape) {
        _removeOverlay();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        const itemHeight = 44.0;
        final targetOffset = (_selectedIndex * itemHeight).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 60),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleTextOrSelectionChange() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _removeOverlay();
      return;
    }

    final cursor = selection.baseOffset;
    if (cursor == 0) {
      _removeOverlay();
      return;
    }

    final textBeforeCursor = text.substring(0, cursor);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');
    final lastHashIndex = textBeforeCursor.lastIndexOf('#');

    int triggerIndex = -1;
    String? triggerChar;

    if (lastAtIndex != -1 && lastHashIndex != -1) {
      if (lastAtIndex > lastHashIndex) {
        triggerIndex = lastAtIndex;
        triggerChar = '@';
      } else {
        triggerIndex = lastHashIndex;
        triggerChar = '#';
      }
    } else if (lastAtIndex != -1) {
      triggerIndex = lastAtIndex;
      triggerChar = '@';
    } else if (lastHashIndex != -1) {
      triggerIndex = lastHashIndex;
      triggerChar = '#';
    }

    if (triggerIndex == -1) {
      _removeOverlay();
      return;
    }

    final queryCandidate = textBeforeCursor.substring(triggerIndex + 1);
    if (queryCandidate.contains('\n') || queryCandidate.contains('\r')) {
      _removeOverlay();
      return;
    }

    if (triggerIndex > 0) {
      final prevChar = textBeforeCursor[triggerIndex - 1];
      if (!RegExp(r'[\s\(\[\{]').hasMatch(prevChar)) {
        _removeOverlay();
        return;
      }
    }

    final newQuery = queryCandidate.trim().toLowerCase();
    if (_activeQuery != newQuery || _activeTrigger != triggerChar) {
      _selectedIndex = 0;
    }

    _activeTrigger = triggerChar;
    _triggerCharIndex = triggerIndex;
    _lastValidTriggerIndex = triggerIndex;
    _activeQuery = newQuery;
    _showOrUpdateOverlay();
  }

  List<DiarioContact> _getFilteredContacts() {
    if (_activeQuery == null) return [];
    if (_activeQuery!.isEmpty) {
      return widget.contacts.take(8).toList();
    }
    final q = _activeQuery!;
    return widget.contacts.where((c) {
      final inName = c.name.toLowerCase().contains(q);
      final inNickname = (c.nickname ?? '').toLowerCase().contains(q);
      final inRel = (c.relationship ?? '').toLowerCase().contains(q);
      return inName || inNickname || inRel;
    }).take(8).toList();
  }

  List<NoteItem> _getFilteredNotes() {
    if (_activeQuery == null) return [];
    if (_activeQuery!.isEmpty) {
      return widget.notes.take(8).toList();
    }
    final q = _activeQuery!;
    return widget.notes.where((n) {
      return n.title.toLowerCase().contains(q);
    }).take(8).toList();
  }

  void _showOrUpdateOverlay() {
    final bool isEmpty = _activeTrigger == '#'
        ? _getFilteredNotes().isEmpty
        : _getFilteredContacts().isEmpty;

    if (isEmpty || !_focusNode.hasFocus) {
      _removeOverlay();
      return;
    }

    final length = _activeTrigger == '#'
        ? _getFilteredNotes().length
        : _getFilteredContacts().length;

    if (_selectedIndex >= length) {
      _selectedIndex = 0;
    }

    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _activeTrigger = null;
    _activeQuery = null;
    _triggerCharIndex = -1;
    _selectedIndex = 0;
  }

  void _selectContact(DiarioContact contact) {
    final targetIndex = _triggerCharIndex != -1 ? _triggerCharIndex : _lastValidTriggerIndex;
    if (targetIndex == -1) return;

    final text = widget.controller.text;
    if (targetIndex >= text.length) return;

    int tokenEnd = targetIndex + 1;
    while (tokenEnd < text.length && !RegExp(r'[\s,.;:!?\n\r]').hasMatch(text[tokenEnd])) {
      tokenEnd++;
    }

    final beforeAt = text.substring(0, targetIndex);
    final afterToken = tokenEnd <= text.length ? text.substring(tokenEnd) : '';

    final mentionInsertion = '@${contact.name} ';
    final newText = '$beforeAt$mentionInsertion$afterToken';
    final newCursor = beforeAt.length + mentionInsertion.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    widget.onMentionSelected?.call(contact);
    _removeOverlay();
    _focusNode.requestFocus();
  }

  void _selectNote(NoteItem note) {
    final targetIndex = _triggerCharIndex != -1 ? _triggerCharIndex : _lastValidTriggerIndex;
    if (targetIndex == -1) return;

    final text = widget.controller.text;
    if (targetIndex >= text.length) return;

    int tokenEnd = targetIndex + 1;
    while (tokenEnd < text.length && !RegExp(r'[\s,.;:!?\n\r]').hasMatch(text[tokenEnd])) {
      tokenEnd++;
    }

    final beforeHash = text.substring(0, targetIndex);
    final afterToken = tokenEnd <= text.length ? text.substring(tokenEnd) : '';

    final mentionInsertion = '#${note.title} ';
    final newText = '$beforeHash$mentionInsertion$afterToken';
    final newCursor = beforeHash.length + mentionInsertion.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    widget.onNoteMentionSelected?.call(note);
    _removeOverlay();
    _focusNode.requestFocus();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(300, 100);

    return OverlayEntry(
      builder: (context) {
        final isNoteMode = _activeTrigger == '#';
        final filteredContacts = !isNoteMode ? _getFilteredContacts() : <DiarioContact>[];
        final filteredNotes = isNoteMode ? _getFilteredNotes() : <NoteItem>[];

        final int count = isNoteMode ? filteredNotes.length : filteredContacts.length;
        if (count == 0) return const SizedBox.shrink();

        final primaryColor = isNoteMode ? NotasColors.primary : DiarioColors.primary;
        final primaryLight = isNoteMode ? NotasColors.primaryLight : DiarioColors.primaryLight;

        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0.0, size.height + 6.0),
            child: FocusScope(
              canRequestFocus: false,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.black.withOpacity(0.18),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.25), width: 1.2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryLight,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isNoteMode ? Icons.tag_rounded : Icons.alternate_email_rounded,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isNoteMode ? 'Mencionar nota o acuerdo' : 'Mencionar contacto',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              count == 1
                                  ? '1 coincidencia • ↵ elegir'
                                  : '$count sugerencias • ↑↓ / ↵',
                              style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: count,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 48, color: DiarioColors.cardBorder),
                          itemBuilder: (context, index) {
                            final isSelected = index == _selectedIndex;

                            if (isNoteMode) {
                              final note = filteredNotes[index];
                              return MouseRegion(
                                onEnter: (_) {
                                  if (_selectedIndex != index) {
                                    setState(() => _selectedIndex = index);
                                    _overlayEntry?.markNeedsBuild();
                                  }
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (_) => _selectNote(note),
                                  child: InkWell(
                                    onTap: () => _selectNote(note),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? primaryLight.withOpacity(0.7) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected
                                            ? Border.all(color: primaryColor.withOpacity(0.35), width: 1)
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: primaryLight,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(note.emoji, style: const TextStyle(fontSize: 16)),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              note.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                                color: isSelected ? primaryColor : DiarioColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelected)
                                            Container(
                                              margin: const EdgeInsets.only(left: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: primaryColor,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.keyboard_return_rounded, size: 10, color: Colors.white),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'Enter',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final c = filteredContacts[index];
                            return MouseRegion(
                              onEnter: (_) {
                                if (_selectedIndex != index) {
                                  setState(() => _selectedIndex = index);
                                  _overlayEntry?.markNeedsBuild();
                                }
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) => _selectContact(c),
                                child: InkWell(
                                  onTap: () => _selectContact(c),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? primaryLight.withOpacity(0.7) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(color: primaryColor.withOpacity(0.35), width: 1)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isSelected ? primaryColor.withOpacity(0.18) : primaryLight,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                                              ? ClipOval(
                                                  child: DiarioImageHelper.buildImageWidget(
                                                    c.avatarUrl!,
                                                    width: 32,
                                                    height: 32,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Text(
                                                  c.initials,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                c.name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                                  color: isSelected ? primaryColor : DiarioColors.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (c.nickname != null && c.nickname!.isNotEmpty)
                                                Text(
                                                  '"${c.nickname}"',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: DiarioColors.textSecondary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (c.relationship != null && c.relationship!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: DiarioColors.surfaceHover,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              c.relationship!,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: DiarioColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        if (isSelected)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: primaryColor,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.keyboard_return_rounded, size: 10, color: Colors.white),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Enter',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        onChanged: widget.onChanged,
        decoration: widget.decoration ??
            InputDecoration(
              hintText: 'Escribe algo (@ para contactos, # para notas)...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: DiarioColors.background,
            ),
      ),
    );
  }
}
