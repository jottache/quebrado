import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_contact.dart';
import '../viewmodels/diario_state.dart';
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
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
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
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: DiarioColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: DiarioColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Diario Jottache',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: DiarioColors.textPrimary),
                  ),
                  if (isDesktop)
                    const Text(
                      'Notas Personales & Directorio',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DiarioColors.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
          const SizedBox(width: 6),
        ],
        bottom: isDesktop
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: DiarioColors.primary,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: DiarioColors.primary.withOpacity(0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: DiarioColors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        iconMargin: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Mis Notas'),
                          ],
                        ),
                      ),
                      Tab(
                        iconMargin: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 18),
                            SizedBox(width: 6),
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
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Nuevo Contacto', style: TextStyle(fontWeight: FontWeight.bold)),
                ))
          : (_tabController.index == 0
              ? FloatingActionButton.extended(
                  heroTag: 'fab_diario_personal_mob',
                  onPressed: _openAddPersonalNoteDialog,
                  backgroundColor: DiarioColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Nueva Nota', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : (activeContactId != null
                  ? null
                  : FloatingActionButton.extended(
                      heroTag: 'fab_diario_contact_mob',
                      onPressed: _openAddContactDialog,
                      backgroundColor: DiarioColors.primary,
                      foregroundColor: Colors.white,
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
                padding: EdgeInsets.fromLTRB(24, 20, 20, 32),
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
                      borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.fromLTRB(20, 20, 24, 88),
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
          padding: EdgeInsets.fromLTRB(16, 16, 16, 88),
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
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 88),
              ),
      ],
    );
  }

  Widget _buildContactsDirectoryView(
    BuildContext context,
    DiarioState state,
    List<DiarioContact> filtered,
    List<DiarioContact> upcomingBirthdays, {
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 6, 20, 88),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar contacto por nombre o rol...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: DiarioColors.textMuted),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: DiarioColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: DiarioColors.cardBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),

                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: DiarioColors.primary,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? Colors.white : DiarioColors.textPrimary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    'Directorio de Personas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DiarioColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${filtered.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DiarioColors.primary),
                  ),
                ),
                if (ResponsiveBreakpoints.isDesktop(context)) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openAddContactDialog,
                    icon: const Icon(Icons.add, size: 16, color: DiarioColors.primary),
                    label: const Text(
                      'Nuevo Contacto',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DiarioColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 4. Contact Cards List or Empty
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 48, color: DiarioColors.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'No hay contactos que coincidan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DiarioColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Presiona el botón para agregar una nueva persona.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
                    ),
                  ],
                ),
              ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cake_outlined, color: DiarioColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'PRÓXIMOS CUMPLEAÑOS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: DiarioColors.surfaceHover,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DiarioColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            days == 0
                                ? (c.ageOnUpcomingBirthday != null ? '¡HOY! (cumple ${c.ageOnUpcomingBirthday})' : '¡HOY!')
                                : (c.ageOnUpcomingBirthday != null ? 'en ${days}d (cumplirá ${c.ageOnUpcomingBirthday})' : 'en ${days}d'),
                            style: TextStyle(
                              fontSize: 10,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedContactId = contact.id;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                        color: DiarioColors.primary.withOpacity(0.20),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: DiarioColors.primary,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

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
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (contact.isFavorite) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded, size: 16, color: DiarioColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (contact.relationship != null && contact.relationship!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DiarioColors.surfaceHover,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              contact.relationship!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        if (contact.currentAge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DiarioColors.primaryLight.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${contact.currentAge} años',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: DiarioColors.primary,
                              ),
                            ),
                          ),
                        if (contact.nickname != null && contact.nickname!.isNotEmpty)
                          Text(
                            '"${contact.nickname}"',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '$entriesCount ${entriesCount == 1 ? "registro" : "registros"}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(Icons.note_add_outlined, size: 19, color: DiarioColors.primary),
                tooltip: 'Agregar nota rápida',
                onPressed: () => _openQuickAddEntry(contact),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
