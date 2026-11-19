import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/role_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';

class RoleManagerDialog extends StatefulWidget {
  const RoleManagerDialog({super.key});

  @override
  State<RoleManagerDialog> createState() => _RoleManagerDialogState();
}

class _RoleManagerDialogState extends State<RoleManagerDialog> {
  final _uuid = const Uuid();

  final List<String> _availableIcons = [
    'favorite',
    'work',
    'people',
    'account_balance_wallet',
    'fitness_center',
    'school',
    'spa',
    'brush',
    'home',
    'travel_explore',
    'psychology',
    'music_note',
  ];

  final List<String> _availableColors = [
    '#3B82F6', // Blue
    '#10B981', // Emerald
    '#8B5CF6', // Purple
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#EC4899', // Pink
    '#14B8A6', // Teal
    '#6366F1', // Indigo
  ];

  void _showEditRoleSheet(BuildContext context, {RoleModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final purposeCtrl = TextEditingController(text: existing?.purposeStatement ?? '');
    String selectedIcon = existing?.iconName ?? _availableIcons.first;
    String selectedColor = existing?.colorHex ?? _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return AlertDialog(
            title: Text(
              existing == null ? 'Nuevo Rol Vital' : 'Editar Rol Vital',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.title),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nombre del Rol (ej. "Salud y Bienestar", "Líder de Proyecto")',
                      style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: RemindersColors.textSecondary),
                    ),
                    const SizedBox(height: OrtizSpace.xs),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nombre del rol',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                      ),
                    ),
                    const SizedBox(height: OrtizSpace.lg),
                    const Text(
                      'Declaración de Propósito / Misión de este Rol',
                      style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: RemindersColors.textSecondary),
                    ),
                    const SizedBox(height: OrtizSpace.xs),
                    const Text(
                      '¿Qué significa el éxito y la plenitud en esta dimensión?',
                      style: TextStyle(fontSize: OrtizFontSize.caption, color: RemindersColors.textMuted),
                    ),
                    const SizedBox(height: OrtizSpace.xs),
                    TextField(
                      controller: purposeCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'ej. Mantener energía física y paz mental para rendir al máximo...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                      ),
                    ),
                    const SizedBox(height: OrtizSpace.lg),
                    const Text(
                      'Ícono Representativo',
                      style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: RemindersColors.textSecondary),
                    ),
                    const SizedBox(height: OrtizSpace.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.map((iconName) {
                        final isSelected = selectedIcon == iconName;
                        final dummyRole = RoleModel(
                          id: '',
                          userId: '',
                          name: '',
                          iconName: iconName,
                          orderIndex: 0,
                        );
                        return InkWell(
                          onTap: () => setSheetState(() => selectedIcon = iconName),
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          child: Container(
                            padding: const EdgeInsets.all(OrtizSpace.sm),
                            decoration: BoxDecoration(
                              color: isSelected ? RemindersColors.primaryLight : OrtizPalette.surfaceHigh,
                              border: Border.all(
                                color: isSelected ? RemindersColors.primary : Colors.transparent,
                                width: OrtizStroke.focus,
                              ),
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                            ),
                            child: Icon(
                              dummyRole.iconData,
                              size: OrtizIconSize.md,
                              color: isSelected ? RemindersColors.primary : RemindersColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: OrtizSpace.lg),
                    const Text(
                      'Color de Identificación',
                      style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: RemindersColors.textSecondary),
                    ),
                    const SizedBox(height: OrtizSpace.sm),
                    Wrap(
                      spacing: 10,
                      children: _availableColors.map((hex) {
                        final isSelected = selectedColor == hex;
                        final color = RoleModel.parseColorHex(hex);
                        return InkWell(
                          onTap: () => setSheetState(() => selectedColor = hex),
                          borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? OrtizPalette.fg : Colors.transparent,
                                width: OrtizStroke.focus,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: OrtizIconSize.sm, color: OrtizPalette.onAccent)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final state = Provider.of<RemindersState>(context, listen: false);
                  final role = RoleModel(
                    id: existing?.id ?? _uuid.v4(),
                    userId: existing?.userId ?? '',
                    name: name,
                    purposeStatement: purposeCtrl.text.trim().isNotEmpty ? purposeCtrl.text.trim() : null,
                    iconName: selectedIcon,
                    colorHex: selectedColor,
                    orderIndex: existing?.orderIndex ?? state.roles.length,
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  );

                  state.saveRole(role);
                  Navigator.pop(ctx);
                },
                child: const Text('Guardar Rol'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<RemindersState>(context);
    final roles = state.roles;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(OrtizSpace.sm),
                        decoration: BoxDecoration(
                          color: RemindersColors.primaryLight,
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        ),
                        child: const Icon(Icons.pie_chart_outline, color: RemindersColors.primary),
                      ),
                      const SizedBox(width: OrtizSpace.md),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Roles de Vida (Brújula)',
                            style: TextStyle(fontSize: OrtizFontSize.title, fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                          ),
                          Text(
                            'Los 7 Hábitos: Equilibrio vital y liderazgo personal',
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: OrtizSpace.lg),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: OrtizSpace.xs),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: OrtizIconSize.md, color: RemindersColors.primary),
                    SizedBox(width: OrtizSpace.sm),
                    Expanded(
                      child: Text(
                        'Stephen Covey enseña que no podemos ser exitosos en el trabajo si descuidamos la salud o la familia. Cada semana debes nutrir cada uno de tus roles.',
                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textSecondary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: OrtizSpace.lg),
              Expanded(
                child: roles.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay roles configurados aún.',
                          style: TextStyle(color: RemindersColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: roles.length,
                        // Filas sin tarjeta, separadas por una línea fina.
                        separatorBuilder: (_, __) => const Divider(height: OrtizStroke.hairline),
                        itemBuilder: (context, index) {
                          final role = roles[index];
                          final count = state.countBigRocksForRole(role.id);
                          final hasRock = count > 0;
                          final rockColor = hasRock ? RemindersColors.completed : RemindersColors.snoozed;

                          return Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: role.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                ),
                                child: Icon(role.iconData, color: role.color, size: OrtizIconSize.lg),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    role.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.body),
                                  ),
                                  const SizedBox(width: OrtizSpace.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                                    decoration: BoxDecoration(
                                      color: rockColor.withValues(alpha: SuiteAppColors.tintAlpha / 0xFF),
                                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hasRock ? Icons.star : Icons.warning_amber_rounded,
                                          size: OrtizIconSize.xs,
                                          color: rockColor,
                                        ),
                                        const SizedBox(width: OrtizSpace.xs),
                                        Text(
                                          hasRock ? '$count Gran Roca' : '0 Rocas (Desatendido)',
                                          style: TextStyle(
                                            fontSize: OrtizFontSize.caption,
                                            fontWeight: FontWeight.bold,
                                            color: rockColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: role.purposeStatement != null && role.purposeStatement!.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: OrtizSpace.xs),
                                      child: Text(
                                        role.purposeStatement!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textSecondary, fontStyle: FontStyle.italic),
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: OrtizIconSize.md, color: RemindersColors.textSecondary),
                                    onPressed: () => _showEditRoleSheet(context, existing: role),
                                    tooltip: 'Editar rol',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: OrtizIconSize.md, color: RemindersColors.overdue),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Eliminar Rol'),
                                          content: Text('¿Seguro que deseas eliminar el rol "${role.name}"? Los recordatorios asociados no se eliminarán.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(c),
                                              child: const Text('Cancelar'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: OrtizPalette.bad,
                                                foregroundColor: OrtizPalette.onAccent,
                                              ),
                                              onPressed: () {
                                                state.deleteRole(role.id);
                                                Navigator.pop(c);
                                              },
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    tooltip: 'Eliminar rol',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: OrtizSpace.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${roles.length} roles configurados',
                    style: const TextStyle(fontSize: OrtizFontSize.bodySm, color: RemindersColors.textMuted),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showEditRoleSheet(context),
                    icon: const Icon(Icons.add, size: OrtizIconSize.md),
                    label: const Text('Agregar Rol'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
