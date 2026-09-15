import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/reminder_model.dart';
import '../services/nlp_parser.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';
import '../dialogs/command_palette_dialog.dart';
import '../dialogs/reminder_editor_dialog.dart';

class RemindersHomeScreen extends StatefulWidget {
  const RemindersHomeScreen({super.key});

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
        child: Scaffold(
          backgroundColor: RemindersColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Recordatorios',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: RemindersColors.textPrimary),
            ),
            actions: [
              // Atajo visual Command Palette
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: OutlinedButton.icon(
                  onPressed: _openCommandPalette,
                  icon: const Icon(Icons.terminal_rounded, size: 16),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Buscar / Cmd+K', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RemindersColors.primary,
                    side: BorderSide(color: RemindersColors.primary.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Nuevo Recordatorio Completo',
                onPressed: () => _openEditorDialog(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: RemindersColors.primary))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: CustomScrollView(
                      slivers: [
                        // Recordatorios Fijados (Pinned Banner estilo WhatsApp/Telegram)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                            child: _buildPinnedRemindersBanner(state),
                          ),
                        ),

                        // 1. Barra de Captura Ultrarrápida con NLP
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                            child: _buildQuickCaptureBar(state, quickNlp),
                          ),
                        ),

                        // 2. Barra de Filtros y Estadísticas Rápidas
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildStatusFilterTabs(state),
                          ),
                        ),

                        // 3. Contenido Principal según Pestaña
                        if (_activeTab == 'Todos') ...[
                          _buildSectionSliver(
                            title: 'VENCIDOS',
                            count: state.overdueReminders.length,
                            items: state.overdueReminders,
                            color: RemindersColors.overdue,
                            actionWidget: state.overdueCount > 0
                                ? TextButton.icon(
                                    onPressed: () => state.snoozeAllOverdueToTomorrow(),
                                    icon: const Icon(Icons.snooze_rounded, size: 14),
                                    label: const Text('Posponer a mañana', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: RemindersColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => _openEditorDialog(),
            tooltip: 'Crear Recordatorio',
            child: const Icon(Icons.add_task_rounded),
          ),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RemindersColors.primary.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: RemindersColors.primary.withOpacity(0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Row(
                          children: [
                            // Vertical accent line
                            Container(
                              width: 3.5,
                              height: 38,
                              decoration: BoxDecoration(
                                color: reminder.priority.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Pin icon circle
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: RemindersColors.primary.withOpacity(0.10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.push_pin_rounded,
                                size: 15,
                                color: RemindersColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),

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
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: RemindersColors.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (pinned.length > 1) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: RemindersColors.primaryLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${index + 1}/${pinned.length}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: RemindersColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    reminder.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: RemindersColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.alarm_rounded,
                                        size: 11,
                                        color: reminder.isOverdue
                                            ? RemindersColors.overdue
                                            : RemindersColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          reminder.timeRemainingFormatted,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
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
                              icon: const Icon(Icons.close_rounded, size: 16, color: RemindersColors.textMuted),
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: RemindersColors.background,
                  border: Border(top: BorderSide(color: RemindersColors.cardBorder.withOpacity(0.5))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Desliza horizontalmente para ver más (${currentIndex + 1} de ${pinned.length})',
                      style: const TextStyle(fontSize: 10, color: RemindersColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(pinned.length, (dotIdx) {
                        final isSel = dotIdx == currentIndex;
                        return Container(
                          width: isSel ? 12 : 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSel ? RemindersColors.primary : Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RemindersColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: RemindersColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quickInputController,
                    focusNode: _quickInputFocus,
                    decoration: const InputDecoration(
                      hintText: 'Captura rápida: ej. Pagar internet mañana 9am !urgente #casa ↵',
                      hintStyle: TextStyle(fontSize: 13, color: RemindersColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RemindersColors.textPrimary),
                    onSubmitted: (_) => _submitQuickReminder(state),
                  ),
                ),
                if (_quickInputController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => _quickInputController.clear(),
                  ),
                ElevatedButton(
                  onPressed: () => _submitQuickReminder(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RemindersColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Crear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          // Previsualización en vivo de los tokens extraídos
          if (quickNlp != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: RemindersColors.primaryLight.withOpacity(0.4),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: const Border(top: BorderSide(color: RemindersColors.cardBorder)),
              ),
              child: Row(
                children: [
                  const Text('Detectado:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: RemindersColors.primary)),
                  const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
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
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600, fontSize: 12)),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.3) : color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: RemindersColors.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : RemindersColors.textSecondary),
              backgroundColor: Colors.white,
              side: BorderSide(color: isSelected ? RemindersColors.primary : RemindersColors.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                ),
                const Spacer(),
                ?actionWidget,
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildReminderCard(items[index]),
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
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.done_all_rounded, size: 48, color: RemindersColors.textMuted.withOpacity(0.5)),
                const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildReminderCard(items[index]),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isHighlighted ? RemindersColors.primary.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? RemindersColors.primary
              : (reminder.isOverdue
                  ? RemindersColors.overdue.withOpacity(0.4)
                  : RemindersColors.cardBorder),
          width: isHighlighted ? 2.0 : (reminder.isOverdue ? 1.5 : 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? RemindersColors.primary.withOpacity(0.20)
                : Colors.black.withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: isHighlighted ? 12 : 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEditorDialog(reminder),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox interactivo
                GestureDetector(
                  onTap: () => state.toggleCompleted(reminder.id),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reminder.isCompleted ? RemindersColors.completed : Colors.white,
                      border: Border.all(
                        color: reminder.isCompleted
                            ? RemindersColors.completed
                            : reminder.priority.color,
                        width: 2,
                      ),
                    ),
                    child: reminder.isCompleted
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
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
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: RemindersColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.push_pin_rounded, size: 10, color: RemindersColors.primary),
                                  SizedBox(width: 3),
                                  Text(
                                    'Fijado',
                                    style: TextStyle(
                                      fontSize: 9,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: reminder.isCompleted ? RemindersColors.textMuted : RemindersColors.textPrimary,
                                decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          // Badge Prioridad
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: reminder.priority.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              reminder.priority.label.split(' ')[0], // P1, P2...
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: reminder.priority.color),
                            ),
                          ),
                        ],
                      ),

                      // Notas
                      if (reminder.notes != null && reminder.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.notes!,
                          style: const TextStyle(fontSize: 12, color: RemindersColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 8),

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
                                  size: 13,
                                  color: reminder.isOverdue
                                      ? RemindersColors.overdue
                                      : RemindersColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  reminder.formattedDueTime,
                                  style: TextStyle(
                                    fontSize: 11,
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
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.notifications_active_rounded, size: 10, color: Colors.orange),
                                  SizedBox(width: 3),
                                  Text('Nagging', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                                ],
                              ),
                            ),

                          // Recurrence badge
                          if (reminder.isRecurring)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: RemindersColors.primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.repeat_rounded, size: 10, color: RemindersColors.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    reminder.recurrence.shortLabel,
                                    style: const TextStyle(
                                      fontSize: 9,
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600),
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
                      icon: const Icon(Icons.snooze_rounded, size: 18, color: RemindersColors.snoozed),
                      tooltip: 'Posponer (Smart Snooze)',
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: RemindersColors.textMuted),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                                size: 16,
                                color: reminder.isPinned ? RemindersColors.textSecondary : RemindersColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(reminder.isPinned ? 'Desfijar' : 'Fijar recordatorio'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'nagging',
                          child: Row(
                            children: [
                              Icon(reminder.isNagging ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, size: 16),
                              const SizedBox(width: 8),
                              Text(reminder.isNagging ? 'Desactivar Nagging' : 'Activar Nagging'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: RemindersColors.overdue),
                              SizedBox(width: 8),
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
