import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/role_model.dart';
import '../theme/reminders_colors.dart';
import '../viewmodels/reminders_state.dart';

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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RemindersColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nombre del rol',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Declaración de Propósito / Misión de este Rol',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RemindersColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '¿Qué significa el éxito y la plenitud en esta dimensión?',
                      style: TextStyle(fontSize: 11, color: RemindersColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: purposeCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'ej. Mantener energía física y paz mental para rendir al máximo...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ícono Representativo',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RemindersColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
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
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? RemindersColors.primaryLight : Colors.grey.shade100,
                              border: Border.all(
                                color: isSelected ? RemindersColors.primary : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              dummyRole.iconData,
                              size: 20,
                              color: isSelected ? RemindersColors.primary : Colors.grey.shade700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Color de Identificación',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RemindersColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: _availableColors.map((hex) {
                        final isSelected = selectedColor == hex;
                        final color = RoleModel.parseColorHex(hex);
                        return InkWell(
                          onTap: () => setSheetState(() => selectedColor = hex),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black87 : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: RemindersColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pie_chart_outline, color: RemindersColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Roles de Vida (Brújula)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: RemindersColors.textPrimary),
                          ),
                          Text(
                            'Los 7 Hábitos: Equilibrio vital y liderazgo personal',
                            style: TextStyle(fontSize: 12, color: RemindersColors.textMuted),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 20, color: RemindersColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Stephen Covey enseña que no podemos ser exitosos en el trabajo si descuidamos la salud o la familia. Cada semana debes nutrir cada uno de tus roles.',
                        style: TextStyle(fontSize: 12, color: RemindersColors.textSecondary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final role = roles[index];
                          final count = state.countBigRocksForRole(role.id);
                          final hasRock = count > 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: role.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(role.iconData, color: role.color, size: 22),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    role.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: hasRock ? Colors.green.shade50 : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: hasRock ? Colors.green.shade300 : Colors.amber.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hasRock ? Icons.star : Icons.warning_amber_rounded,
                                          size: 12,
                                          color: hasRock ? Colors.green.shade700 : Colors.amber.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasRock ? '$count Gran Roca' : '0 Rocas (Desatendido)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: hasRock ? Colors.green.shade800 : Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: role.purposeStatement != null && role.purposeStatement!.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        role.purposeStatement!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: RemindersColors.textSecondary),
                                    onPressed: () => _showEditRoleSheet(context, existing: role),
                                    tooltip: 'Editar rol',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
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
                                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${roles.length} roles configurados',
                    style: const TextStyle(fontSize: 12, color: RemindersColors.textMuted),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showEditRoleSheet(context),
                    icon: const Icon(Icons.add, size: 18),
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
