import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/diario_state.dart';
import '../services/speech_recognition_service.dart';
import '../widgets/mention_text_field.dart';
import '../../notas/notas.dart';

class QuickNoteDialog extends StatefulWidget {
  final bool autoStartVoice;

  const QuickNoteDialog({
    super.key,
    this.autoStartVoice = false,
  });

  @override
  State<QuickNoteDialog> createState() => _QuickNoteDialogState();
}

class _QuickNoteDialogState extends State<QuickNoteDialog> {
  late MentionTextEditingController _textController;
  final Set<String> _mentionedContactIds = {};
  bool _isListening = false;
  String _speechTextSnapshot = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = MentionTextEditingController(
      getContacts: () {
        if (!mounted) return [];
        return Provider.of<DiarioState>(context, listen: false).contacts;
      },
    );
    if (widget.autoStartVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleVoiceDictation();
      });
    }
  }

  @override
  void dispose() {
    if (_isListening) {
      SpeechRecognitionService.instance.stopListening();
    }
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceDictation() async {
    if (_isListening) {
      await SpeechRecognitionService.instance.stopListening();
      if (mounted) setState(() => _isListening = false);
    } else {
      _speechTextSnapshot = _textController.text;
      final started = await SpeechRecognitionService.instance.startListening(
        onResult: (words, isFinal) {
          if (mounted) {
            setState(() {
              final prefix = _speechTextSnapshot.isNotEmpty ? '$_speechTextSnapshot ' : '';
              _textController.text = '$prefix$words';
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
      );

      if (mounted) {
        setState(() => _isListening = started);
        if (!started) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo activar el micrófono o no hay permisos concedidos.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveQuickNote() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe o dicta algún texto para registrar la nota.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isListening) {
      await SpeechRecognitionService.instance.stopListening();
      _isListening = false;
    }

    setState(() => _isSaving = true);
    try {
      final state = Provider.of<DiarioState>(context, listen: false);
      final notasState = Provider.of<NotasState>(context, listen: false);
      final mentionsList = state.extractMentionedContactIds(text);
      final noteMentionsList = state.extractMentionedNoteIds(text, notasState.notes);
      await state.addPersonalEntry(
        title: '',
        contentText: text,
        mentionedContactIds: mentionsList,
        mentionedNoteIds: noteMentionsList,
        isPinned: false,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nota rápida registrada exitosamente.'),
            backgroundColor: DiarioColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: DiarioColors.rose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: DiarioColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nota Rápida',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: DiarioColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Guarda una idea o pensamiento al instante',
                          style: TextStyle(
                            fontSize: 12,
                            color: DiarioColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: DiarioColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Text Area
              Container(
                decoration: BoxDecoration(
                  color: DiarioColors.surfaceHover,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isListening ? DiarioColors.primary : DiarioColors.cardBorder,
                    width: _isListening ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: MentionAutocompleteField(
                  controller: _textController,
                  contacts: Provider.of<DiarioState>(context).contacts,
                  notes: Provider.of<NotasState>(context).notes,
                  maxLines: 5,
                  minLines: 3,
                  onMentionSelected: (contact) {
                    _mentionedContactIds.add(contact.id);
                  },
                  decoration: const InputDecoration(
                    hintText: '¿Qué estás pensando? Escribe (@ personas, # notas) o dicta...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: DiarioColors.textMuted,
                      height: 1.4,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Dictation Button / Listening Indicator
              InkWell(
                onTap: _toggleVoiceDictation,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? DiarioColors.rose.withOpacity(0.12)
                        : DiarioColors.primaryLight.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isListening
                          ? DiarioColors.rose.withOpacity(0.4)
                          : DiarioColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 20,
                        color: _isListening ? DiarioColors.rose : DiarioColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isListening ? 'Escuchando... Toca para detener' : 'Grabar por voz mientras hablas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isListening ? DiarioColors.rose : DiarioColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action button: Registrar Nota
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveQuickNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DiarioColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Registrar Nota',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
