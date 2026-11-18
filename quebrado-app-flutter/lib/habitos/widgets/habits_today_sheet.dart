// Hoja «Marcar hábitos de hoy» (spec 02, PA-03; docs/design/ortiz-home.md §8).
// Solo hábitos buenos programados para hoy (`HabitosState.goodHabitsScheduledOn`);
// cada toque guarda al momento en la fecha de HOY sin cambiar la fecha que se
// ve en Hábitos. «Listo» cierra y, si cambió algo, muestra el aviso con el conteo.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../agente/viewmodels/agente_state.dart';
import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';
import '../../theme/ortiz_type.dart';
import '../../theme/suite_apps.dart';
import '../../widgets/ortiz/ortiz_empty_state.dart';
import '../../widgets/ortiz/ortiz_notice.dart';
import '../../widgets/responsive_sheet_helper.dart';
import '../models/habit_model.dart';
import '../viewmodels/habitos_state.dart';

/// Resultado de la hoja al pulsar «Listo».
class HabitsTodaySummary {
  const HabitsTodaySummary({required this.done, required this.total, required this.changed});

  final int done;
  final int total;
  final bool changed;

  String get noticeText => 'Hábitos de hoy: $done de $total hechos';
}

/// Abre la hoja (hoja inferior en el teléfono, panel derecho en escritorio).
///
/// [onOpenHabitos] se usa en «Abrir Hábitos» y en «Ver» del aviso;
/// [onCreateHabit], en el estado vacío. Ambos son opcionales.
Future<void> showHabitsTodaySheet(
  BuildContext context, {
  VoidCallback? onOpenHabitos,
  VoidCallback? onCreateHabit,
}) async {
  final today = DateTime.now();
  final summary = await showResponsiveSheet<HabitsTodaySummary>(
    context: context,
    builder: (_) => HabitsTodaySheet(
      today: today,
      onOpenHabitos: onOpenHabitos,
      onCreateHabit: onCreateHabit,
    ),
  );
  if (summary == null || !summary.changed || !context.mounted) return;
  showOrtizNotice(
    context,
    summary.noticeText,
    success: true,
    actionLabel: onOpenHabitos != null ? 'Ver' : null,
    onAction: onOpenHabitos,
  );
  // CA-09: Ortiz se pone contento al guardar con cambios. Sin `AgenteState`
  // en el árbol (p. ej. Hábitos suelto en un test) no pasa nada.
  try {
    context.read<AgenteState>().celebrate();
  } on ProviderNotFoundException {
    // Sin Ortiz en el árbol: solo el aviso.
  }
}

class HabitsTodaySheet extends StatefulWidget {
  const HabitsTodaySheet({
    super.key,
    required this.today,
    this.onOpenHabitos,
    this.onCreateHabit,
  });

  final DateTime today;
  final VoidCallback? onOpenHabitos;
  final VoidCallback? onCreateHabit;

  @override
  State<HabitsTodaySheet> createState() => _HabitsTodaySheetState();
}

class _HabitsTodaySheetState extends State<HabitsTodaySheet> {
  /// Ids fijados al cargar: la lista no cambia mientras la hoja está abierta.
  List<String>? _ids;
  bool _changed = false;

  void _close(HabitosState state, String todayKey, List<HabitModel> habits) {
    final done = habits.where((h) => state.isCompleted(h.id, todayKey)).length;
    Navigator.of(context).pop(
      HabitsTodaySummary(done: done, total: habits.length, changed: _changed),
    );
  }

  void _openHabitos() {
    Navigator.of(context).pop();
    widget.onOpenHabitos?.call();
  }

