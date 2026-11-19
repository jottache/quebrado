import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../viewmodels/habitos_state.dart';
import '../theme/habitos_terminal_theme.dart';
import 'habit_terminal_editor_dialog.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../diario/models/diario_contact.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class HabitDetailCliDialog extends StatefulWidget {
  final HabitModel habit;

  const HabitDetailCliDialog({super.key, required this.habit});

  @override
  State<HabitDetailCliDialog> createState() => _HabitDetailCliDialogState();
}

class _HabitDetailCliDialogState extends State<HabitDetailCliDialog> {
  /// Rangos disponibles para ver la actividad (días hacia atrás desde hoy).
  static const Map<int, String> _ranges = {30: '30 días', 90: '3 meses', 180: '6 meses', 365: '12 meses'};
  int _rangeDays = 30;

  HabitModel get habit => widget.habit;
  String get _rangeLabel => _ranges[_rangeDays]!;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HabitosState>(context);
    final diarioState = Provider.of<DiarioState>(context, listen: false);
    final linkedContact = habit.contactId != null
        ? diarioState.contacts.where((c) => c.id == habit.contactId).firstOrNull
        : null;

    final streak = state.calculateCurrentStreak(habit.id);
    final cleanDays = habit.isNegative ? state.calculateCleanDays(habit.id) : null;
    final stats = state.getRangeStats(habit.id, days: _rangeDays);
    final unit = habit.unit ?? 'veces';

