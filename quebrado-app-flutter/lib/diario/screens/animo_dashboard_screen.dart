import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood_catalog.dart';
import '../viewmodels/animo_state.dart';
import '../viewmodels/diario_state.dart';
import '../widgets/mood_checkin_sheet.dart';
import '../widgets/mood_log_tile.dart';
import '../widgets/mood_month_calendar.dart';
import '../widgets/mood_quick_bar.dart';
import '../widgets/mood_trend_chart.dart';
import '../../widgets/responsive_breakpoints.dart';
import '../../widgets/ortiz/ortiz.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';

/// Color de identidad del Diario (spec 05: vía `SuiteApp`).
Color get _diario => SuiteApp.diario.color;

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
    final t = OrtizTokens.of(context);
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
      _section(
        title: 'Calendario',
        child: MoodMonthCalendar(
          contactId: widget.contactId,
          selectedDate: _selectedDay,
          onDaySelected: (d) => setState(() => _selectedDay = _isSameDay(d, _selectedDay) ? null : d),
        ),
      ),
      if (_selectedDay != null) _buildSelectedDay(animo, _selectedDay!),
    ];

    final rightColumn = <Widget>[
      _section(
        title: 'Tendencia',
        child: MoodTrendChart(contactId: widget.contactId),
      ),
      _section(
        title: 'Emociones frecuentes · 30 días',
        child: _buildTopEmotions(animo),
      ),
      _buildRecent(animo),
    ];

    List<Widget> staggered(List<Widget> items) => [
          for (var i = 0; i < items.length; i++) ortizStaggered(context, i, items[i]),
        ];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: OrtizFontSize.title, color: t.fg)),
        actions: [
          IconButton(
            tooltip: 'Registro completo',
            icon: const Icon(Icons.add_reaction_outlined),
            onPressed: () => showMoodCheckinSheet(context, contactId: widget.contactId),
          ),
          const SizedBox(width: OrtizSpace.xs),
        ],
      ),
      body: RefreshIndicator(
        color: _diario,
        onRefresh: () => animo.loadAll(),
        child: animo.isLoading && !animo.hasLoaded
            ? Center(child: CircularProgressIndicator(color: _diario))
            : isDesktop
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1300),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: ListView(padding: const EdgeInsets.fromLTRB(OrtizSpace.xxl, OrtizSpace.lg, OrtizSpace.md, OrtizSpace.xxxl), children: staggered(leftColumn)),
                          ),
                          Expanded(
                            flex: 6,
                            child: ListView(padding: const EdgeInsets.fromLTRB(OrtizSpace.md, OrtizSpace.lg, OrtizSpace.xxl, OrtizSpace.xxxl), children: staggered(rightColumn)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.sm, OrtizSpace.lg, OrtizSpace.xxxl),
                    children: staggered([...leftColumn, ...rightColumn]),
                  ),
      ),
    );
  }

  // ===========================================================================
  // SECCIONES
  // ===========================================================================

  /// Grupo sin tarjeta (spec 05, C4): encabezado `muted` y contenido sobre `bg`.
  Widget _section({required String title, required Widget child, Widget? trailing}) {
    return OrtizSection(
      padding: const EdgeInsets.only(top: OrtizSpace.md),
      title: title,
      trailing: trailing,
      children: [child],
    );
  }

  Widget _buildSyncBanner(AnimoState animo) {
    final text = !animo.isBackendReady
        ? 'Sin conexión con Supabase. Tus registros se guardan en este dispositivo y se sincronizarán después.'
        : '${animo.pendingCount} ${animo.pendingCount == 1 ? "cambio pendiente" : "cambios pendientes"} de sincronizar.';
    return Container(
      margin: const EdgeInsets.only(bottom: OrtizSpace.sm),
      padding: const EdgeInsets.fromLTRB(OrtizSpace.md, OrtizSpace.sm, OrtizSpace.xs, OrtizSpace.sm),
      decoration: BoxDecoration(
        color: OrtizPalette.warnTint,
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        border: Border.all(color: OrtizPalette.warnBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: OrtizIconSize.sm, color: OrtizPalette.warn),
          const SizedBox(width: OrtizSpace.sm),
          Expanded(child: Text(text, style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: OrtizPalette.fg))),
          if (animo.isBackendReady)
            TextButton(onPressed: () => animo.syncPending(), child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildContactQuickCard() {
    return OrtizSection(
      children: [
        const Text(
          '¿Cómo lo viste hoy?',
          style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w900, color: OrtizPalette.fg),
        ),
        const Text(
          'Ánimo percibido · tu observación, no su auto-reporte',
          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w600, color: OrtizPalette.muted),
        ),
        const SizedBox(height: OrtizSpace.xs),
        MoodQuickBar(contactId: widget.contactId),
      ],
    );
  }

  Widget _buildProgressCard(AnimoState animo) {
    final done = animo.selfLoggedDaysCount;
    return OrtizSection(
      padding: const EdgeInsets.only(top: OrtizSpace.md),
      surface: true,
      children: [
        Row(
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
                    color: _diario,
                    backgroundColor: OrtizPalette.line,
                  ),
                  Text('$done/$_patternsGoalDays', style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w900, color: OrtizPalette.fg)),
                ],
              ),
            ),
            const SizedBox(width: OrtizSpace.md),
            Expanded(
              child: Text(
                'Registra cómo te sientes durante 7 días distintos para empezar a ver tus patrones.',
                style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w700, color: _diario, height: 1.35),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedDay(AnimoState animo, DateTime day) {
    final logs = animo.logsOnDate(day, contactId: widget.contactId);
    final value = animo.dayValence(day, contactId: widget.contactId);
    const weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final title = '${weekDays[day.weekday - 1]} ${day.day}/${day.month}';

    return _section(
      title: value == null ? title : '$title · ${MoodCatalog.metaForAverage(value).emoji} ${value.toStringAsFixed(1)}',
      trailing: TextButton.icon(
        onPressed: () => showMoodCheckinSheet(
          context,
          contactId: widget.contactId,
          initialDate: DateTime(day.year, day.month, day.day, 20),
        ),
        icon: const Icon(Icons.add_rounded, size: OrtizIconSize.sm),
        label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w800)),
        style: TextButton.styleFrom(foregroundColor: _diario),
      ),
      child: logs.isEmpty
          ? const Text('Sin registros este día.', style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted))
          : Column(children: logs.map((l) => MoodLogTile(log: l)).toList()),
    );
  }

  Widget _buildTopEmotions(AnimoState animo) {
    final top = animo.topEmotions(days: 30, contactId: widget.contactId);
    if (top.isEmpty) {
      return const Text(
        'Cuando agregues emociones a tus registros, aquí verás cuáles se repiten.',
        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted, fontWeight: FontWeight.w600),
      );
    }
    final maxCount = top.first.count;
    return Column(
      children: top.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(f.emotion.label, style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  child: LinearProgressIndicator(
                    value: f.count / maxCount,
                    minHeight: 10,
                    color: f.emotion.color,
                    backgroundColor: f.emotion.color.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(width: OrtizSpace.sm),
              SizedBox(
                width: 24,
                child: Text('${f.count}', textAlign: TextAlign.right, style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecent(AnimoState animo) {
    final logs = animo.logsFor(contactId: widget.contactId).take(20).toList();
    return _section(
      title: 'Registros recientes',
      child: logs.isEmpty
          ? Text(
              _isSelf ? 'Aún no tienes registros. Toca un emoji arriba para empezar.' : 'Aún no hay registros de este contacto.',
              style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted, fontWeight: FontWeight.w600),
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
