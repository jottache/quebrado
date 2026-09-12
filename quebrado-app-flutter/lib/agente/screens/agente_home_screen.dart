import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../viewmodels/agente_state.dart';
import '../theme/agente_colors.dart';
import '../dialogs/agente_settings_dialog.dart';
import '../models/chat_artifact_model.dart';
import '../widgets/artifact_card_view.dart';
import 'chat_conversation_screen.dart';

class AgenteHomeScreen extends StatefulWidget {
  const AgenteHomeScreen({super.key});

  @override
  State<AgenteHomeScreen> createState() => _AgenteHomeScreenState();
}

class _AgenteHomeScreenState extends State<AgenteHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ArtifactType? _filterType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agenteState = Provider.of<AgenteState>(context);
    final sessions = agenteState.sessions;
    final artifacts = _filterType == null
        ? agenteState.allArtifacts
        : agenteState.allArtifacts.where((a) => a.type == _filterType).toList();

    return Scaffold(
      backgroundColor: AgenteColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AgenteColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AgenteColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agente Ortiz',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'CHATS & ARTEFACTOS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AgenteColors.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AgenteColors.primary),
            tooltip: 'Ajustes del Agente',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AgenteSettingsDialog(),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AgenteColors.primary,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AgenteColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              text: 'Conversaciones (${sessions.length})',
            ),
            Tab(
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              text: 'Artefactos (${agenteState.allArtifacts.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Conversaciones
          _buildSessionsTab(context, agenteState),

          // TAB 2: Artefactos Guardados
          _buildArtifactsTab(context, artifacts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AgenteColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded, size: 20),
        label: const Text('Nueva Charla', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          await agenteState.startNewSession();
          if (mounted) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => const ChatConversationScreen(),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context, AgenteState agenteState) {
    final sessions = agenteState.sessions;

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No hay conversaciones guardadas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Inicia una nueva charla para interactuar con tu asistente.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = agenteState.currentSession?.id == session.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AgenteColors.primary : AgenteColors.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AgenteColors.primary : AgenteColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: isSelected ? Colors.white : AgenteColors.primary,
              ),
            ),
            title: Text(
              session.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${session.messageCount} mensajes • ${_formatDate(session.updatedAt)}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (val) {
                if (val == 'delete') {
                  agenteState.deleteSession(session.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar charla', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () async {
              await agenteState.selectSession(session.id);
              if (context.mounted) {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const ChatConversationScreen(),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildArtifactsTab(BuildContext context, List<ChatArtifactModel> artifacts) {
    return Column(
      children: [
        // Filter Chips Bar
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('Todos', null),
              _buildFilterChip('Finanzas', ArtifactType.financialSummary),
              _buildFilterChip('Cálculos', ArtifactType.calculation),
              _buildFilterChip('Contactos', ArtifactType.contactCard),
              _buildFilterChip('Tareas', ArtifactType.reminderList),
              _buildFilterChip('Tablas', ArtifactType.table),
            ],
          ),
        ),

        // Artifacts Grid / List
        Expanded(
          child: artifacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text(
                        'No hay artefactos generados',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Los cálculos y tablas generados en el chat aparecerán aquí.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: artifacts.length,
                  itemBuilder: (context, index) {
                    return ArtifactCardView(artifact: artifacts[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, ArtifactType? type) {
    final isSelected = _filterType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterType = type),
        selectedColor: AgenteColors.primaryLight,
        checkmarkColor: AgenteColors.primary,
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AgenteColors.primaryDark : Colors.grey[800],
        ),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }
}