    return Dialog(
      backgroundColor: OrtizPalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.sheet)),
      insetPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.xxl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera Minimalista
            Padding(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.lg, OrtizSpace.md),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: habit.isNegative ? OrtizPalette.warnTint : HabitosColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    child: Icon(
                      habit.isNegative ? Icons.shield_outlined : Icons.track_changes_rounded,
                      color: habit.isNegative ? OrtizPalette.warn : HabitosColors.primary,
                      size: OrtizIconSize.md,
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: const TextStyle(
                            fontSize: OrtizFontSize.titleSm,
                            fontWeight: FontWeight.w900,
                            color: OrtizPalette.fg,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (habit.description != null && habit.description!.isNotEmpty)
                          Text(
                            habit.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: OrtizPalette.line),

            // Contenido de estadísticas
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(OrtizSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Resumen de métricas: filas separadas por líneas, sin tarjeta.
                    Column(
                        children: [
                          _metricRow('Tipo de hábito', habit.type.label),
                          const Divider(height: 16, color: OrtizPalette.line),
                          if (linkedContact != null) ...[
                            _metricRow('Contacto vinculado', linkedContact.name, isHighlight: true),
                            const Divider(height: 16, color: OrtizPalette.line),
                          ],
                          if (habit.isNegative) ...[
                            _metricRow(
                              'Recaídas hoy',
                              '${state.getRelapseCount(habit.id, state.todayKey)} $unit',
                              isHighlight: true,
                              color: state.getRelapseCount(habit.id, state.todayKey) > 0 ? OrtizPalette.bad : null,
                            ),
                            const Divider(height: 16, color: OrtizPalette.line),
                            _metricRow('Días libre de recaída', '$cleanDays ${cleanDays == 1 ? "día" : "días"} invicto', isHighlight: true),
                            const Divider(height: 16, color: OrtizPalette.line),
                            _metricRow(
                              'Días limpios · $_rangeLabel',
                              '${stats.successDays} de ${stats.trackedDays} (${(stats.successRate * 100).round()}%)',
                            ),
                            const Divider(height: 16, color: OrtizPalette.line),
                            _metricRow(
                              'Recaídas · $_rangeLabel',
                              '${stats.relapseDays} ${stats.relapseDays == 1 ? "día" : "días"} · ${stats.relapseCount} $unit',
                              color: stats.relapseDays > 0 ? OrtizPalette.bad : null,
                            ),
                          ] else ...[
                            if (habit.type == HabitType.counter) ...[
                              _metricRow('Total hoy', '${state.getValue(habit.id, state.todayKey).toInt()} $unit', isHighlight: true),
                              const Divider(height: 16, color: OrtizPalette.line),
                              _metricRow('Total · $_rangeLabel', '${stats.totalValue.toInt()} $unit'),
                              const Divider(height: 16, color: OrtizPalette.line),
                            ],
                            _metricRow('Racha actual', '$streak días seguidos', isHighlight: true, color: HabitosColors.amber),
                            const Divider(height: 16, color: OrtizPalette.line),
                            _metricRow(
                              'Consistencia · $_rangeLabel',
                              '${(stats.successRate * 100).round()}% (${stats.successDays} de ${stats.trackedDays} días)',
                            ),
                          ],
                          if (habit.type == HabitType.quantitative) ...[
                            const Divider(height: 16, color: OrtizPalette.line),
                            _metricRow('Meta diaria', '${habit.targetValue.toInt()} ${habit.unit ?? ""}'),
                          ],
                          if (habit.type == HabitType.timer) ...[
                            const Divider(height: 16, color: OrtizPalette.line),
                            _metricRow('Tiempo objetivo', '${(habit.targetValue / 60).round()} minutos'),
                          ],
                        ],
                    ),

                    const SizedBox(height: OrtizSpace.xl),

                    // Actividad por rango
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: OrtizIconSize.sm, color: OrtizPalette.muted),
                        const SizedBox(width: OrtizSpace.xs),
                        Expanded(
                          child: Text(
                            'Actividad · $_rangeLabel (toca un día para ver o corregir)',
                            style: const TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.w800,
                              color: OrtizPalette.fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OrtizSpace.sm),
                    _buildRangeSelector(),
                    const SizedBox(height: OrtizSpace.md),
                    _rangeDays <= 30 ? _build30DayGrid(context, state) : _buildHeatmap(context, state),
                    const SizedBox(height: OrtizSpace.sm),
                    _buildLegend(),
                  ],
                ),
              ),
            ),

            // Acciones inferiores (Eliminar & Editar)
            const Divider(height: 1, color: OrtizPalette.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: OrtizIconSize.sm, color: OrtizPalette.bad),
                    label: const Text('Eliminar', style: TextStyle(color: OrtizPalette.bad, fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: OrtizPalette.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
                          title: const Text(
                            '¿Eliminar hábito?',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: OrtizFontSize.titleSm),
                          ),
                          content: Text(
                            'Se eliminarán el hábito "${habit.title}" y todos sus registros históricos.',
                            style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar', style: TextStyle(color: OrtizPalette.muted)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OrtizPalette.bad,
                                foregroundColor: OrtizPalette.onAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        state.deleteHabit(habit.id);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: OrtizIconSize.sm),
                    label: const Text('Editar Hábito', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HabitosColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => HabitTerminalEditorDialog(habit: habit),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool isHighlight = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: OrtizSpace.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: OrtizFontSize.bodySm,
              fontWeight: FontWeight.w800,
              color: color ?? (isHighlight ? HabitosColors.primary : OrtizPalette.fg),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _ranges.entries.map((e) {
        final selected = e.key == _rangeDays;
        return ChoiceChip(
          key: ValueKey('habit_range_${e.key}'),
          label: Text(e.value),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _rangeDays = e.key),
          selectedColor: HabitosColors.primary,
          backgroundColor: OrtizPalette.surface,
          labelStyle: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? OrtizPalette.onAccent : OrtizPalette.fg,
          ),
          side: BorderSide(color: selected ? HabitosColors.primary : OrtizPalette.line),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  /// Colores de cada día según su estado.
  ({Color bg, Color border, Color text}) _dayColors(HabitDayStatus s) {
    switch (s.kind) {
      case HabitDayKind.relapse:
        return (bg: OrtizPalette.bad, border: OrtizPalette.bad, text: OrtizPalette.onAccent);
      case HabitDayKind.clean:
        return (bg: HabitosColors.primaryLight, border: HabitosColors.primaryBorder, text: HabitosColors.primary);
      case HabitDayKind.completed:
        return (bg: HabitosColors.primary, border: HabitosColors.primary, text: OrtizPalette.onAccent);
      case HabitDayKind.partial:
        return (bg: HabitosColors.primary.withValues(alpha: 0.45), border: HabitosColors.primary, text: OrtizPalette.fg);
      case HabitDayKind.beforeCreation:
        return (bg: Colors.transparent, border: OrtizPalette.line.withValues(alpha: 0.6), text: OrtizPalette.muted);
      case HabitDayKind.none:
        return (bg: OrtizPalette.surfaceHigh, border: OrtizPalette.line, text: OrtizPalette.muted);
    }
  }

  Widget _buildLegend() {
    Widget item(Color bg, Color border, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(OrtizRadius.chip), border: Border.all(color: border)),
            ),
            const SizedBox(width: OrtizSpace.xs),
            Text(label, style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted, fontWeight: FontWeight.w600)),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: habit.isNegative
          ? [
              item(HabitosColors.primaryLight, HabitosColors.primaryBorder, 'Día limpio'),
              item(OrtizPalette.bad, OrtizPalette.bad, 'Recaída (número = veces)'),
              item(Colors.transparent, OrtizPalette.line, 'Antes de crear el hábito'),
            ]
          : [
              item(HabitosColors.primary, HabitosColors.primary, 'Cumplido'),
              item(HabitosColors.primary.withValues(alpha: 0.45), HabitosColors.primary, 'Parcial'),
              item(OrtizPalette.surfaceHigh, OrtizPalette.line, 'Sin registro'),
            ],
    );
  }

  /// Vista de calendario compacta (columnas = semanas, filas = lunes..domingo) para 3, 6 y 12 meses.
  Widget _buildHeatmap(BuildContext context, HabitosState state) {
    final statuses = state.getDayStatuses(habit.id, days: _rangeDays);
    if (statuses.isEmpty) return const SizedBox.shrink();

    // Rellenar al inicio para que la primera columna empiece en lunes.
    final leading = statuses.first.date.weekday - 1;
    final cells = <HabitDayStatus?>[...List.filled(leading, null), ...statuses];
    final weeks = (cells.length / 7).ceil();
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 2.0;
        const labelWidth = 16.0;
        final cell = ((constraints.maxWidth - labelWidth - gap * (weeks - 1)) / weeks).clamp(5.0, 22.0);

        Widget column(int w) {
          return Column(
            children: List.generate(7, (d) {
              final idx = w * 7 + d;
              final status = idx < cells.length ? cells[idx] : null;
              final colors = status == null ? null : _dayColors(status);
              // Sin separación bajo el domingo (última fila).
              final bottomGap = d < 6 ? gap : 0.0;
              final box = Container(
                width: cell,
                height: cell,
                margin: EdgeInsets.only(bottom: bottomGap),
                decoration: BoxDecoration(
                  color: colors?.bg ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(cell > 10 ? 3 : 1.5),
                  border: colors == null ? null : Border.all(color: colors.border, width: 0.6),
                ),
                alignment: Alignment.center,
                child: (status != null && status.relapseCount > 1 && cell >= 14)
                    ? Text('${status.relapseCount}', style: const TextStyle(fontSize: OrtizFontSize.micro, color: OrtizPalette.onAccent, fontWeight: FontWeight.w900))
                    : null,
              );
              if (status == null) return box;
              return Tooltip(
                message: _dayTooltip(status),
                child: InkWell(onTap: () => _showDayMetricPopover(context, state, status), child: box),
              );
            }),
          );
        }

        // Etiquetas de mes sobre la semana en que empieza cada mes.
        final monthLabels = <Widget>[];
        int? lastMonth;
        for (var w = 0; w < weeks; w++) {
          final firstReal = List.generate(7, (d) => w * 7 + d)
              .where((i) => i < cells.length && cells[i] != null)
              .map((i) => cells[i]!)
              .firstOrNull;
          final m = firstReal?.date.month;
          final showLabel = m != null && m != lastMonth;
          if (m != null) lastMonth = m;
          monthLabels.add(SizedBox(
            width: cell + (w < weeks - 1 ? gap : 0),
            child: showLabel
                ? OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: 40,
                    child: Text(months[m - 1], style: const TextStyle(fontSize: OrtizFontSize.micro, color: OrtizPalette.muted, fontWeight: FontWeight.w700)),
                  )
                : null,
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: labelWidth),
              child: SizedBox(height: 12, child: Row(children: monthLabels)),
            ),
            const SizedBox(height: OrtizSpace.xxs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    children: List.generate(7, (d) {
                      const labels = ['L', '', 'M', '', 'V', '', 'D'];
                      return SizedBox(
                        height: cell + (d < 6 ? gap : 0),
                        child: Text(labels[d], style: const TextStyle(fontSize: OrtizFontSize.micro, color: OrtizPalette.muted)),
                      );
                    }),
                  ),
                ),
                for (var w = 0; w < weeks; w++) ...[
                  column(w),
                  if (w < weeks - 1) const SizedBox(width: gap),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  String _dayTooltip(HabitDayStatus s) {
    final date = '${s.date.day}/${s.date.month}/${s.date.year}';
    switch (s.kind) {
      case HabitDayKind.relapse:
        return '$date · ${s.relapseCount} ${s.relapseCount == 1 ? "recaída" : "recaídas"}';
      case HabitDayKind.clean:
        return '$date · Día limpio';
      case HabitDayKind.completed:
        return '$date · Cumplido';
      case HabitDayKind.partial:
        return '$date · ${s.value.toInt()} ${habit.unit ?? ""}';
      case HabitDayKind.beforeCreation:
        return '$date · El hábito aún no existía';
      case HabitDayKind.none:
        return '$date · Sin registro';
    }
  }

  Widget _build30DayGrid(BuildContext context, HabitosState state) {
    final statuses = state.getDayStatuses(habit.id, days: 30);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: statuses.map((status) {
        final colors = _dayColors(status);
        return Tooltip(
          message: _dayTooltip(status),
          child: InkWell(
            key: ValueKey('habit_day_${status.dateKey}'),
            onTap: () => _showDayMetricPopover(context, state, status),
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '${status.date.day}',
                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: colors.text),
                    ),
                  ),
                  if (status.kind == HabitDayKind.relapse)
                    Positioned(
                      right: 2,
                      top: 1,
                      child: Text(
                        '×${status.relapseCount}',
                        style: const TextStyle(fontSize: OrtizFontSize.micro, fontWeight: FontWeight.w900, color: OrtizPalette.onAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showDayMetricPopover(BuildContext context, HabitosState state, HabitDayStatus status) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final date = status.date;
    final dateStr = status.dateKey;
    final formattedDate = '${date.day} de ${months[date.month - 1]}, ${date.year}';
    final unit = habit.unit ?? 'veces';
    final canEdit = status.kind != HabitDayKind.beforeCreation;

    showDialog(
      context: context,
      builder: (ctx) => Consumer<HabitosState>(
        builder: (ctx, live, _) {
          final relapses = live.getRelapseCount(habit.id, dateStr);
          final value = live.getValue(habit.id, dateStr);
          final isCompleted = live.isCompleted(habit.id, dateStr);

          final String headline;
          final String subtitle;
          final Color accent;
          if (habit.isNegative) {
            headline = relapses == 0 ? 'Día limpio' : '$relapses $unit';
            subtitle = !canEdit
                ? 'El hábito aún no existía'
                : (relapses == 0 ? '✓ Sin recaídas este día' : 'Recaídas registradas este día');
            accent = relapses == 0 ? HabitosColors.primary : OrtizPalette.bad;
          } else {
            headline = '${value.toInt()} $unit';
            subtitle = isCompleted || value > 0 ? '✓ Día con actividad registrada' : 'Sin actividad este día';
            accent = isCompleted || value > 0 ? HabitosColors.primary : OrtizPalette.muted;
          }

          return AlertDialog(
            backgroundColor: OrtizPalette.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
            titlePadding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.sm),
            contentPadding: const EdgeInsets.fromLTRB(OrtizSpace.xl, 0, OrtizSpace.xl, OrtizSpace.xl),
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: habit.isNegative && relapses > 0 ? OrtizPalette.badTint : HabitosColors.primaryLight,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                  child: Icon(Icons.event_note_rounded, color: accent, size: OrtizIconSize.sm),
                ),
                const SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w900, color: OrtizPalette.fg),
                      ),
                      Text(
                        habit.title,
                        style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 16, color: OrtizPalette.line),
                Container(
                  padding: const EdgeInsets.all(OrtizSpace.md),
                  // Bloque destacado del diálogo: `surfaceHigh`, sin borde.
                  decoration: BoxDecoration(
                    color: OrtizPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                  ),
                  child: Column(
                    children: [
                      Text(
                        habit.isNegative ? 'RECAÍDAS' : 'VECES MARCADO',
                        style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w800, color: OrtizPalette.muted),
                      ),
                      const SizedBox(height: OrtizSpace.xs),
                      Text(
                        headline,
                        style: TextStyle(fontSize: OrtizFontSize.display, fontWeight: FontWeight.w900, color: accent, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: OrtizSpace.xxs),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w700, color: accent),
                      ),
                    ],
                  ),
                ),
                if (canEdit && (habit.isNegative || habit.type == HabitType.counter)) ...[
                  const SizedBox(height: OrtizSpace.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if ((habit.isNegative ? relapses : value) > 0) ...[
                        OutlinedButton.icon(
                          key: const ValueKey('habit_day_minus'),
                          icon: const Icon(Icons.remove, size: OrtizIconSize.sm),
                          label: const Text('-1'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: OrtizPalette.fg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                          ),
                          onPressed: () => live.updateHabitValue(habit.id, -1, dateStr),
                        ),
                        const SizedBox(width: OrtizSpace.md),
                      ],
                      ElevatedButton.icon(
                        key: const ValueKey('habit_day_plus'),
                        icon: const Icon(Icons.add, size: OrtizIconSize.sm),
                        label: Text(habit.isNegative ? '+1 recaída' : '+1 Toque'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: habit.isNegative ? OrtizPalette.bad : HabitosColors.primary,
                          foregroundColor: OrtizPalette.onAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                        ),
                        onPressed: () => live.updateHabitValue(habit.id, 1, dateStr),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar', style: TextStyle(color: OrtizPalette.muted, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
