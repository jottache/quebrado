import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood_catalog.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';
import '../viewmodels/diario_state.dart';
import '../widgets/mood_checkin_sheet.dart';
import '../widgets/mood_log_tile.dart';
import '../widgets/mood_month_calendar.dart';
import '../widgets/mood_quick_bar.dart';
import '../widgets/mood_trend_chart.dart';
import '../../widgets/responsive_breakpoints.dart';

/// Pantalla "Mi ánimo" (o "Ánimo de {contacto}" si se pasa [contactId]).
class AnimoDashboardScreen extends StatefulWidget {
  final String? contactId;

  const AnimoDashboardScreen({super.key, this.contactId});

  @override
  State<AnimoDashboardScreen> createState() => _AnimoDashboardScreenState();
}

class _AnimoDashboardScreenState extends State<AnimoDashboardScreen> {
  DateTime? _selectedDay;

  static const int _patternsGoalDays = 7;

  bool get _isSelf => widget.contactId == null;

  @override
  Widget build(BuildContext context) {
    final animo = Provider.of<AnimoState>(context);
    String title = 'Mi ánimo';
    if (!_isSelf) {
      try {
        final contact = Provider.of<DiarioState>(context).getContactById(widget.contactId!);
        title = 'Ánimo de ${contact?.name.split(' ').first ?? 'contacto'}';
      } on ProviderNotFoundException {
        title = 'Ánimo percibido';
      }
    }
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    final leftColumn = <Widget>[
      if (!animo.isBackendReady || animo.pendingCount > 0) _buildSyncBanner(animo),
      _isSelf ? const MoodTodayCard() : _buildContactQuickCard(),
      if (_isSelf && animo.selfLoggedDaysCount < _patternsGoalDays) _buildProgressCard(animo),
      _card(
        title: 'Calendario',
        icon: Icons.calendar_month_rounded,
        child: MoodMonthCalendar(
          contactId: widget.contactId,
          selectedDate: _selectedDay,
          onDaySelected: (d) => setState(() => _selectedDay = _isSameDay(d, _selectedDay) ? null : d),
        ),
      ),
      if (_selectedDay != null) _buildSelectedDay(animo, _selectedDay!),
    ];

    final rightColumn = <Widget>[
      _card(
        title: 'Tendencia',
        icon: Icons.show_chart_rounded,
        child: MoodTrendChart(contactId: widget.contactId),
      ),
      _card(
        title: 'Emociones frecuentes · 30 días',
        icon: Icons.bubble_chart_rounded,
        child: _buildTopEmotions(animo),
      ),
      _buildRecent(animo),
    ];

    return Scaffold(
      backgroundColor: DiarioColors.background,
      appBar: AppBar(
        backgroundColor: DiarioColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: DiarioColors.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Registro completo',
            icon: const Icon(Icons.add_reaction_outlined),
            onPressed: () => showMoodCheckinSheet(context, contactId: widget.contactId),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: DiarioColors.primary,
        onRefresh: () => animo.loadAll(),
        child: animo.isLoading && !animo.hasLoaded
            ? const Center(child: CircularProgressIndicator(color: DiarioColors.primary))
            : isDesktop
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1300),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 12, 32), children: leftColumn),
                          ),
                          Expanded(
                            flex: 6,
                            child: ListView(padding: const EdgeInsets.fromLTRB(12, 16, 24, 32), children: rightColumn),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [...leftColumn, ...rightColumn],
                  ),
      ),
    );
  }

  // ===========================================================================
  // SECCIONES
  // ===========================================================================

  Widget _card({required String title, required IconData icon, required Widget child, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: DiarioColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSyncBanner(AnimoState animo) {
    final text = !animo.isBackendReady
        ? 'Sin conexión con Supabase. Tus registros se guardan en este dispositivo y se sincronizarán después.'
        : '${animo.pendingCount} ${animo.pendingCount == 1 ? "cambio pendiente" : "cambios pendientes"} de sincronizar.';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: DiarioColors.amberLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: DiarioColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          if (animo.isBackendReady)
            TextButton(onPressed: () => animo.syncPending(), child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildContactQuickCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Cómo lo viste hoy?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
          ),
          const Text(
            'Ánimo percibido · tu observación, no su auto-reporte',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DiarioColors.textSecondary),
          ),
          const SizedBox(height: 4),
          MoodQuickBar(contactId: widget.contactId),
        ],
      ),
    );
  }

  Widget _buildProgressCard(AnimoState animo) {
    final done = animo.selfLoggedDaysCount;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DiarioColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: done / _patternsGoalDays,
                  strokeWidth: 4,
                  color: DiarioColors.primary,
                  backgroundColor: Colors.white,
                ),
                Text('$done/$_patternsGoalDays', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Registra cómo te sientes durante 7 días distintos para empezar a ver tus patrones.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DiarioColors.primaryDark, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDay(AnimoState animo, DateTime day) {
    final logs = animo.logsOnDate(day, contactId: widget.contactId);
    final value = animo.dayValence(day, contactId: widget.contactId);
    const weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final title = '${weekDays[day.weekday - 1]} ${day.day}/${day.month}';

    return _card(
      title: value == null ? title : '$title · ${MoodCatalog.metaForAverage(value).emoji} ${value.toStringAsFixed(1)}',
      icon: Icons.today_rounded,
      trailing: TextButton.icon(
        onPressed: () => showMoodCheckinSheet(
          context,
          contactId: widget.contactId,
          initialDate: DateTime(day.year, day.month, day.day, 20),
        ),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w800)),
        style: TextButton.styleFrom(foregroundColor: DiarioColors.primary),
      ),
      child: logs.isEmpty
          ? const Text('Sin registros este día.', style: TextStyle(fontSize: 12, color: DiarioColors.textMuted))
          : Column(children: logs.map((l) => MoodLogTile(log: l)).toList()),
    );
  }

  Widget _buildTopEmotions(AnimoState animo) {
    final top = animo.topEmotions(days: 30, contactId: widget.contactId);
    if (top.isEmpty) {
      return const Text(
        'Cuando agregues emociones a tus registros, aquí verás cuáles se repiten.',
        style: TextStyle(fontSize: 12, color: DiarioColors.textMuted, fontWeight: FontWeight.w600),
      );
    }
    final maxCount = top.first.count;
    return Column(
      children: top.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(f.emotion.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: f.count / maxCount,
                    minHeight: 10,
                    color: f.emotion.color,
                    backgroundColor: f.emotion.color.withOpacity(0.12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text('${f.count}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecent(AnimoState animo) {
    final logs = animo.logsFor(contactId: widget.contactId).take(20).toList();
    return _card(
      title: 'Registros recientes',
      icon: Icons.history_rounded,
      child: logs.isEmpty
          ? Text(
              _isSelf ? 'Aún no tienes registros. Toca un emoji arriba para empezar.' : 'Aún no hay registros de este contacto.',
              style: const TextStyle(fontSize: 12, color: DiarioColors.textMuted, fontWeight: FontWeight.w600),
            )
          : Column(children: logs.map((l) => MoodLogTile(log: l, showDate: true)).toList()),
    );
  }

  static bool _isSameDay(DateTime a, DateTime? b) =>
      b != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Helper para abrir la pantalla desde cualquier módulo.
void openAnimoDashboard(BuildContext context, {String? contactId}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AnimoDashboardScreen(contactId: contactId)),
  );
}

