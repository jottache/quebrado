import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_contact.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../dialogs/contact_editor_dialog.dart';
import 'contact_detail_screen.dart';
import 'template_manager_screen.dart';
import 'diario_search_screen.dart';
import '../widgets/diario_image_helper.dart';

class DiarioHomeScreen extends StatefulWidget {
  const DiarioHomeScreen({super.key});

  @override
  State<DiarioHomeScreen> createState() => _DiarioHomeScreenState();
}

class _DiarioHomeScreenState extends State<DiarioHomeScreen> {
  String _selectedFilter = 'Todos';
  String _searchQuery = '';

  final List<String> _filters = [
    'Todos', 'Favoritos', 'Familia', 'Amigos', 'Pareja'
  ];

  void _openAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => const ContactEditorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    final allContacts = state.contacts;

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

    return Scaffold(
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
            const Text(
              'Diario Jottache',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: DiarioColors.textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Búsqueda Global',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DiarioSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Modelos Reutilizables',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TemplateManagerScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.loadAll(),
        color: DiarioColors.primary,
        child: CustomScrollView(
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

            // 3. Section Title & Total
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Text(
                      'Directorio de Personas',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
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
                          'Presiona el botón inferior para agregar una nueva persona.',
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
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 80),
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
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddContactDialog,
        backgroundColor: DiarioColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nuevo Contacto', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
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
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => ContactDetailScreen(contactId: c.id)),
                    );
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
                            days == 0 ? '¡HOY!' : 'en ${days}d',
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ContactDetailScreen(contactId: contact.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Minimalist Avatar in Primary Tone
              Container(
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: DiarioColors.primary,
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
                    Row(
                      children: [
                        if (contact.relationship != null && contact.relationship!.isNotEmpty) ...[
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
                          const SizedBox(width: 8),
                        ],
                        if (contact.nickname != null && contact.nickname!.isNotEmpty) ...[
                          Text(
                            '"${contact.nickname}"',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(width: 8),
                        ],
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
                icon: const Icon(Icons.edit_outlined, size: 18, color: DiarioColors.textMuted),
                tooltip: 'Editar contacto',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ContactEditorDialog(contact: contact),
                  );
                },
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
