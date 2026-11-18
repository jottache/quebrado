import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class BookSelectorBottomSheet extends StatefulWidget {
  const BookSelectorBottomSheet({super.key});

  @override
  State<BookSelectorBottomSheet> createState() => _BookSelectorBottomSheetState();
}

class _BookSelectorBottomSheetState extends State<BookSelectorBottomSheet> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showCreateBookDialog(BuildContext context, AppState appState) {
    _textController.clear();
    String selectedColor = AppColors.creationColors[0];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
            title: Text(
              "Nueva Contabilidad",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.cardText),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Ej. Mi Negocio",
                    hintStyle: const TextStyle(color: OrtizPalette.muted),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  style: TextStyle(color: AppColors.cardText),
                ),
                const SizedBox(height: OrtizSpace.lg),
                Text("Color Principal", style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: AppColors.cardText)),
                const SizedBox(height: OrtizSpace.sm),
                Wrap(
                  spacing: OrtizSpace.sm,
                  runSpacing: OrtizSpace.sm,
                  children: AppColors.creationColors.map((colorHex) {
                    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    final isSelected = selectedColor == colorHex;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = colorHex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: AppColors.cardText, width: 2) : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: OrtizPalette.onAccent, size: OrtizIconSize.sm)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar", style: TextStyle(color: OrtizPalette.muted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = _textController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(context); // Close input dialog
                    
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    );
                    
                    await appState.createProfile(name, selectedColor);
                    appState.setTabIndex(0);
                    
                    if (mounted) {
                      Navigator.pop(context); // Close loading dialog
                      Navigator.pop(context); // Close bottom sheet
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Libro '$name' creado."), backgroundColor: AppColors.primary),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                ),
                child: const Text("Crear", style: TextStyle(color: OrtizPalette.onAccent)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRenameBookDialog(BuildContext context, AppState appState, String profileId, String currentName, String currentColor) {
    _textController.text = currentName;
    String selectedColor = currentColor.isNotEmpty ? currentColor : AppColors.creationColors[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
            title: Text(
              "Editar Contabilidad",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.cardText),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  style: TextStyle(color: AppColors.cardText),
                ),
                const SizedBox(height: OrtizSpace.lg),
                Text("Color Principal", style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: AppColors.cardText)),
                const SizedBox(height: OrtizSpace.sm),
                Wrap(
                  spacing: OrtizSpace.sm,
                  runSpacing: OrtizSpace.sm,
                  children: AppColors.creationColors.map((colorHex) {
                    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    final isSelected = selectedColor == colorHex;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = colorHex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: AppColors.cardText, width: 2) : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: OrtizPalette.onAccent, size: OrtizIconSize.sm)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar", style: TextStyle(color: OrtizPalette.muted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = _textController.text.trim();
                  if (newName.isNotEmpty) {
                    await appState.updateProfile(profileId, newName, selectedColor);
                    if (mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                ),
                child: const Text("Guardar", style: TextStyle(color: OrtizPalette.onAccent)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmDeleteBook(BuildContext context, AppState appState, String profileId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
        title: Text(
          "¿Eliminar Contabilidad?",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense),
        ),
        content: Text(
          "¿Estás seguro de que deseas eliminar el libro '$name'? Se borrarán de forma PERMANENTE todas sus cuentas, transacciones y configuraciones registradas. Esta acción no se puede deshacer.",
          style: TextStyle(color: AppColors.cardText, fontSize: OrtizFontSize.bodySm, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: OrtizPalette.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirm dialog
              
              // Show loader
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
              
              await appState.deleteProfile(profileId);
              
              if (mounted) {
                Navigator.pop(context); // Remove loader
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Libro '$name' eliminado."),
                    backgroundColor: AppColors.expense,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
            ),
            child: const Text("Eliminar", style: TextStyle(color: OrtizPalette.onAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.sheet),
          topRight: Radius.circular(OrtizRadius.sheet),
        ),
      ),
      padding: EdgeInsets.all(OrtizSpace.xl),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: OrtizPalette.line,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
              ),
            ),
            const SizedBox(height: OrtizSpace.lg),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(OrtizSpace.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: OrtizIconSize.md,
                  ),
                ),
                SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    "Libros de Contabilidad",
                    style: TextStyle(
                      fontSize: OrtizFontSize.titleSm,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.sm),
            Text(
              "Cada libro funciona de forma aislada. Puedes tener un libro para tus finanzas personales y otro independiente para los gastos de tu negocio.",
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
                color: AppColors.cardSubtitleText,
                height: 1.4,
              ),
            ),
            SizedBox(height: OrtizSpace.lg),
            
            // List of books
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: appState.profiles.length,
                itemBuilder: (context, index) {
                  final profile = appState.profiles[index];
                  final profileId = profile['id']!;
                  final profileName = profile['name']!;
                  final profileColor = profile['color'] ?? '';
                  final isActive = appState.activeDbName == profileId;

                  // Fila sin tarjeta: el libro activo va sobre `surfaceHigh`.
                  return Padding(
                    padding: const EdgeInsets.only(bottom: OrtizSpace.xs),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      onTap: isActive
                          ? null
                          : () async {
                              await appState.switchProfile(profileId);
                              appState.setTabIndex(0); // Volver al dashboard
                              
                              if (mounted) {
                                Navigator.of(context, rootNavigator: true).pop(); // Close bottom sheet
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Cargada contabilidad: $profileName"),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              }
                            },
                      child: Ink(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.xs),
                        decoration: BoxDecoration(
                          color: isActive ? OrtizPalette.surfaceHigh : Colors.transparent,
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isActive ? AppColors.primary : OrtizPalette.muted,
                              size: OrtizIconSize.md,
                            ),
                            const SizedBox(width: OrtizSpace.md),
                            Expanded(
                              child: Text(
                                profileName,
                                style: TextStyle(
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  color: AppColors.cardText,
                                  fontSize: OrtizFontSize.body,
                                ),
                              ),
                            ),
                            if (profileId != 'quebrado.db') ...[
                              Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: profileColor.isNotEmpty 
                                          ? Color(int.parse(profileColor.replaceFirst('#', '0xFF'))) 
                                          : AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: "Editar",
                                icon: const Icon(Icons.edit_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
                                onPressed: () => _showRenameBookDialog(context, appState, profileId, profileName, profileColor),
                              ),
                              IconButton(
                                tooltip: "Eliminar",
                                icon: const Icon(Icons.delete_outline_rounded, size: OrtizIconSize.md, color: OrtizPalette.muted),
                                onPressed: () => _confirmDeleteBook(context, appState, profileId, profileName),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: OrtizSpace.lg),
            ElevatedButton.icon(
              onPressed: () => _showCreateBookDialog(context, appState),
              icon: const Icon(Icons.add_rounded, color: OrtizPalette.onAccent, size: OrtizIconSize.md),
              label: const Text(
                "Crear nueva contabilidad",
                style: TextStyle(color: OrtizPalette.onAccent, fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.block)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
