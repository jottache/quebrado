import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood_catalog.dart';
import '../models/mood_log.dart';
import '../models/mood_tag.dart';
import '../services/speech_recognition_service.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';
import '../viewmodels/diario_state.dart';
import 'mention_text_field.dart';
import 'mood_emotion_picker.dart';
import '../../recordatorios/models/role_model.dart';
import '../../recordatorios/viewmodels/reminders_state.dart';
import '../../widgets/responsive_sheet_helper.dart';

/// Abre el formulario completo de ánimo (crear o editar).
/// - [contactId] null → ánimo propio; con valor → ánimo percibido de ese contacto.
/// - [existing] → edita un registro existente.
Future<void> showMoodCheckinSheet(
  BuildContext context, {
  MoodLog? existing,
  String? contactId,
  int? initialValence,
  DateTime? initialDate,
  MoodSource source = MoodSource.manual,
}) {
  return showResponsiveSheet(
    context: context,
    desktopWidth: 520,
    builder: (_) => MoodCheckinSheet(
      existing: existing,
      contactId: existing?.contactId ?? contactId,
      initialValence: initialValence,
      initialDate: initialDate,
      source: source,
    ),
  );
}

class MoodCheckinSheet extends StatefulWidget {
  final MoodLog? existing;
  final String? contactId;
  final int? initialValence;
  final DateTime? initialDate;
  final MoodSource source;

  const MoodCheckinSheet({
    super.key,
    this.existing,
    this.contactId,
    this.initialValence,
    this.initialDate,
    this.source = MoodSource.manual,
  });

  @override
  State<MoodCheckinSheet> createState() => _MoodCheckinSheetState();
}

class _MoodCheckinSheetState extends State<MoodCheckinSheet> {
  late int? _valence;
  late MoodPerspective _perspective;
  late int? _energy;
  late List<String> _emotions;
  late Set<String> _tagIds;
  late Set<String> _roleIds;
  late bool _isDaily;
  late DateTime _loggedAt;
  late MentionTextEditingController _noteController;

  bool _isListening = false;
  String _speechSnapshot = '';
  bool _isSaving = false;