  void _createHabit() {
    Navigator.of(context).pop();
    widget.onCreateHabit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final state = context.watch<HabitosState>();
    final todayKey = state.dateKeyOf(widget.today);

    if (_ids == null && !state.isLoading) {
      _ids = state.goodHabitsScheduledOn(widget.today).map((h) => h.id).toList();
    }
    final byId = {for (final h in state.allHabits) h.id: h};
    final habits = (_ids ?? const <String>[])
        .map((id) => byId[id])
        .whereType<HabitModel>()
        .toList();
    final done = habits.where((h) => state.isCompleted(h.id, todayKey)).length;
    final hasAnyHabit = state.allHabits.isNotEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hábitos de hoy', style: OrtizType.title.copyWith(color: t.fg)),
                  if (habits.isNotEmpty) ...[
                    const SizedBox(height: OrtizSpace.xs),
                    Text(
                      '$done de ${habits.length} hechos',
                      style: OrtizType.bodySm.copyWith(color: t.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (state.isLoading) const LinearProgressIndicator(),
            const Divider(height: OrtizStroke.hairline),
            Flexible(
              child: state.isLoading
                  ? const SizedBox.shrink()
                  : !hasAnyHabit
                      ? SingleChildScrollView(
                          child: OrtizEmptyState(
                            icon: Icons.checklist_rounded,
                            title: 'Aún no tienes hábitos',
                            action: widget.onCreateHabit == null
                                ? null
                                : FilledButton(onPressed: _createHabit, child: const Text('Crear hábito')),
                          ),
                        )
                      : habits.isEmpty
                          ? const SingleChildScrollView(
                              child: OrtizEmptyState(
                                icon: Icons.checklist_rounded,
                                title: 'No tienes hábitos para marcar hoy',
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
                              itemCount: habits.length,
                              separatorBuilder: (_, _) => const Divider(height: OrtizStroke.hairline),
                              itemBuilder: (context, i) => _HabitTodayRow(
                                habit: habits[i],
                                state: state,
                                todayKey: todayKey,
                                onChanged: () => _changed = true,
                              ),
                            ),
            ),
            const Divider(height: OrtizStroke.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.sm, OrtizSpace.xl, OrtizSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Los malos hábitos se registran en Hábitos.',
                        style: OrtizType.bodySm.copyWith(color: t.muted),
                      ),
                      if (widget.onOpenHabitos != null)
                        TextButton(onPressed: _openHabitos, child: const Text('Abrir Hábitos')),
                    ],
                  ),
                  const SizedBox(height: OrtizSpace.sm),
                  FilledButton(
                    onPressed: () => _close(state, todayKey, habits),
                    child: const Text('Listo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitTodayRow extends StatelessWidget {
  const _HabitTodayRow({
    required this.habit,
    required this.state,
    required this.todayKey,
    required this.onChanged,
  });

  final HabitModel habit;
  final HabitosState state;
  final String todayKey;
  final VoidCallback onChanged;

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String? _subtitle() {
    final value = state.getValue(habit.id, todayKey);
    switch (habit.type) {
      case HabitType.quantitative:
        return '${_num(value)} / ${_num(habit.targetValue)} ${habit.unit ?? ''}'.trim();
      case HabitType.timer:
        // La meta de los temporizadores se guarda en segundos.
        return '${_num((habit.targetValue / Duration.secondsPerMinute).roundToDouble())} min';
      case HabitType.counter:
        return '${_num(value)} ${habit.unit ?? 'veces'} hoy';
      case HabitType.binary:
      case HabitType.negative:
        return null;
    }
  }

  Color _color() {
    final hex = habit.colorHex.replaceAll('#', '');
    final v = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return v == null ? SuiteApp.habitos.color : Color(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final isCounter = habit.type == HabitType.counter;
    final isDone = state.isCompleted(habit.id, todayKey);
    final subtitle = _subtitle();

    void toggle() {
      onChanged();
      state.toggleHabitCompletion(habit.id, dateKey: todayKey);
    }

    final content = Row(
      children: [
        if (!isCounter)
          Semantics(
            label: '${habit.title}, ${isDone ? 'hecho' : 'sin hacer'}',
            excludeSemantics: true,
            child: Checkbox(
              value: isDone,
              onChanged: (_) => toggle(),
              fillColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? SuiteApp.habitos.color : Colors.transparent,
              ),
              checkColor: t.onAccent,
            ),
          )
        else
          const SizedBox(width: OrtizSize.minTouch),
        Container(
          width: OrtizSize.dot,
          height: OrtizSize.dot,
          decoration: BoxDecoration(color: _color(), shape: BoxShape.circle),
        ),
        const SizedBox(width: OrtizSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OrtizType.body.copyWith(color: t.fg),
              ),
              if (subtitle != null)
                Text(subtitle, style: OrtizType.bodySm.copyWith(color: t.muted)),
            ],
          ),
        ),
        if (isCounter)
          Semantics(
            label: 'Sumar 1 a ${habit.title}',
            excludeSemantics: true,
            button: true,
            child: Tooltip(
              message: 'Sumar 1',
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(OrtizSize.minTouch, OrtizSize.minTouch)),
                onPressed: () {
                  onChanged();
                  state.incrementCounter(habit.id, dateStr: todayKey);
                },
                child: const Text('+1'),
              ),
            ),
          ),
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: OrtizSize.minTouch),
      child: isCounter ? content : InkWell(onTap: toggle, child: content),
    );
  }
}
