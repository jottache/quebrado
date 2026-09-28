import 'package:flutter/material.dart';
import '../models/mood_catalog.dart';
import '../models/mood_log.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';
import 'mood_checkin_sheet.dart';

/// Barra de 5 emojis. Un toque guarda el registro al instante y ofrece
/// "Agregar detalle" para completar emociones, contexto y nota.
class MoodQuickBar extends StatelessWidget {
  final String? contactId;
  final double emojiSize;
  final MoodSource source;

  const MoodQuickBar({
    super.key,
    this.contactId,
    this.emojiSize = 28,
    this.source = MoodSource.manual,
  });

  Future<void> _quickLog(BuildContext context, int valence) async {
    final animo = AnimoState.maybeOf(context, listen: false);
    if (animo == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);

    final log = await animo.addLog(valence: valence, contactId: contactId, source: source);

    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text('${log.valenceMeta.emoji} Guardado · ${log.valenceMeta.label}'),
        action: SnackBarAction(
          label: 'Agregar detalle',
          textColor: const Color(0xFF8CE99A),
          onPressed: () {
            if (context.mounted) showMoodCheckinSheet(context, existing: log);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: MoodCatalog.valences.map((meta) {
        return Expanded(
          child: Tooltip(
            message: meta.label,
            child: InkWell(
              key: ValueKey('mood_quick_${contactId ?? 'self'}_${meta.value}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => _quickLog(context, meta.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(child: Text(meta.emoji, style: TextStyle(fontSize: emojiSize))),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Tarjeta "¿Cómo te sientes?" para Diario / Launcher. Si ya hay registros hoy,
/// muestra el resumen y permite registrar otro. No se dibuja si no hay [AnimoState].
class MoodTodayCard extends StatelessWidget {
  final VoidCallback? onOpenDashboard;
  final EdgeInsetsGeometry margin;

  const MoodTodayCard({super.key, this.onOpenDashboard, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final animo = AnimoState.maybeOf(context);
    if (animo == null) return const SizedBox.shrink();

    final today = animo.todaySelfLogs();
    final dayValue = animo.todaySelfValence;
    final streak = animo.selfLoggingStreak;

    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
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
              if (dayValue != null)
                Text(MoodCatalog.metaForAverage(dayValue).emoji, style: const TextStyle(fontSize: 20))
              else
                const Icon(Icons.mood_rounded, color: DiarioColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today.isEmpty ? '¿Cómo te sientes hoy?' : 'Hoy: ${MoodCatalog.metaForAverage(dayValue!).label}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                    ),
                    Text(
                      today.isEmpty
                          ? 'Un toque basta. Puedes agregar detalle después.'
                          : '${today.length} ${today.length == 1 ? "registro" : "registros"}${streak > 1 ? " · 🔥 $streak días seguidos" : ""} · registra otro',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DiarioColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (animo.pendingCount > 0)
                const Tooltip(
                  message: 'Pendiente de sincronizar',
                  child: Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.cloud_off_rounded, size: 16, color: DiarioColors.textMuted),
                  ),
                ),
              if (onOpenDashboard != null)
                TextButton(
                  onPressed: onOpenDashboard,
                  style: TextButton.styleFrom(
                    foregroundColor: DiarioColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Mi ánimo ›', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const MoodQuickBar(),
        ],
      ),
    );
  }
}
