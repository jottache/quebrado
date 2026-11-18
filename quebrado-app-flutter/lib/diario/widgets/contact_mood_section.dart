import 'package:flutter/material.dart';
import '../models/diario_contact.dart';
import '../models/mood_catalog.dart';
import '../models/mood_log.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';
import '../screens/animo_dashboard_screen.dart';
import 'mood_log_tile.dart';
import 'mood_quick_bar.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
/// Sección "Ánimo percibido" del detalle de contacto.
class ContactMoodSection extends StatelessWidget {
  final DiarioContact contact;

  const ContactMoodSection({super.key, required this.contact});

  String get _displayName =>
      (contact.nickname != null && contact.nickname!.trim().isNotEmpty) ? contact.nickname!.trim() : contact.name.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final animo = AnimoState.maybeOf(context);
    if (animo == null) return const SizedBox.shrink();

    final logs = animo.logsFor(contactId: contact.id);
    final latest = logs.isNotEmpty ? logs.first : null;
    final avg30 = animo.averageValence(contactId: contact.id, days: 30);
    final series = animo.dailySeries(contactId: contact.id, days: 30);

    // Sin tarjeta (spec 05): el grupo va sobre el fondo, separado por espacio.
    return Padding(
      padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, 0, OrtizSpace.xl, OrtizSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: DiarioColors.primaryLight, borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                child: const Icon(Icons.mood_rounded, size: OrtizIconSize.sm, color: DiarioColors.primary),
              ),
              const SizedBox(width: OrtizSpace.sm),
              const Expanded(
                child: Text(
                  'Ánimo percibido',
                  style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                ),
              ),
              if (logs.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AnimoDashboardScreen(contactId: contact.id)),
                  ),
                  style: TextButton.styleFrom(foregroundColor: DiarioColors.primary),
                  child: Text('Historial (${logs.length}) ›', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: OrtizFontSize.bodySm)),
                ),
            ],
          ),
          const SizedBox(height: OrtizSpace.xs),
          Text(
            latest == null
                ? '¿Cómo viste a $_displayName? Registra lo que notaste o lo que te contó.'
                : _summary(latest, avg30),
            style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: DiarioColors.textSecondary, fontWeight: FontWeight.w600, height: 1.35),
          ),
          if (series.length >= 2) ...[
            const SizedBox(height: OrtizSpace.sm),
            _Sparkline(series: series),
          ],
          const SizedBox(height: OrtizSpace.sm),
          MoodQuickBar(contactId: contact.id, emojiSize: 26),
          if (latest != null) ...[
            const SizedBox(height: OrtizSpace.sm),
            MoodLogTile(log: latest, showDate: true),
          ],
        ],
      ),
    );
  }

  String _summary(MoodLog latest, double? avg30) {
    final days = DateTime.now().difference(latest.loggedAt).inDays;
    final when = days == 0 ? 'hoy' : (days == 1 ? 'ayer' : 'hace $days días');
    final how = latest.perspective == MoodPerspective.told ? 'te contó que estaba' : 'lo notaste';
    final base = 'Último: ${latest.valenceMeta.emoji} ${latest.valenceMeta.label.toLowerCase()} $when ($how).';
    if (avg30 == null) return base;
    return '$base Promedio 30 días: ${MoodCatalog.metaForAverage(avg30).emoji} ${avg30.toStringAsFixed(1)}.';
  }
}

/// Mini gráfico de puntos de colores de los últimos 30 días.
class _Sparkline extends StatelessWidget {
  final Map<String, double> series;
  const _Sparkline({required this.series});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(30, (i) {
          final d = DateTime(today.year, today.month, today.day - (29 - i));
          final value = series[MoodLog.dateKey(d)];
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs),
              height: value == null ? 6 : 10 + (value + 2) * 4,
              decoration: BoxDecoration(
                color: value == null ? DiarioColors.surfaceHover : MoodCatalog.colorForAverage(value),
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
            ),
          );
        }),
      ),
    );
  }
}
