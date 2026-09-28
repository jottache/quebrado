import 'package:flutter/material.dart';
import '../models/diario_contact.dart';
import '../models/mood_catalog.dart';
import '../models/mood_log.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';
import '../screens/animo_dashboard_screen.dart';
import 'mood_log_tile.dart';
import 'mood_quick_bar.dart';

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

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DiarioColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), offset: const Offset(0, 3), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: DiarioColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.mood_rounded, size: 16, color: DiarioColors.primary),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ánimo percibido',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                ),
              ),
              if (logs.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AnimoDashboardScreen(contactId: contact.id)),
                  ),
                  style: TextButton.styleFrom(foregroundColor: DiarioColors.primary),
                  child: Text('Historial (${logs.length}) ›', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            latest == null
                ? '¿Cómo viste a $_displayName? Registra lo que notaste o lo que te contó.'
                : _summary(latest, avg30),
            style: const TextStyle(fontSize: 12, color: DiarioColors.textSecondary, fontWeight: FontWeight.w600, height: 1.35),
          ),
          if (series.length >= 2) ...[
            const SizedBox(height: 10),
            _Sparkline(series: series),
          ],
          const SizedBox(height: 8),
          MoodQuickBar(contactId: contact.id, emojiSize: 26),
          if (latest != null) ...[
            const SizedBox(height: 8),
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
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: value == null ? 6 : 10 + (value + 2) * 4,
              decoration: BoxDecoration(
                color: value == null ? DiarioColors.surfaceHover : MoodCatalog.colorForAverage(value),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}
