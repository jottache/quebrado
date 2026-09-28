import 'package:flutter/material.dart';
import '../models/mood_catalog.dart';
import '../theme/diario_colors.dart';
import '../viewmodels/animo_state.dart';

/// Calendario mensual coloreado por el valor de ánimo de cada día.
class MoodMonthCalendar extends StatefulWidget {
  final String? contactId;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDaySelected;

  const MoodMonthCalendar({super.key, this.contactId, this.selectedDate, this.onDaySelected});

  @override
  State<MoodMonthCalendar> createState() => _MoodMonthCalendarState();
}

class _MoodMonthCalendarState extends State<MoodMonthCalendar> {
  late DateTime _month;

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    final base = widget.selectedDate ?? DateTime.now();
    _month = DateTime(base.year, base.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final animo = AnimoState.maybeOf(context);
    if (animo == null) return const SizedBox.shrink();

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday - 1;
    final today = DateTime.now();
    final values = <int, double?>{
      for (var d = 1; d <= daysInMonth; d++)
        d: animo.dayValence(DateTime(_month.year, _month.month, d), contactId: widget.contactId),
    };
    final loggedDays = values.values.whereType<double>().toList();
    final monthAvg = loggedDays.isEmpty ? null : loggedDays.reduce((a, b) => a + b) / loggedDays.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${_monthNames[_month.month - 1]} ${_month.year}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                  ),
                  Text(
                    monthAvg == null
                        ? 'Sin registros'
                        : '${loggedDays.length} días · promedio ${MoodCatalog.metaForAverage(monthAvg).emoji} ${monthAvg.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DiarioColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _isCurrentMonth ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: _weekDays
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DiarioColors.textMuted)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++) _buildDay(d, values[d], today),
          ],
        ),
      ],
    );
  }

  Widget _buildDay(int day, double? value, DateTime today) {
    final date = DateTime(_month.year, _month.month, day);
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final sel = widget.selectedDate;
    final isSelected = sel != null && sel.year == date.year && sel.month == date.month && sel.day == date.day;
    final color = value != null ? MoodCatalog.colorForAverage(value) : null;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: isFuture || widget.onDaySelected == null ? null : () => widget.onDaySelected!(date),
      child: Container(
        decoration: BoxDecoration(
          color: color?.withOpacity(0.85) ?? (isFuture ? Colors.transparent : DiarioColors.surfaceHover),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? DiarioColors.textPrimary : (isToday ? DiarioColors.primary : Colors.transparent),
            width: isSelected ? 2 : 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: value != null
            ? Text(MoodCatalog.metaForAverage(value).emoji, style: const TextStyle(fontSize: 15))
            : Text(
                '$day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isFuture ? DiarioColors.cardBorder : DiarioColors.textMuted,
                ),
              ),
      ),
    );
  }
}
