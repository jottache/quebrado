import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../viewmodels/agente_state.dart';
import '../theme/agente_colors.dart';
import '../dialogs/agente_settings_dialog.dart';
import '../dialogs/prompt_editor_dialog.dart';
import '../models/chat_artifact_model.dart';
import '../models/agente_prompt_model.dart';
import '../widgets/artifact_card_view.dart';
import '../widgets/agente_chat_bottom_sheet.dart';
import 'chat_conversation_screen.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Margen inferior de las listas para que el botón flotante no tape la última fila.
const double _fabClearance = OrtizSize.minTouch + OrtizSpace.xxxl;

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
    final prompts = agenteState.quickPrompts;

    return Scaffold(
      backgroundColor: AgenteColors.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(OrtizSpace.sm),
              decoration: BoxDecoration(
                color: AgenteColors.primaryLight,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AgenteColors.primary, size: OrtizIconSize.md),
            ),
            const SizedBox(width: OrtizSpace.sm),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ortiz',
                  style: TextStyle(
                    fontSize: OrtizFontSize.titleSm,
                    fontWeight: FontWeight.w900,
                    color: OrtizPalette.fg,
                  ),
                ),
                Text(
                  'CHATS, ARTEFACTOS & ATAJOS',
                  style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AgenteColors.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AgenteColors.primary),
            tooltip: 'Ajustes de Ortiz',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AgenteSettingsDialog(),
              );
            },
          ),
          const SizedBox(width: OrtizSpace.xs),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AgenteColors.primary,
          unselectedLabelColor: OrtizPalette.muted,
          indicatorColor: AgenteColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: OrtizFontSize.bodySm),
          tabs: [
            Tab(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: OrtizIconSize.md),
              text: 'Charlas (${sessions.length})',
            ),
            Tab(
              icon: const Icon(Icons.inventory_2_outlined, size: OrtizIconSize.md),
              text: 'Artefactos (${agenteState.allArtifacts.length})',
            ),
            Tab(
              icon: const Icon(Icons.bolt_rounded, size: OrtizIconSize.md),
              text: 'Prompts (${prompts.length})',
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Conversaciones
              _buildSessionsTab(context, agenteState),

              // TAB 2: Artefactos Guardados
              _buildArtifactsTab(context, artifacts),

              // TAB 3: Prompts Rápidos del Launcher
              _buildPromptsTab(context, agenteState),
            ],
          ),
        ),
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              backgroundColor: AgenteColors.primary,
              foregroundColor: OrtizPalette.onAccent,
              icon: const Icon(Icons.add_rounded, size: OrtizIconSize.md),
              label: const Text('Nuevo Prompt', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final newPrompt = await PromptEditorDialog.show(context);
                if (newPrompt != null) {
                  agenteState.saveQuickPrompt(newPrompt);
                }
              },
            )
          : FloatingActionButton.extended(
              backgroundColor: AgenteColors.primary,
              foregroundColor: OrtizPalette.onAccent,
              icon: const Icon(Icons.add_comment_rounded, size: OrtizIconSize.md),
              label: const Text('Nueva Charla', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                await agenteState.startNewSession();
                if (context.mounted) {
                  AgenteChatBottomSheet.show(context, autoFocus: true);
                }
              },
            ),
    );
  }

  Widget _buildSessionsTab(BuildContext context, AgenteState agenteState) {
    final sessions = agenteState.sessions;

    if (sessions.isEmpty) {
      return const OrtizEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No hay conversaciones guardadas',
        message: 'Inicia una nueva charla para interactuar con tu asistente.',
      );
    }

    // Filas sin tarjeta; la charla activa va sobre `surfaceHigh`.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.lg, _fabClearance),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = agenteState.currentSession?.id == session.id;

        return OrtizListRow(
          selected: isSelected,
          leading: Container(
            width: OrtizSize.minTouch - OrtizSpace.sm,
            height: OrtizSize.minTouch - OrtizSpace.sm,
            decoration: BoxDecoration(
              color: isSelected ? AgenteColors.primary : AgenteColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: OrtizIconSize.md,
              color: isSelected ? OrtizPalette.onAccent : AgenteColors.primary,
            ),
          ),
          title: session.title,
          subtitle: '${session.messageCount} mensajes • ${_formatDate(session.updatedAt)}',
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
            tooltip: 'Opciones de la charla',
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
                    Icon(Icons.delete_outline_rounded, size: OrtizIconSize.md, color: OrtizPalette.bad),
                    SizedBox(width: OrtizSpace.sm),
                    Text('Eliminar charla', style: TextStyle(color: OrtizPalette.bad)),
                  ],
                ),
              ),
            ],
          ),
          onTap: () async {
            await agenteState.selectSession(session.id);
            if (context.mounted) {
              AgenteChatBottomSheet.show(context, autoFocus: false);
            }
          },
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
          padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
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
              ? const OrtizEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No hay artefactos generados',
                  message: 'Los cálculos y tablas generados en el chat aparecerán aquí.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.lg, OrtizSpace.lg, _fabClearance),
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
      padding: const EdgeInsets.only(right: OrtizSpace.sm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterType = type),
        selectedColor: AgenteColors.primaryLight,
        checkmarkColor: AgenteColors.primary,
        labelStyle: TextStyle(
          fontSize: OrtizFontSize.caption,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AgenteColors.primaryDark : OrtizPalette.fg,
        ),
        backgroundColor: OrtizPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
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

  Widget _buildPromptsTab(BuildContext context, AgenteState agenteState) {
    final prompts = agenteState.quickPrompts;

    if (prompts.isEmpty) {
      return OrtizEmptyState(
        icon: Icons.bolt_rounded,
        title: 'Sin Prompts Rápidos',
        message:
            'Los prompts que crees aquí aparecerán directamente en la barra flotante del launcher para consultar con un solo toque.',
        action: ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: OrtizIconSize.md),
          label: const Text('Crear Primer Prompt', style: TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AgenteColors.primary,
            foregroundColor: OrtizPalette.onAccent,
            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
          ),
          onPressed: () async {
            final newPrompt = await PromptEditorDialog.show(context);
            if (newPrompt != null) {
              agenteState.saveQuickPrompt(newPrompt);
            }
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner explicativo
        Container(
          margin: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.md, OrtizSpace.lg, OrtizSpace.sm),
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
          decoration: BoxDecoration(
            color: AgenteColors.primaryLight,
            borderRadius: BorderRadius.circular(OrtizRadius.field),
            border: Border.all(color: AgenteColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: OrtizIconSize.md, color: AgenteColors.primary),
              const SizedBox(width: OrtizSpace.sm),
              Expanded(
                child: Text(
                  'Estos ${prompts.length} prompts se muestran en la barra inferior del launcher para consultas instantáneas.',
                  style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: AgenteColors.primaryDark, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Lista de prompts reordenables
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, OrtizSpace.xs, OrtizSpace.lg, _fabClearance),
            itemCount: prompts.length,
            onReorder: (oldIndex, newIndex) {
              agenteState.reorderQuickPrompts(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              // Fila sin tarjeta, separada por una línea fina (`line`).
              return DecoratedBox(
                key: ValueKey(prompt.id),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: OrtizPalette.line, width: OrtizStroke.hairline)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(OrtizSpace.md, OrtizSpace.sm, OrtizSpace.sm, OrtizSpace.sm),
                  leading: Container(
                    width: OrtizIconSize.xl + OrtizSpace.xs,
                    height: OrtizIconSize.xl + OrtizSpace.xs,
                    decoration: BoxDecoration(
                      color: OrtizPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          fontWeight: FontWeight.w900,
                          color: OrtizPalette.muted,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    prompt.text,
                    style: const TextStyle(
                      fontSize: OrtizFontSize.body,
                      fontWeight: FontWeight.w700,
                      color: OrtizPalette.fg,
                    ),
                  ),
                  subtitle: prompt.label != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: OrtizSpace.xs),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                              decoration: BoxDecoration(
                                color: AgenteColors.primaryLight,
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              child: Text(
                                prompt.label!,
                                style: const TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  fontWeight: FontWeight.w800,
                                  color: AgenteColors.primary,
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón Probar
                      IconButton(
                        icon: const Icon(Icons.play_arrow_rounded, color: AgenteColors.primary, size: OrtizIconSize.lg),
                        tooltip: 'Probar en chat',
                        onPressed: () {
                          AgenteChatBottomSheet.show(context, initialPrompt: prompt.text);
                        },
                      ),
                      // Menú de opciones (Editar / Borrar)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final edited = await PromptEditorDialog.show(context, prompt: prompt);
                            if (edited != null) {
                              agenteState.saveQuickPrompt(edited);
                            }
                          } else if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
                                title: const Text('¿Eliminar prompt?', style: TextStyle(fontWeight: FontWeight.w900)),
                                content: Text('Se eliminará "${prompt.text}" de los accesos rápidos del launcher.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    style: TextButton.styleFrom(foregroundColor: OrtizPalette.bad),
                                    child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              agenteState.deleteQuickPrompt(prompt.id);
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
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
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: OrtizIconSize.sm, color: OrtizPalette.bad),
                                SizedBox(width: OrtizSpace.sm),
                                Text('Eliminar', style: TextStyle(color: OrtizPalette.bad)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.drag_indicator_rounded, color: OrtizPalette.muted, size: OrtizIconSize.md),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