  bool get _isSelf => widget.contactId == null || widget.contactId!.isEmpty;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _valence = e?.valence ?? widget.initialValence;
    _perspective = e?.perspective ?? (_isSelf ? MoodPerspective.self : MoodPerspective.observed);
    _energy = e?.energy;
    _emotions = List<String>.from(e?.emotions ?? const []);
    _tagIds = Set<String>.from(e?.tagIds ?? const []);
    _roleIds = Set<String>.from(e?.roleIds ?? const []);
    _isDaily = e?.isDaily ?? false;
    _loggedAt = e?.loggedAt ?? widget.initialDate ?? DateTime.now();
    _noteController = MentionTextEditingController(
      text: e?.note ?? '',
      getContacts: () {
        if (!mounted) return [];
        return _diarioState?.contacts ?? [];
      },
    );
  }

  @override
  void dispose() {
    if (_isListening) SpeechRecognitionService.instance.stopListening();
    _noteController.dispose();
    super.dispose();
  }

  DiarioState? get _diarioState {
    try {
      return Provider.of<DiarioState>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  List<RoleModel> _availableRoles(BuildContext context) {
    try {
      return Provider.of<RemindersState>(context).roles.where((r) => !r.archived).toList();
    } on ProviderNotFoundException {
      return const [];
    }
  }

  String get _subjectName {
    if (_isSelf) return '';
    final contact = _diarioState?.getContactById(widget.contactId!);
    return contact?.nickname?.isNotEmpty == true ? contact!.nickname! : (contact?.name ?? 'este contacto');
  }

  // ===========================================================================
  // ACCIONES
  // ===========================================================================

  Future<void> _toggleVoice() async {
    final speech = SpeechRecognitionService.instance;
    if (_isListening) {
      await speech.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    _speechSnapshot = _noteController.text;
    final started = await speech.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          final prefix = _speechSnapshot.isNotEmpty ? '$_speechSnapshot ' : '';
          _noteController.text = '$prefix$words';
          _noteController.selection = TextSelection.fromPosition(
            TextPosition(offset: _noteController.text.length),
          );
        });
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!mounted) return;
    setState(() => _isListening = started);
    if (!started) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo activar el micrófono o no hay permisos concedidos.')),
      );
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt.isAfter(now) ? now : _loggedAt,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now,
      helpText: '¿Qué día fue?',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
      helpText: '¿A qué hora?',
    );
    if (!mounted) return;
    var picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? _loggedAt.hour,
      time?.minute ?? _loggedAt.minute,
    );
    if (picked.isAfter(now)) picked = now;
    setState(() => _loggedAt = picked);
  }

  Future<void> _createTag(AnimoState animo) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva etiqueta', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej: Fútbol, Terapia, Viaje...'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(backgroundColor: DiarioColors.primary),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final tag = await animo.addTag(name: name);
    if (mounted) setState(() => _tagIds.add(tag.id));
  }

  Future<void> _save() async {
    final valence = _valence;
    if (valence == null || _isSaving) return;
    final animo = AnimoState.maybeOf(context, listen: false);
    if (animo == null) return;

    setState(() => _isSaving = true);
    if (_isListening) await SpeechRecognitionService.instance.stopListening();

    final note = _noteController.text.trim();
    // Solo cuenta a quien siga mencionado en el texto final.
    final mentioned = <String>{...?_diarioState?.extractMentionedContactIds(note)}..remove(widget.contactId);

    final existing = widget.existing;
    if (existing != null) {
      await animo.updateLog(existing.copyWith(
        valence: valence,
        perspective: _perspective,
        kind: _isDaily ? MoodKind.daily : MoodKind.momentary,
        energy: _energy,
        clearEnergy: _energy == null,
        emotions: _emotions,
        tagIds: _tagIds.toList(),
        roleIds: _roleIds.toList(),
        mentionedContactIds: mentioned.toList(),
        note: note.isEmpty ? null : note,
        clearNote: note.isEmpty,
        loggedAt: _loggedAt,
      ));
    } else {
      await animo.addLog(
        valence: valence,
        contactId: widget.contactId,
        perspective: _perspective,
        kind: _isDaily ? MoodKind.daily : MoodKind.momentary,
        energy: _energy,
        emotions: _emotions,
        tagIds: _tagIds.toList(),
        roleIds: _roleIds.toList(),
        mentionedContactIds: mentioned.toList(),
        note: note.isEmpty ? null : note,
        source: widget.source,
        loggedAt: _loggedAt,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final animo = AnimoState.maybeOf(context);
    final roles = _isSelf ? _availableRoles(context) : const <RoleModel>[];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: DiarioColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildValenceSelector(),
                  if (!_isSelf) ...[
                    const SizedBox(height: 14),
                    _buildPerspectiveToggle(),
                  ],
                  if (_valence != null) ...[
                    if (_isSelf) ...[
                      _sectionTitle('Energía', optional: true),
                      _buildEnergySelector(),
                    ],
                    _sectionTitle('¿Qué emociones?', optional: true, trailing: '${_emotions.length}/3'),
                    MoodEmotionPicker(
                      valence: _valence!,
                      energy: _energy,
                      selected: _emotions,
                      onChanged: (v) => setState(() => _emotions = v),
                    ),
                    if (animo != null) _buildTagsSection(animo),
                    if (roles.isNotEmpty) _buildRolesSection(roles),
                    _sectionTitle('Nota', optional: true),
                    _buildNoteField(),
                    const SizedBox(height: 8),
                    _buildOptions(),
                  ],
                ],
              ),
            ),
          ),
          _buildSaveBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final title = _isEditing
        ? 'Editar registro'
        : (_isSelf ? '¿Cómo te sientes?' : '¿Cómo viste a $_subjectName?');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: DiarioColors.cardBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                    ),
                    if (!_isSelf)
                      const Text(
                        'Ánimo percibido · es tu percepción, no su auto-reporte',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DiarioColors.textSecondary),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {bool optional = false, String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary)),
          if (optional) ...[
            const SizedBox(width: 6),
            const Text('opcional', style: TextStyle(fontSize: 11, color: DiarioColors.textMuted, fontWeight: FontWeight.w600)),
          ],
          const Spacer(),
          if (trailing != null)
            Text(trailing, style: const TextStyle(fontSize: 11, color: DiarioColors.textMuted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildValenceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: MoodCatalog.valences.map((meta) {
          final isSelected = _valence == meta.value;
          return Expanded(
            child: InkWell(
              key: ValueKey('mood_sheet_valence_${meta.value}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _valence = meta.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? meta.lightColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? meta.color : Colors.transparent, width: 1.5),
                ),
                child: Column(
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.18 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Text(meta.emoji, style: const TextStyle(fontSize: 30)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? DiarioColors.textPrimary : DiarioColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerspectiveToggle() {
    return SegmentedButton<MoodPerspective>(
      segments: const [
        ButtonSegment(
          value: MoodPerspective.observed,
          icon: Icon(Icons.visibility_outlined, size: 16),
          label: Text('Lo noté yo'),
        ),
        ButtonSegment(
          value: MoodPerspective.told,
          icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
          label: Text('Me lo contó'),
        ),
      ],
      selected: {_perspective},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _perspective = s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: DiarioColors.primaryLight,
        selectedForegroundColor: DiarioColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  Widget _buildEnergySelector() {
    return Row(
      children: List.generate(5, (i) {
        final level = i + 1;
        final isSelected = _energy == level;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 4 ? 0 : 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _energy = isSelected ? null : level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? DiarioColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? DiarioColors.primary : DiarioColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        level,
                        (_) => Container(
                          width: 4,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : DiarioColors.primary.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      MoodCatalog.energyLabel(level),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : DiarioColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTagsSection(AnimoState animo) {
    final grouped = <String, List<MoodTag>>{};
    for (final tag in animo.tags) {
      grouped.putIfAbsent(tag.groupKey, () => []).add(tag);
    }
    final order = MoodTag.groupLabels.keys.where(grouped.containsKey).toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in order) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Text(
              MoodTag.groupLabel(group),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DiarioColors.textSecondary),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: grouped[group]!.map((tag) => _tagChip(tag)).toList(),
          ),
          const SizedBox(height: 8),
        ],
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 16, color: DiarioColors.primary),
          label: const Text('Nueva etiqueta'),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DiarioColors.primary),
          backgroundColor: DiarioColors.primaryLight,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onPressed: () => _createTag(animo),
        ),
      ],
    );

    if (_isSelf) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('¿Qué estaba pasando?', optional: true, trailing: _tagIds.isEmpty ? null : '${_tagIds.length}'),
          content,
        ],
      );
    }

    // En contactos el contexto es secundario: colapsado.
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: _tagIds.isNotEmpty,
          title: Text(
            _tagIds.isEmpty ? 'Agregar contexto (opcional)' : 'Contexto · ${_tagIds.length}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
          ),
          children: [content],
        ),
      ),
    );
  }

  Widget _tagChip(MoodTag tag) {
    final isSelected = _tagIds.contains(tag.id);
    return FilterChip(
      label: Text('${tag.emoji} ${tag.name}'),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (v) => setState(() => v ? _tagIds.add(tag.id) : _tagIds.remove(tag.id)),
      selectedColor: DiarioColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
        color: isSelected ? Colors.white : DiarioColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? DiarioColors.primary : DiarioColors.cardBorder),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRolesSection(List<RoleModel> roles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('¿Con qué rol se relaciona?', optional: true),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: roles.map((role) {
            final isSelected = _roleIds.contains(role.id);
            return FilterChip(
              avatar: Icon(role.iconData, size: 15, color: isSelected ? Colors.white : role.color),
              label: Text(role.name),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (v) => setState(() => v ? _roleIds.add(role.id) : _roleIds.remove(role.id)),
              selectedColor: role.color,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? Colors.white : DiarioColors.textPrimary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isSelected ? role.color : role.color.withOpacity(0.35)),
              ),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    final contacts = _diarioState?.contacts ?? const [];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isListening ? DiarioColors.primary : DiarioColors.cardBorder,
          width: _isListening ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MentionAutocompleteField(
              controller: _noteController,
              contacts: contacts,
              maxLines: 5,
              minLines: 2,
              decoration: InputDecoration(
                hintText: _isSelf
                    ? '¿Qué pasó? Menciona personas con @...'
                    : '¿Qué notaste? ¿Qué te contó?',
                border: InputBorder.none,
                hintStyle: const TextStyle(fontSize: 13, color: DiarioColors.textMuted),
              ),
            ),
          ),
          IconButton(
            tooltip: _isListening ? 'Detener dictado' : 'Dictar por voz',
            icon: Icon(
              _isListening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
              color: _isListening ? DiarioColors.rose : DiarioColors.primary,
            ),
            onPressed: _toggleVoice,
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    final now = DateTime.now();
    final isNow = now.difference(_loggedAt).inMinutes.abs() < 2;
    final dateLabel = isNow ? 'Ahora' : _formatDateTime(_loggedAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: _isDaily,
            onChanged: (v) => setState(() => _isDaily = v),
            activeColor: DiarioColors.primary,
            dense: true,
            title: Text(
              _isSelf ? 'Es mi balance del día' : 'Es el balance de su día',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            subtitle: const Text(
              'Si lo marcas, cuenta como el valor del día',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.schedule_rounded, color: DiarioColors.primary),
            title: const Text('¿Fue en otro momento?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            trailing: Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w700, color: DiarioColors.textSecondary)),
            onTap: _pickDateTime,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    final canSave = _valence != null && !_isSaving;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: DiarioColors.cardBorder)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const ValueKey('mood_sheet_save'),
            onPressed: canSave ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: DiarioColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(
              _valence == null ? 'Elige cómo te sientes' : (_isEditing ? 'Guardar cambios' : 'Guardar'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime d) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} · $hh:$mm';
  }
}
