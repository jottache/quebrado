import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood_catalog.dart';
import '../models/mood_log.dart';
import '../models/mood_tag.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';
import '../viewmodels/diario_state.dart';
import 'mood_checkin_sheet.dart';

/// Un registro de ánimo en un timeline: emoji, emociones, contexto, nota y menú.
class MoodLogTile extends StatelessWidget {
  final MoodLog log;
  final bool showDate;
  final bool showSubject;

  const MoodLogTile({super.key, required this.log, this.showDate = false, this.showSubject = false});

  Future<void> _delete(BuildContext context) async {
    final animo = AnimoState.maybeOf(context, listen: false);
    if (animo == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final removed = await animo.deleteLog(log.id);
    if (removed == null) return;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: const Text('Registro eliminado'),
        action: SnackBarAction(label: 'Deshacer', onPressed: () => animo.restoreLog(removed)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = log.valenceMeta;
    final animo = AnimoState.maybeOf(context);
    DiarioState? diario;
    try {
      diario = Provider.of<DiarioState>(context);
    } on ProviderNotFoundException {
      diario = null;
    }

    final tagLabels = log.tagIds
        .map((id) => animo?.tagById(id))
        .whereType<MoodTag>()
        .map((t) => '${t.emoji} ${t.name}')
        .toList();
    final people = log.mentionedContactIds
        .map((id) => diario?.getContactById(id)?.name)
        .whereType<String>()
        .toList();
    final subjectName = (!log.isSelf && showSubject) ? diario?.getContactById(log.contactId!)?.name : null;
    final isPending = animo?.isPending(log.id) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showMoodCheckinSheet(context, existing: log),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: meta.lightColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(meta.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subjectName != null ? '$subjectName · ${meta.label}' : meta.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                          ),
                        ),
                        if (log.isDaily) ...[
                          const SizedBox(width: 6),
                          _badge('Balance del día'),
                        ],
                        if (!log.isSelf) ...[
                          const SizedBox(width: 6),
                          _badge(log.perspective == MoodPerspective.told ? '💬 Me lo contó' : '👁 Percibido'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _formatWhen(log.loggedAt, showDate),
                        if (log.energy != null) 'Energía ${MoodCatalog.energyLabel(log.energy!).toLowerCase()}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 11, color: DiarioColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    if (log.emotions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: log.emotions.map((key) {
                          final emotion = MoodCatalog.emotionByKey(key);
                          final color = emotion?.color ?? DiarioColors.primary;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              MoodCatalog.emotionLabel(key),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (tagLabels.isNotEmpty || people.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [...tagLabels, ...people.map((p) => '@$p')].join('  '),
                        style: const TextStyle(fontSize: 11, color: DiarioColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (log.note != null && log.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        log.note!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: DiarioColors.textPrimary, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              if (isPending)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Tooltip(
                    message: 'Pendiente de sincronizar',
                    child: Icon(Icons.cloud_off_rounded, size: 15, color: DiarioColors.textMuted),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: DiarioColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  if (v == 'edit') showMoodCheckinSheet(context, existing: log);
                  if (v == 'delete') _delete(context);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar', style: TextStyle(color: DiarioColors.rose, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: DiarioColors.surfaceHover, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: DiarioColors.textSecondary)),
    );
  }

  static String _formatWhen(DateTime d, bool withDate) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (!withDate) return time;
    return '${d.day} ${months[d.month - 1]} · $time';
  }
}
