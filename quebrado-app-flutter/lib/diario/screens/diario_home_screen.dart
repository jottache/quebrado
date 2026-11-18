import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_contact.dart';
import '../viewmodels/diario_state.dart';
import '../viewmodels/animo_state.dart';
import 'animo_dashboard_screen.dart';
import '../theme/diario_colors.dart';
import '../dialogs/contact_editor_dialog.dart';
import 'contact_detail_screen.dart';
import 'entry_editor_dialog.dart';
import '../dialogs/quick_note_dialog.dart';
import 'template_manager_screen.dart';
import 'diario_search_screen.dart';
import '../widgets/diario_image_helper.dart';
import '../widgets/personal_notes_view.dart';
import '../../widgets/responsive_breakpoints.dart';
import '../../widgets/suite_menu_button.dart';

import '../../widgets/ortiz/ortiz.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
/// Margen inferior de las listas para que el FAB extendido no tape la última
/// fila (antes 88 px: objetivo táctil + 32 + 8).
const double _fabClearance = OrtizSize.minTouch + OrtizSpace.xxxl + OrtizSpace.sm;

class DiarioHomeScreen extends StatefulWidget {
  const DiarioHomeScreen({super.key});

  @override
  State<DiarioHomeScreen> createState() => _DiarioHomeScreenState();
}

