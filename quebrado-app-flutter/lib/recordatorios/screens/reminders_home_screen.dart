import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../dialogs/command_palette_dialog.dart';
import '../dialogs/covey_guide_dialog.dart';
import '../dialogs/reminder_editor_dialog.dart';
import '../dialogs/role_manager_dialog.dart';
import '../dialogs/sunday_planning_wizard_dialog.dart';
import '../models/reminder_model.dart';
import '../services/nlp_parser.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';
import '../widgets/covey_matrix_view.dart';
import '../widgets/weekly_schedule_view.dart';

import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import 'package:quebrado_app_flutter/widgets/suite_menu_button.dart';

class RemindersHomeScreen extends StatefulWidget {
  const RemindersHomeScreen({super.key, this.highlightReminderId});

  /// Recordatorio que se muestra resaltado y visible en la lista (ruta
  /// `/recordatorios/:id`, P-02 de `docs/design/rutas.md`).
  final String? highlightReminderId;

  @override
  State<RemindersHomeScreen> createState() => _RemindersHomeScreenState();
}

class _RemindersHomeScreenState extends State<RemindersHomeScreen> {
  final TextEditingController _quickInputController = TextEditingController();
  final FocusNode _quickInputFocus = FocusNode();
  String _activeTab = 'Todos'; // Todos, Vencidos, Hoy, Próximos, Pospuestos, Completados

