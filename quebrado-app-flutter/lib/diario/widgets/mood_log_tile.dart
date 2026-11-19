import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood_catalog.dart';
import '../models/mood_log.dart';
import '../models/mood_tag.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';
import '../viewmodels/diario_state.dart';
import 'mood_checkin_sheet.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
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

    // Sin tarjeta (spec 05): fila sobre el fondo; al pasar o pulsar, `surfaceHigh`.
    return Padding(
      padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
      child: InkWell(
        hoverColor: DiarioColors.surfaceHover,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        onTap: () => showMoodCheckinSheet(context, existing: log),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OrtizSpace.md, OrtizSpace.sm, OrtizSpace.xs, OrtizSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: meta.lightColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(meta.emoji, style: const TextStyle(fontSize: OrtizFontSize.display)),
              ),
              const SizedBox(width: OrtizSpace.sm),
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
                            style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                          ),
                        ),
                        if (log.isDaily) ...[
                          const SizedBox(width: OrtizSpace.xs),
                          _badge('Balance del día'),
                        ],
                        if (!log.isSelf) ...[
                          const SizedBox(width: OrtizSpace.xs),
                          _badge(log.perspective == MoodPerspective.told ? '💬 Me lo contó' : '👁 Percibido'),
                        ],
                      ],
                    ),
                    const SizedBox(height: OrtizSpace.xxs),
                    Text(
                      [
                        _formatWhen(log.loggedAt, showDate),
                        if (log.energy != null) 'Energía ${MoodCatalog.energyLabel(log.energy!).toLowerCase()}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: OrtizFontSize.caption, color: DiarioColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    if (log.emotions.isNotEmpty) ...[
                      const SizedBox(height: OrtizSpace.xs),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: log.emotions.map((key) {
                          final emotion = MoodCatalog.emotionByKey(key);
                          final color = emotion?.color ?? DiarioColors.primary;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: Text(
                              MoodCatalog.emotionLabel(key),
                              style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: color),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (tagLabels.isNotEmpty || people.isNotEmpty) ...[
                      const SizedBox(height: OrtizSpace.xs),
                      Text(
                        [...tagLabels, ...people.map((p) => '@$p')].join('  '),
                        style: const TextStyle(fontSize: OrtizFontSize.caption, color: DiarioColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (log.note != null && log.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: OrtizSpace.xs),
                      Text(
                        log.note!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: DiarioColors.textPrimary, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              if (isPending)
                const Padding(
                  padding: EdgeInsets.only(top: OrtizSpace.xs),
                  child: Tooltip(
                    message: 'Pendiente de sincronizar',
                    child: Icon(Icons.cloud_off_rounded, size: OrtizIconSize.sm, color: DiarioColors.textMuted),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: OrtizIconSize.md, color: DiarioColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
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
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
      decoration: BoxDecoration(color: DiarioColors.surfaceHover, borderRadius: BorderRadius.circular(OrtizRadius.chip)),
      child: Text(text, style: const TextStyle(fontSize: OrtizFontSize.micro, fontWeight: FontWeight.w800, color: DiarioColors.textSecondary)),
    );
  }

  static String _formatWhen(DateTime d, bool withDate) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (!withDate) return time;
    return '${d.day} ${months[d.month - 1]} · $time';
  }
}