class _DiarioHomeScreenState extends State<DiarioHomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  String _selectedFilter = 'Todos';
  String _searchQuery = '';
  String? _selectedContactId;
  String? _activeDrawerContent; // 'search' | 'templates'

  final List<String> _filters = [
    'Todos', 'Favoritos', 'Familia', 'Amigos', 'Pareja'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => const ContactEditorDialog(),
    );
  }

  void _openAddPersonalNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => const QuickNoteDialog(),
    );
  }

  void _openQuickAddEntry(DiarioContact contact) {
    final state = Provider.of<DiarioState>(context, listen: false);
    final rootCategories = state.getRootCategories(contact.id);
    final defaultCatId = rootCategories.firstOrNull?.id ?? 'cat_alimentos';

    showDialog(
      context: context,
      builder: (context) => EntryEditorDialog(
        contactId: contact.id,
        categoryId: defaultCatId,
      ),
    );
  }

  Widget _buildEndDrawer(BuildContext context, bool isDesktop) {
    final drawerWidth = isDesktop ? 550.0 : MediaQuery.of(context).size.width * 0.92;
    return Drawer(
      width: drawerWidth,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(OrtizRadius.sheet)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _activeDrawerContent == 'templates'
          ? const TemplateManagerScreen(isDrawer: true)
          : DiarioSearchScreen(
              isDrawer: true,
              onSelectContact: (contactId) {
                setState(() {
                  _selectedContactId = contactId;
                  if (!isDesktop && _tabController.index != 1) {
                    _tabController.animateTo(1);
                  }
                });
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    final allContacts = state.contacts;
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    // Filter contacts
    List<DiarioContact> filtered = allContacts.where((c) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = c.name.toLowerCase().contains(q) ||
            (c.nickname?.toLowerCase().contains(q) ?? false) ||
            (c.relationship?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }

      if (_selectedFilter == 'Favoritos') return c.isFavorite;
      if (_selectedFilter == 'Familia') {
        final rel = c.relationship?.toLowerCase() ?? '';
        return rel.contains('familia') || rel.contains('sobrin') || rel.contains('hijo') || rel.contains('herman') || rel.contains('papá') || rel.contains('mamá');
      }
      if (_selectedFilter == 'Amigos') {
        final rel = c.relationship?.toLowerCase() ?? '';
        return rel.contains('amig');
      }
      if (_selectedFilter == 'Pareja') {
        final rel = c.relationship?.toLowerCase() ?? '';
        return rel.contains('novi') || rel.contains('espos') || rel.contains('pareja');
      }
      return true;
    }).toList();

    final upcomingBirthdays = state.getUpcomingBirthdays(limit: 3);
    final activeContactId = state.selectedContactId ?? _selectedContactId;

    if (state.selectedContactId != null && !isDesktop && _tabController.index != 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index != 1) {
          _tabController.animateTo(1);
        }
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: _buildEndDrawer(context, isDesktop),
      backgroundColor: DiarioColors.background,
      appBar: AppBar(
        backgroundColor: DiarioColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: SuiteMenuButton.leading(context),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: DiarioColors.primaryLight,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: DiarioColors.primary, size: OrtizIconSize.md),
            ),
            const SizedBox(width: OrtizSpace.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Diario Jottache',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: OrtizFontSize.titleSm, color: DiarioColors.textPrimary),
                  ),
                  if (isDesktop)
                    const Text(
                      'Notas Personales & Directorio',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w600, color: DiarioColors.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (AnimoState.maybeOf(context, listen: false) != null)
            IconButton(
              icon: const Icon(Icons.mood_rounded),
              tooltip: 'Mi ánimo',
              onPressed: () => openAnimoDashboard(context),
            ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Búsqueda Global',
            onPressed: () {
              setState(() => _activeDrawerContent = 'search');
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Modelos Reutilizables',
            onPressed: () {
              if (isDesktop) {
                setState(() => _activeDrawerContent = 'templates');
                _scaffoldKey.currentState?.openEndDrawer();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const TemplateManagerScreen()),
                );
              }
            },
          ),
          const SizedBox(width: OrtizSpace.xs),
        ],
        bottom: isDesktop
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.fromLTRB(OrtizSpace.lg, 0, OrtizSpace.lg, OrtizSpace.sm),
                  padding: const EdgeInsets.all(OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    color: DiarioColors.surface,
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    border: Border.all(color: DiarioColors.cardBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: DiarioColors.primary,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: OrtizPalette.onAccent,
                    unselectedLabelColor: DiarioColors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: OrtizFontSize.bodySm),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.bodySm),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        iconMargin: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_note_rounded, size: OrtizIconSize.md),
                            SizedBox(width: OrtizSpace.xs),
                            Text('Mis Notas'),
                          ],
                        ),
                      ),
                      Tab(
                        iconMargin: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: OrtizIconSize.md),
                            SizedBox(width: OrtizSpace.xs),
                            Text('Contactos'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: PopScope(
        canPop: activeContactId == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && activeContactId != null) {
            state.selectContact(null);
            setState(() {
              _selectedContactId = null;
            });
          }
        },
        child: RefreshIndicator(
          onRefresh: () => state.loadAll(),
          color: DiarioColors.primary,
          child: isDesktop
              ? _buildDesktopLayout(context, state, filtered, upcomingBirthdays, activeContactId)
              : _buildMobileLayout(context, state, filtered, upcomingBirthdays, activeContactId),
        ),
      ),
      floatingActionButton: isDesktop
          ? (activeContactId != null
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'fab_diario_desktop',
                  onPressed: _openAddContactDialog,
                  backgroundColor: DiarioColors.primary,
                  foregroundColor: OrtizPalette.onAccent,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Nuevo Contacto', style: TextStyle(fontWeight: FontWeight.bold)),
                ))
          : (_tabController.index == 0
              ? FloatingActionButton.extended(
                  heroTag: 'fab_diario_personal_mob',
                  onPressed: _openAddPersonalNoteDialog,
                  backgroundColor: DiarioColors.primary,
                  foregroundColor: OrtizPalette.onAccent,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Nueva Nota', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : (activeContactId != null
                  ? null
                  : FloatingActionButton.extended(
                      heroTag: 'fab_diario_contact_mob',
                      onPressed: _openAddContactDialog,
                      backgroundColor: DiarioColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Nuevo Contacto', style: TextStyle(fontWeight: FontWeight.bold)),
                    ))),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    DiarioState state,
    List<DiarioContact> filtered,
    List<DiarioContact> upcomingBirthdays,
    String? activeContactId,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Mis Notas Personales
            const Expanded(
              flex: 5,
              child: PersonalNotesView(
                padding: EdgeInsets.fromLTRB(OrtizSpace.xxl, OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.xxxl),
              ),
            ),

            // Vertical Divider between columns
            Container(
              width: 1,
              color: DiarioColors.cardBorder,
            ),

            // Right Column: Directorio de Contactos o Detalle de Contacto
            Expanded(
              flex: 6,
              child: activeContactId != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
                      child: ContactDetailScreen(
                        key: ValueKey(activeContactId),
                        contactId: activeContactId,
                        embedded: true,
                        onBack: () {
                          state.selectContact(null);
                          setState(() => _selectedContactId = null);
                        },
                      ),
                    )
                  : _buildContactsDirectoryView(
                      context,
                      state,
                      filtered,
                      upcomingBirthdays,
                      padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xl, OrtizSpace.xxl, _fabClearance),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    DiarioState state,
    List<DiarioContact> filtered,
    List<DiarioContact> upcomingBirthdays,
    String? activeContactId,
  ) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 1: Mis Notas Personales
        const PersonalNotesView(
          padding: EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.lg, _fabClearance),
        ),

        // Tab 2: Directorio de Contactos o Detalle de Contacto
        activeContactId != null
            ? ContactDetailScreen(
                key: ValueKey(activeContactId),
                contactId: activeContactId,
                embedded: true,
                onBack: () {
                  state.selectContact(null);
                  setState(() => _selectedContactId = null);
                },
              )
            : _buildContactsDirectoryView(
                context,
                state,
                filtered,
                upcomingBirthdays,
                padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xs, OrtizSpace.xl, _fabClearance),
              ),
      ],
    );
  }

  Widget _buildContactsDirectoryView(
    BuildContext context,
    DiarioState state,
    List<DiarioContact> filtered,
    List<DiarioContact> upcomingBirthdays, {
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.xs, OrtizSpace.xl, _fabClearance),
  }) {
    return CustomScrollView(
      slivers: [
        // 1. Upcoming Birthdays Strip (if any)
        if (upcomingBirthdays.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildUpcomingBirthdaysBanner(upcomingBirthdays),
          ),

        // 2. Search & Filter Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.lg, OrtizSpace.xl, OrtizSpace.sm),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar contacto por nombre o rol...',
                    prefixIcon: const Icon(Icons.search_rounded, size: OrtizIconSize.md, color: DiarioColors.textMuted),
                    filled: true,
                    fillColor: DiarioColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
                      borderSide: const BorderSide(color: DiarioColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
                      borderSide: const BorderSide(color: DiarioColors.cardBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
                  ),
                ),

                const SizedBox(height: OrtizSpace.md),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: OrtizSpace.sm),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: DiarioColors.primary,
                          backgroundColor: DiarioColors.background,
                          labelStyle: TextStyle(
                            fontSize: OrtizFontSize.bodySm,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? OrtizPalette.onAccent : DiarioColors.textPrimary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                            side: BorderSide(
                              color: isSelected ? DiarioColors.primary : DiarioColors.cardBorder,
                            ),
                          ),
                          onSelected: (val) => setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Section Title, Total & Action
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.md, OrtizSpace.xl, OrtizSpace.sm),
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    'Directorio de Personas',
                    style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: OrtizSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                  decoration: BoxDecoration(
                    color: DiarioColors.primaryLight,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                  child: Text(
                    '${filtered.length}',
                    style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w800, color: DiarioColors.primary),
                  ),
                ),
                if (ResponsiveBreakpoints.isDesktop(context)) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openAddContactDialog,
                    icon: const Icon(Icons.add, size: OrtizIconSize.sm, color: DiarioColors.primary),
                    label: const Text(
                      'Nuevo Contacto',
                      style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w800, color: DiarioColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 4. Contact Cards List or Empty
        if (filtered.isEmpty)
          const SliverToBoxAdapter(
            child: OrtizEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No hay contactos que coincidan',
              message: 'Presiona el botón para agregar una nueva persona.',
            ),
          )
        else
          SliverPadding(
            padding: padding,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final contact = filtered[index];
                  return _buildContactCard(context, contact, state);
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingBirthdaysBanner(List<DiarioContact> birthdays) {
    // Sin tarjeta (spec 05, C4): franja sobre el fondo, con su encabezado.
    return Padding(
      padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.lg, OrtizSpace.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cake_outlined, color: DiarioColors.primary, size: OrtizIconSize.sm),
              SizedBox(width: OrtizSpace.sm),
              Text(
                'PRÓXIMOS CUMPLEAÑOS',
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: DiarioColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: OrtizSpace.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: birthdays.map((c) {
                final days = c.daysUntilBirthday;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedContactId = c.id;
                    });
                  },
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  child: Container(
                    margin: const EdgeInsets.only(right: OrtizSpace.sm),
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                    decoration: BoxDecoration(
                      color: DiarioColors.surfaceHover,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      border: Border.all(color: DiarioColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w700, color: DiarioColors.textPrimary),
                        ),
                        const SizedBox(width: OrtizSpace.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                          decoration: BoxDecoration(
                            color: DiarioColors.primaryLight,
                            borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          ),
                          child: Text(
                            days == 0
                                ? (c.ageOnUpcomingBirthday != null ? '¡HOY! (cumple ${c.ageOnUpcomingBirthday})' : '¡HOY!')
                                : (c.ageOnUpcomingBirthday != null ? 'en ${days}d (cumplirá ${c.ageOnUpcomingBirthday})' : 'en ${days}d'),
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w800,
                              color: DiarioColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, DiarioContact contact, DiarioState state) {
    final entriesCount = state.getEntriesForContact(contact.id).length;

    // Sin tarjeta (spec 05, C4): fila sobre el fondo; las filas se separan
    // con una línea fina.
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DiarioColors.cardBorder)),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedContactId = contact.id;
          });
        },
        borderRadius: BorderRadius.circular(OrtizRadius.field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.md),
          child: Row(
            children: [
              // Minimalist Avatar in Primary Tone (Tap to zoom if photo exists)
              GestureDetector(
                onTap: (contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty)
                    ? () {
                        DiarioImageHelper.openFullScreenImage(
                          context,
                          contact.avatarUrl!,
                          title: contact.name,
                        );
                      }
                    : null,
                child: MouseRegion(
                  cursor: (contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty)
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DiarioColors.primary.withValues(alpha: 0.20),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty
                        ? ClipOval(
                            child: DiarioImageHelper.buildImageWidget(
                              contact.avatarUrl!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            contact.initials,
                            style: const TextStyle(
                              fontSize: OrtizFontSize.titleSm,
                              fontWeight: FontWeight.w900,
                              color: DiarioColors.primary,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(width: OrtizSpace.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            style: const TextStyle(
                              fontSize: OrtizFontSize.body,
                              fontWeight: FontWeight.w900,
                              color: DiarioColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (contact.isFavorite) ...[
                          const SizedBox(width: OrtizSpace.xs),
                          const Icon(Icons.star_rounded, size: OrtizIconSize.sm, color: DiarioColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: OrtizSpace.xs),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (contact.relationship != null && contact.relationship!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                            decoration: BoxDecoration(
                              color: DiarioColors.surfaceHover,
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              border: Border.all(color: DiarioColors.cardBorder),
                            ),
                            child: Text(
                              contact.relationship!,
                              style: const TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.w700,
                                color: DiarioColors.textSecondary,
                              ),
                            ),
                          ),
                        if (contact.currentAge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                            decoration: BoxDecoration(
                              color: DiarioColors.primaryLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: Text(
                              '${contact.currentAge} años',
                              style: const TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.w700,
                                color: DiarioColors.primary,
                              ),
                            ),
                          ),
                        if (contact.nickname != null && contact.nickname!.isNotEmpty)
                          Text(
                            '"${contact.nickname}"',
                            style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: DiarioColors.textSecondary, fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '$entriesCount ${entriesCount == 1 ? "registro" : "registros"}',
                          style: const TextStyle(fontSize: OrtizFontSize.caption, color: DiarioColors.textMuted),
                        ),
                        ?_buildPerceivedMoodBadge(contact),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(Icons.note_add_outlined, size: OrtizIconSize.md, color: DiarioColors.primary),
                tooltip: 'Agregar nota rápida',
                onPressed: () => _openQuickAddEntry(contact),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: OrtizIconSize.sm, color: DiarioColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Emoji del último ánimo percibido del contacto (si es de los últimos 14 días).
  Widget? _buildPerceivedMoodBadge(DiarioContact contact) {
    final latest = AnimoState.maybeOf(context)?.latestFor(contact.id);
    if (latest == null || DateTime.now().difference(latest.loggedAt).inDays > 14) return null;
    final meta = latest.valenceMeta;
    return Tooltip(
      message: 'Ánimo percibido: ${meta.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
        decoration: BoxDecoration(
          color: meta.lightColor,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
        ),
        child: Text(meta.emoji, style: const TextStyle(fontSize: OrtizFontSize.caption)),
      ),
    );
  }
}
