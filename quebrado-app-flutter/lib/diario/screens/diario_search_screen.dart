import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_contact.dart';
import '../models/diario_entry.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../widgets/diario_image_helper.dart';
import 'contact_detail_screen.dart';

class DiarioSearchScreen extends StatefulWidget {
  const DiarioSearchScreen({super.key});

  @override
  State<DiarioSearchScreen> createState() => _DiarioSearchScreenState();
}

class _DiarioSearchScreenState extends State<DiarioSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    final searchResult = state.searchGlobal(_query);

    return Scaffold(
      backgroundColor: DiarioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar por placa, comida, persona, modelo...',
            border: InputBorder.none,
            hintStyle: TextStyle(fontSize: 14, color: DiarioColors.textMuted),
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          onChanged: (val) => setState(() => _query = val),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.trim().isEmpty
          ? _buildInitialState()
          : searchResult.isEmpty
              ? _buildEmptyResultsState()
              : _buildResultsList(searchResult, state),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DiarioColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.manage_search_rounded, size: 34, color: DiarioColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Búsqueda Inteligente Global',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: DiarioColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escribe una placa (ej. AB-492), una comida (ej. pasta de hígado), una talla o un nombre para encontrar a la persona asociada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: DiarioColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: DiarioColors.textMuted),
            const SizedBox(height: 14),
            Text(
              'Sin resultados para "$_query"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DiarioColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Verifica que el término de búsqueda esté bien escrito.',
              style: TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(DiarioSearchResult result, DiarioState state) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. Personas encontradas
        if (result.matchedContacts.isNotEmpty) ...[
          Text(
            'PERSONAS (${result.matchedContacts.length})',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DiarioColors.textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          ...result.matchedContacts.map((c) => _buildContactResultItem(c)),
          const SizedBox(height: 20),
        ],

        // 2. Entradas y Datos encontrados
        if (result.matchedEntries.isNotEmpty) ...[
          Text(
            'REGISTROS Y DATOS (${result.matchedEntries.length})',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DiarioColors.textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          ...result.matchedEntries.map((e) => _buildEntryResultItem(e, state)),
        ],
      ],
    );
  }

  Widget _buildContactResultItem(DiarioContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ContactDetailScreen(contactId: contact.id),
            ),
          );
        },
        leading: GestureDetector(
          onTap: (contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty)
              ? () => DiarioImageHelper.openFullScreenImage(
                    context,
                    contact.avatarUrl!,
                    title: contact.name,
                  )
              : null,
          child: MouseRegion(
            cursor: (contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty)
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Container(
              width: 42,
              height: 42,
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
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      contact.initials,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: DiarioColors.primary),
                    ),
            ),
          ),
        ),
        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          contact.relationship ?? (contact.phone ?? 'Sin teléfono'),
          style: const TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DiarioColors.textMuted),
      ),
    );
  }

  Widget _buildEntryResultItem(DiarioEntry entry, DiarioState state) {
    final contact = state.getContactById(entry.contactId);
    final template = entry.templateId != null ? state.getTemplateById(entry.templateId!) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiarioColors.cardBorder),
      ),
      child: ListTile(
        onTap: () {
          if (contact != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ContactDetailScreen(contactId: contact.id),
              ),
            );
          }
        },
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: template != null ? template.color.withOpacity(0.12) : DiarioColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            template != null ? template.iconData : Icons.article_outlined,
            color: template != null ? template.color : DiarioColors.primary,
            size: 20,
          ),
        ),
        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          'En contacto: ${contact?.name ?? "Desconocido"}${template != null ? " • (${template.name})" : ""}',
          style: const TextStyle(fontSize: 12, color: DiarioColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.hasPhoto) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DiarioImageHelper.buildImageWidget(
                  entry.photoUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DiarioColors.textMuted),
          ],
        ),
      ),
    );
  }
}