  final Map<String, GlobalKey> _reminderCardKeys = {};
  String? _highlightedReminderId;
  late final PageController _pinnedPageController = PageController();
  int _pinnedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _quickInputController.addListener(() {
      setState(() {});
    });
    _highlightFromRoute();
  }

  @override
  void didUpdateWidget(covariant RemindersHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightReminderId != oldWidget.highlightReminderId) {
      _highlightFromRoute();
    }
  }

  /// Resalta [RemindersHomeScreen.highlightReminderId] en el feed (con todos
  /// los recordatorios) y lo desplaza a la vista. El resaltado se mantiene
  /// mientras la pantalla muestre esa ruta.
  void _highlightFromRoute() {
    final id = widget.highlightReminderId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RemindersState>().setSelectedView('classic');
      setState(() {
        _activeTab = 'Todos';
        _highlightedReminderId = id;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cardContext = _reminderCardKeys[id]?.currentContext;
        if (!mounted || cardContext == null) return;
        Scrollable.ensureVisible(
          cardContext,
          duration: OrtizMotion.of(context, OrtizMotion.base),
          curve: OrtizMotion.ease,
          alignment: 0.15,
        );
      });
    });
  }

  @override
  void dispose() {
    _quickInputController.dispose();
    _quickInputFocus.dispose();
    _pinnedPageController.dispose();
    super.dispose();
  }

  void _scrollToReminder(ReminderModel reminder) async {
    if (_activeTab != 'Todos') {
      setState(() {
        _activeTab = 'Todos';
      });
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final key = _reminderCardKeys[reminder.id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.15,
      );

      setState(() {
        _highlightedReminderId = reminder.id;
      });
      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted) {
        setState(() {
          _highlightedReminderId = null;
        });
      }
    }
  }

  void _openCommandPalette() {
    showDialog(
      context: context,
      builder: (context) => const CommandPaletteDialog(),
    );
  }

  void _openEditorDialog([ReminderModel? reminder]) {
    showDialog(
      context: context,
      builder: (context) => ReminderEditorDialog(reminder: reminder),
    );
  }

  void _submitQuickReminder(RemindersState state) {
    final text = _quickInputController.text.trim();
    if (text.isEmpty) return;

    state.createFromNlp(text);
    _quickInputController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recordatorio registrado: "$text"'),
        backgroundColor: RemindersColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final quickNlp = _quickInputController.text.trim().isNotEmpty
        ? NlpParser.parse(_quickInputController.text.trim())
        : null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () => _quickInputFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _quickInputFocus.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;

            return Scaffold(
              backgroundColor: RemindersColors.background,
              appBar: AppBar(
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: SuiteMenuButton.leading(context),
                title: Text(
                  isMobile ? 'Agenda Semanal' : 'Agenda & Hábitos (Covey)',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: OrtizFontSize.titleSm, color: RemindersColors.textPrimary),
                ),
                actions: isMobile
                    ? [
                        IconButton(
                          icon: const Icon(Icons.help_outline_rounded, size: OrtizIconSize.md, color: RemindersColors.primary),
                          tooltip: '¿Cómo organizarme?',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const CoveyGuideDialog(),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: OrtizIconSize.md, color: RemindersColors.textPrimary),
                          tooltip: 'Opciones de Agenda',
                          onSelected: (val) {
                            if (val == 'ritual') {
                              showDialog(context: context, builder: (_) => const SundayPlanningWizardDialog());
                            } else if (val == 'roles') {
                              showDialog(context: context, builder: (_) => const RoleManagerDialog());
                            } else if (val == 'palette') {
                              _openCommandPalette();
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'ritual',
                              child: Row(
                                children: [
                                  Icon(Icons.wb_sunny_outlined, size: OrtizIconSize.md, color: OrtizPalette.warn),
                                  SizedBox(width: OrtizSpace.sm),
                                  Text('Ritual Dominical', style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'roles',
                              child: Row(
                                children: [
                                  Icon(Icons.pie_chart_outline_rounded, size: OrtizIconSize.md, color: RemindersColors.primary),
                                  SizedBox(width: OrtizSpace.sm),
                                  Text('Roles Vitales (Brújula)', style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'palette',
                              child: Row(
                                children: [
                                  Icon(Icons.terminal_rounded, size: OrtizIconSize.md, color: RemindersColors.textMuted),
                                  SizedBox(width: OrtizSpace.sm),
                                  Text('Buscar / Comandos', style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: OrtizIconSize.lg, color: RemindersColors.primary),
                          tooltip: 'Nuevo Recordatorio',
                          onPressed: () => _openEditorDialog(),
                        ),
                        const SizedBox(width: OrtizSpace.xs),
                      ]
                    : [
                        // Botón Ritual Dominical de Stephen Covey
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                          child: TextButton.icon(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => const SundayPlanningWizardDialog(),
                            ),
                            icon: const Icon(Icons.wb_sunny_outlined, size: OrtizIconSize.sm, color: OrtizPalette.warn),
                            label: const Text(
                              'Ritual Dominical',
                              style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.warn),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: OrtizPalette.warnTint,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
                            ),
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.xs),
                        // Botón Gestor de Roles Vitales
                        IconButton(
                          icon: const Icon(Icons.pie_chart_outline_rounded, size: OrtizIconSize.md, color: RemindersColors.primary),
                          tooltip: 'Roles Vitales (Brújula)',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const RoleManagerDialog(),
                          ),
                        ),
                        // Atajo visual Command Palette
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: OrtizSpace.sm, horizontal: OrtizSpace.xs),
                          child: OutlinedButton.icon(
                            onPressed: _openCommandPalette,
                            icon: const Icon(Icons.terminal_rounded, size: OrtizIconSize.sm),
                            label: const Text('Cmd+K', style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: RemindersColors.primary,
                              side: BorderSide(color: RemindersColors.primary.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
                            ),
                          ),
                        ),
                        // Botón Guía Paso a Paso
                        IconButton(
                          icon: const Icon(Icons.help_outline_rounded, size: OrtizIconSize.md, color: RemindersColors.primary),
                          tooltip: '¿Cómo organizarme? (Guía Paso a Paso)',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const CoveyGuideDialog(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'Nuevo Recordatorio Completo',
                          onPressed: () => _openEditorDialog(),
                        ),
                        const SizedBox(width: OrtizSpace.sm),
                      ],
              ),
              body: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: RemindersColors.primary))
                  : Column(
                      children: [
                        // Barra de Switcher de Vistas Covey
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? OrtizSpace.md : OrtizSpace.xl, vertical: OrtizSpace.xs),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(OrtizSpace.xxs),
                                      decoration: BoxDecoration(
                                        color: OrtizPalette.surface,
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                        border: Border.all(color: OrtizPalette.line),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildViewSwitcherBtn(
                                            label: isMobile ? 'Semana' : 'Agenda Semanal',
                                            icon: Icons.calendar_view_week_rounded,
                                            viewKey: 'weekly',
                                            current: state.selectedView,
                                            onTap: () => state.setSelectedView('weekly'),
                                          ),
                                          _buildViewSwitcherBtn(
                                            label: 'Matriz 2x2',
                                            icon: Icons.grid_view_rounded,
                                            viewKey: 'matrix',
                                            current: state.selectedView,
                                            onTap: () => state.setSelectedView('matrix'),
                                          ),
                                          _buildViewSwitcherBtn(
                                            label: isMobile ? 'Feed' : 'Feed Clásico',
                                            icon: Icons.format_list_bulleted_rounded,
                                            viewKey: 'classic',
                                            current: state.selectedView,
                                            onTap: () => state.setSelectedView('classic'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: OrtizSpace.sm),
                                    // Botón Guía de Organización Paso a Paso
                                    TextButton.icon(
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => const CoveyGuideDialog(),
                                      ),
                                      icon: const Icon(Icons.school_outlined, size: OrtizIconSize.sm, color: RemindersColors.primary),
                                      label: Text(
                                        isMobile ? 'Guía' : '¿Cómo organizarme?',
                                        style: const TextStyle(
                                          fontSize: OrtizFontSize.bodySm,
                                          fontWeight: FontWeight.bold,
                                          color: RemindersColors.primary,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        backgroundColor: RemindersColors.primaryLight,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.sm),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                    // Banner de Recordatorios Fijados (visible para cualquier vista si hay fijados activos)
                    if (state.pinnedReminders.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xs, OrtizSpace.xl, OrtizSpace.xxs),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: _buildPinnedRemindersBanner(state),
                          ),
                        ),
                      ),

                    // Barra de Captura Ultrarrápida con NLP (presente en la parte superior)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xs, OrtizSpace.xl, OrtizSpace.xs),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: _buildQuickCaptureBar(state, quickNlp),
                        ),
                      ),
                    ),
                    Expanded(
                      child: state.selectedView == 'weekly'
                          ? const WeeklyScheduleView()
                          : state.selectedView == 'matrix'
                              ? const CoveyMatrixView()
                              : _buildClassicView(state),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: RemindersColors.primary,
            foregroundColor: OrtizPalette.onAccent,
            onPressed: () => _openEditorDialog(),
            tooltip: 'Crear Recordatorio',
            child: const Icon(Icons.add_task_rounded),
          ),
        );
      },
    ),
  ),
);
}

  Widget _buildViewSwitcherBtn({
    required String label,
    required IconData icon,
    required String viewKey,
    required String current,
    required VoidCallback onTap,
  }) {
    final isSelected = viewKey == current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OrtizRadius.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
        decoration: BoxDecoration(
          color: isSelected ? OrtizPalette.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: OrtizIconSize.sm,
              color: isSelected ? RemindersColors.primary : OrtizPalette.muted,
            ),
            const SizedBox(width: OrtizSpace.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: OrtizFontSize.caption,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? RemindersColors.primary : OrtizPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassicView(RemindersState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: CustomScrollView(
          slivers: [
            // Barra de Filtros y Estadísticas Rápidas
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl),
                child: _buildStatusFilterTabs(state),
              ),
            ),

            // Contenido Principal según Pestaña
            if (_activeTab == 'Todos') ...[
              _buildSectionSliver(
                title: 'VENCIDOS',
                count: state.overdueReminders.length,
                items: state.overdueReminders,
                color: RemindersColors.overdue,
                actionWidget: state.overdueCount > 0
                    ? TextButton.icon(
                        onPressed: () => state.snoozeAllOverdueToTomorrow(),
                        icon: const Icon(Icons.snooze_rounded, size: OrtizIconSize.xs),
                        label: const Text('Posponer a mañana', style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: RemindersColors.overdue),
                      )
                    : null,
              ),
              _buildSectionSliver(
                title: 'PARA HOY',
                count: state.todayReminders.length,
                items: state.todayReminders,
                color: RemindersColors.high,
              ),
              _buildSectionSliver(
                title: 'PRÓXIMOS',
                count: state.upcomingReminders.length,
                items: state.upcomingReminders,
                color: RemindersColors.primary,
              ),
              _buildSectionSliver(
                title: 'SIN FECHA LÍMITE',
                count: state.noDateReminders.length,
                items: state.noDateReminders,
                color: RemindersColors.low,
              ),
              _buildSectionSliver(
                title: 'COMPLETADOS',
                count: state.completedReminders.length,
                items: state.completedReminders,
                color: RemindersColors.completed,
                isCollapsible: true,
              ),
            ] else ...[
              _buildFilteredListSliver(state),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: BANNER DE RECORDATORIOS FIJADOS (ESTILO WHATSAPP/TELEGRAM)
  // ===========================================================================
  Widget _buildPinnedRemindersBanner(RemindersState state) {
    final pinned = state.pinnedReminders;
    if (pinned.isEmpty) return const SizedBox.shrink();

    final currentIndex = _pinnedPageIndex.clamp(0, pinned.length - 1);

    return Container(
      margin: const EdgeInsets.only(bottom: OrtizSpace.sm),
      // Bloque destacado sin sombra (como `OrtizSection(surface: true)`).
      decoration: BoxDecoration(
        color: OrtizPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 78,
              child: PageView.builder(
                controller: _pinnedPageController,
                itemCount: pinned.length,
                onPageChanged: (idx) {
                  setState(() => _pinnedPageIndex = idx);
                },
                itemBuilder: (context, index) {
                  final reminder = pinned[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _scrollToReminder(reminder),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                        child: Row(
                          children: [
                            // Vertical accent line
                            Container(
                              width: 3.5,
                              height: 38,
                              decoration: BoxDecoration(
                                color: reminder.priority.color,
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.sm),
                            // Pin icon circle
                            Container(
                              padding: const EdgeInsets.all(OrtizSpace.xs),
                              decoration: BoxDecoration(
                                color: RemindersColors.primary.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.push_pin_rounded,
                                size: OrtizIconSize.sm,
                                color: RemindersColors.primary,
                              ),
                            ),
                            const SizedBox(width: OrtizSpace.md),

                            // Content: Title & Days/Hours remaining
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'RECORDATORIO FIJADO',
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.caption,
                                          fontWeight: FontWeight.w900,
                                          color: RemindersColors.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (pinned.length > 1) ...[
                                        const SizedBox(width: OrtizSpace.xs),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                                          decoration: BoxDecoration(
                                            color: RemindersColors.primaryLight,
                                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                          ),
                                          child: Text(
                                            '${index + 1}/${pinned.length}',
                                            style: const TextStyle(
                                              fontSize: OrtizFontSize.micro,
                                              fontWeight: FontWeight.w800,
                                              color: RemindersColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: OrtizSpace.xxs),
                                  Text(
                                    reminder.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: OrtizFontSize.bodySm,
                                      fontWeight: FontWeight.w800,
                                      color: RemindersColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: OrtizSpace.xxs),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.alarm_rounded,
                                        size: OrtizIconSize.xs,
                                        color: reminder.isOverdue
                                            ? RemindersColors.overdue
                                            : RemindersColors.textSecondary,
                                      ),
                                      const SizedBox(width: OrtizSpace.xs),
                                      Expanded(
                                        child: Text(
                                          reminder.timeRemainingFormatted,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.caption,
                                            fontWeight: FontWeight.w700,
                                            color: reminder.isOverdue
                                                ? RemindersColors.overdue
                                                : RemindersColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Unpin Action Button
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: OrtizIconSize.sm, color: RemindersColors.textMuted),
                              tooltip: 'Desfijar recordatorio',
                              onPressed: () => state.togglePin(reminder.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Horizontal Swipe & Page Dots indicator if multiple pinned
            if (pinned.length > 1)
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md),
                decoration: BoxDecoration(
                  color: RemindersColors.background,
                  border: Border(top: BorderSide(color: RemindersColors.cardBorder.withValues(alpha: 0.5))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Desliza horizontalmente para ver más (${currentIndex + 1} de ${pinned.length})',
                      style: const TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(pinned.length, (dotIdx) {
                        final isSel = dotIdx == currentIndex;
                        return Container(
                          width: isSel ? 12 : 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxs),
                          decoration: BoxDecoration(
                            color: isSel ? RemindersColors.primary : OrtizPalette.line,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: BARRA DE CAPTURA RÁPIDA CON NLP
  // ===========================================================================
  Widget _buildQuickCaptureBar(RemindersState state, NlpParseResult? quickNlp) {
    return Container(
      // Campo de captura: flota sobre `surface`, sin sombra.
      decoration: BoxDecoration(
        color: OrtizPalette.surface,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        border: Border.all(color: RemindersColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.xs, OrtizSpace.sm, OrtizSpace.xs),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: RemindersColors.primary, size: OrtizIconSize.lg),
                const SizedBox(width: OrtizSpace.md),
                Expanded(
                  child: TextField(
                    controller: _quickInputController,
                    focusNode: _quickInputFocus,
                    decoration: const InputDecoration(
                      hintText: 'Captura rápida: ej. Pagar internet mañana 9am !urgente #casa ↵',
                      hintStyle: TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w600, color: RemindersColors.textPrimary),
                    onSubmitted: (_) => _submitQuickReminder(state),
                  ),
                ),
                if (_quickInputController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: OrtizIconSize.md),
                    onPressed: () => _quickInputController.clear(),
                  ),
                ElevatedButton(
                  onPressed: () => _submitQuickReminder(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RemindersColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                  ),
                  child: const Text('Crear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm)),
                ),
              ],
            ),
          ),
          // Previsualización en vivo de los tokens extraídos
          if (quickNlp != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
              decoration: BoxDecoration(
                color: RemindersColors.primaryLight.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(OrtizRadius.block)),
                border: const Border(top: BorderSide(color: RemindersColors.cardBorder)),
              ),
              child: Row(
                children: [
                  const Text('Detectado:', style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: RemindersColors.primary)),
                  const SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (quickNlp.dueAt != null)
                          _buildMiniChip(
                            icon: Icons.calendar_today_rounded,
                            label: quickNlp.matchedDateText ?? 'Fecha asignada',
                            color: RemindersColors.primary,
                          ),
                        if (quickNlp.isRecurring)
                          _buildMiniChip(
                            icon: Icons.repeat_rounded,
                            label: quickNlp.matchedRecurrenceText ?? quickNlp.recurrence.shortLabel,
                            color: RemindersColors.primary,
                          ),
                        _buildMiniChip(
                          icon: Icons.flag_rounded,
                          label: quickNlp.priority.label,
                          color: quickNlp.priority.color,
                        ),
                        ...quickNlp.tags.map(
                          (t) => _buildMiniChip(
                            icon: Icons.tag_rounded,
                            label: t,
                            color: RemindersColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OrtizRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: OrtizIconSize.xs, color: color),
          const SizedBox(width: OrtizSpace.xs),
          Text(label, style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET: PESTAÑAS DE ESTADO Y FILTROS
  // ===========================================================================
  Widget _buildStatusFilterTabs(RemindersState state) {
    final tabs = [
      {'label': 'Todos', 'count': state.pendingTotalCount},
      {'label': 'Vencidos', 'count': state.overdueCount, 'color': RemindersColors.overdue},
      {'label': 'Hoy', 'count': state.todayCount, 'color': RemindersColors.high},
      {'label': 'Completados', 'count': state.completedCount, 'color': RemindersColors.completed},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final label = tab['label'] as String;
          final count = tab['count'] as int;
          final color = (tab['color'] as Color?) ?? RemindersColors.primary;
          final isSelected = _activeTab == label;

          return Padding(
            padding: const EdgeInsets.only(right: OrtizSpace.sm, bottom: OrtizSpace.sm),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600, fontSize: OrtizFontSize.bodySm)),
                  if (count > 0) ...[
                    const SizedBox(width: OrtizSpace.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                      decoration: BoxDecoration(
                        color: isSelected ? OrtizPalette.onAccent.withValues(alpha: 0.2) : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: OrtizFontSize.caption,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? OrtizPalette.onAccent : color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: RemindersColors.primary,
              labelStyle: TextStyle(color: isSelected ? OrtizPalette.onAccent : RemindersColors.textSecondary),
              backgroundColor: Colors.transparent,
              side: BorderSide(color: isSelected ? RemindersColors.primary : RemindersColors.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
              onSelected: (_) => setState(() => _activeTab = label),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: SECCIONES INTELIGENTES
  // ===========================================================================
  Widget _buildSectionSliver({
    required String title,
    required int count,
    required List<ReminderModel> items,
    required Color color,
    Widget? actionWidget,
    bool isCollapsible = false,
  }) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.lg, OrtizSpace.xl, OrtizSpace.sm),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                ),
                const SizedBox(width: OrtizSpace.sm),
                Text(
                  title,
                  style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
                ),
                const SizedBox(width: OrtizSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                  child: Text('$count', style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: color)),
                ),
                const Spacer(),
                ?actionWidget,
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ortizStaggered(context, index, _buildReminderCard(items[index])),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredListSliver(RemindersState state) {
    List<ReminderModel> items = [];
    if (_activeTab == 'Vencidos') items = state.overdueReminders;
    if (_activeTab == 'Hoy') items = state.todayReminders;
    if (_activeTab == 'Completados') items = state.completedReminders;

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.xxxl),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.done_all_rounded, size: OrtizIconSize.xxl, color: OrtizPalette.faint),
                const SizedBox(height: OrtizSpace.md),
                Text(
                  'No hay recordatorios en "$_activeTab"',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: RemindersColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.sm, OrtizSpace.xl, OrtizSpace.xl),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => ortizStaggered(context, index, _buildReminderCard(items[index])),
          childCount: items.length,
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: TARJETA INDIVIDUAL DE RECORDATORIO
  // ===========================================================================
  Widget _buildReminderCard(ReminderModel reminder) {
    final state = Provider.of<RemindersState>(context, listen: false);
    final cardKey = _reminderCardKeys.putIfAbsent(reminder.id, () => GlobalKey());
    final isHighlighted = _highlightedReminderId == reminder.id;

    return AnimatedContainer(
      key: cardKey,
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: OrtizSpace.sm),
      decoration: BoxDecoration(
        // Fila sin tarjeta: el resaltado va sobre `surfaceHigh` y la línea
        // inferior separa una fila de otra.
        color: isHighlighted ? OrtizPalette.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        border: isHighlighted
            ? Border.all(color: RemindersColors.primary, width: 2.0)
            : Border(
                bottom: BorderSide(
                  color: reminder.isOverdue
                      ? RemindersColors.overdue.withValues(alpha: 0.4)
                      : RemindersColors.cardBorder,
                ),
              ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        child: InkWell(
          borderRadius: BorderRadius.circular(OrtizRadius.block),
          onTap: () => _openEditorDialog(reminder),
          child: Padding(
            padding: const EdgeInsets.all(OrtizSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox interactivo
                GestureDetector(
                  onTap: () => state.toggleCompleted(reminder.id),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: OrtizSpace.xxs, right: OrtizSpace.md),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reminder.isCompleted ? RemindersColors.completed : Colors.transparent,
                      border: Border.all(
                        color: reminder.isCompleted
                            ? RemindersColors.completed
                            : reminder.priority.color,
                        width: 2,
                      ),
                    ),
                    child: reminder.isCompleted
                        ? const Icon(Icons.check_rounded, size: OrtizIconSize.xs, color: OrtizPalette.onAccent)
                        : null,
                  ),
                ),

                // Contenido Principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título, Pinned Badge y Priority Badge
                      Row(
                        children: [
                          if (reminder.isPinned) ...[
                            Container(
                              margin: const EdgeInsets.only(right: OrtizSpace.xs),
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                              decoration: BoxDecoration(
                                color: RemindersColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.push_pin_rounded, size: OrtizFontSize.micro, color: RemindersColors.primary),
                                  SizedBox(width: OrtizSpace.xxs),
                                  Text(
                                    'Fijado',
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.micro,
                                      fontWeight: FontWeight.w800,
                                      color: RemindersColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              reminder.title,
                              style: TextStyle(
                                fontSize: OrtizFontSize.body,
                                fontWeight: FontWeight.w700,
                                color: reminder.isCompleted ? RemindersColors.textMuted : RemindersColors.textPrimary,
                                decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          // Badge Prioridad
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                            decoration: BoxDecoration(
                              color: reminder.priority.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: Text(
                              reminder.priority.label.split(' ')[0], // P1, P2...
                              style: TextStyle(fontSize: OrtizFontSize.micro, fontWeight: FontWeight.bold, color: reminder.priority.color),
                            ),
                          ),
                        ],
                      ),

                      // Notas
                      if (reminder.notes != null && reminder.notes!.isNotEmpty) ...[
                        const SizedBox(height: OrtizSpace.xs),
                        Text(
                          reminder.notes!,
                          style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: OrtizSpace.sm),

                      // Fecha / Hora + Tags + Nagging Indicator
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (reminder.dueAt != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.alarm_rounded,
                                  size: OrtizIconSize.xs,
                                  color: reminder.isOverdue
                                      ? RemindersColors.overdue
                                      : RemindersColors.textSecondary,
                                ),
                                const SizedBox(width: OrtizSpace.xs),
                                Text(
                                  reminder.formattedDueTime,
                                  style: TextStyle(
                                    fontSize: OrtizFontSize.caption,
                                    fontWeight: FontWeight.w700,
                                    color: reminder.isOverdue
                                        ? RemindersColors.overdue
                                        : RemindersColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),

                          // Nagging indicator
                          if (reminder.isNagging)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                              decoration: BoxDecoration(
                                color: OrtizPalette.warnTint,
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.notifications_active_rounded, size: OrtizFontSize.micro, color: OrtizPalette.warn),
                                  SizedBox(width: OrtizSpace.xxs),
                                  Text('Nagging', style: TextStyle(fontSize: OrtizFontSize.micro, fontWeight: FontWeight.bold, color: OrtizPalette.warn)),
                                ],
                              ),
                            ),

                          // Recurrence badge
                          if (reminder.isRecurring)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                              decoration: BoxDecoration(
                                color: RemindersColors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.repeat_rounded, size: OrtizFontSize.micro, color: RemindersColors.primary),
                                  const SizedBox(width: OrtizSpace.xxs),
                                  Text(
                                    reminder.recurrence.shortLabel,
                                    style: const TextStyle(
                                      fontSize: OrtizFontSize.micro,
                                      fontWeight: FontWeight.bold,
                                      color: RemindersColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Tags
                          ...reminder.tags.map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                              decoration: BoxDecoration(
                                color: OrtizPalette.surfaceHigh,
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Botones de acción (Snooze y Menú)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Menú Smart Snooze
                    PopupMenuButton<Duration>(
                      icon: const Icon(Icons.snooze_rounded, size: OrtizIconSize.md, color: RemindersColors.snoozed),
                      tooltip: 'Posponer (Smart Snooze)',
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                      onSelected: (duration) {
                        state.snoozeRelative(reminder.id, duration);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: Duration(minutes: 15),
                          child: Text('+15 minutos'),
                        ),
                        const PopupMenuItem(
                          value: Duration(hours: 1),
                          child: Text('+1 hora'),
                        ),
                        const PopupMenuItem(
                          value: Duration(hours: 3),
                          child: Text('+3 horas'),
                        ),
                        PopupMenuItem(
                          onTap: () {
                            final now = DateTime.now();
                            final tonight = DateTime(now.year, now.month, now.day, 20, 0);
                            state.snoozeTo(reminder.id, tonight);
                          },
                          child: const Text('Esta noche (8:00 PM)'),
                        ),
                        PopupMenuItem(
                          onTap: () {
                            final now = DateTime.now();
                            final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
                            state.snoozeTo(reminder.id, tomorrow);
                          },
                          child: const Text('Mañana (9:00 AM)'),
                        ),
                      ],
                    ),

                    // Menú de opciones adicionales
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: OrtizIconSize.md, color: RemindersColors.textMuted),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                      onSelected: (action) {
                        if (action == 'edit') _openEditorDialog(reminder);
                        if (action == 'pin') state.togglePin(reminder.id);
                        if (action == 'nagging') state.toggleNagging(reminder.id);
                        if (action == 'delete') state.deleteReminder(reminder.id);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(
                                reminder.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                                size: OrtizIconSize.sm,
                                color: reminder.isPinned ? RemindersColors.textSecondary : RemindersColors.primary,
                              ),
                              const SizedBox(width: OrtizSpace.sm),
                              Text(reminder.isPinned ? 'Desfijar' : 'Fijar recordatorio'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: OrtizIconSize.sm),
                              SizedBox(width: OrtizSpace.sm),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'nagging',
                          child: Row(
                            children: [
                              Icon(reminder.isNagging ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, size: OrtizIconSize.sm),
                              const SizedBox(width: OrtizSpace.sm),
                              Text(reminder.isNagging ? 'Desactivar Nagging' : 'Activar Nagging'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: OrtizIconSize.sm, color: RemindersColors.overdue),
                              SizedBox(width: OrtizSpace.sm),
                              Text('Eliminar', style: TextStyle(color: RemindersColors.overdue)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
