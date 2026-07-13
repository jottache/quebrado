import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  style: TextStyle(color: AppColors.cardText),
                ),
                const SizedBox(height: 16),
                Text("Color Principal", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.cardText)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                        child: isSelected ? Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
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
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Libro '$name' creado."), backgroundColor: AppColors.primary),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("Crear", style: TextStyle(color: Colors.white)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                const SizedBox(height: 16),
                Text("Color Principal", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.cardText)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                        child: isSelected ? Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("Guardar", style: TextStyle(color: Colors.white)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "¿Eliminar Contabilidad?",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense),
        ),
        content: Text(
          "¿Estás seguro de que deseas eliminar el libro '$name'? Se borrarán de forma PERMANENTE todas sus cuentas, transacciones y configuraciones registradas. Esta acción no se puede deshacer.",
          style: TextStyle(color: AppColors.cardText, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text("Eliminar", style: TextStyle(color: Colors.white)),
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
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.all(20),
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Libros de Contabilidad",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Cada libro funciona de forma aislada. Puedes tener un libro para tus finanzas personales y otro independiente para los gastos de tu negocio.",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cardSubtitleText,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            
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

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: isActive
                          ? null
                          : () async {
                              // Switch active database
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              );
                              
                              await appState.switchProfile(profileId);
                              appState.setTabIndex(0); // Volver al dashboard
                              
                              if (mounted) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Cargada contabilidad: $profileName"),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              }
                            },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive ? AppColors.primary : AppColors.cardBorderColor,
                            width: isActive ? 2.0 : AppColors.cardBorderWidth,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isActive ? AppColors.primary : Colors.grey,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                profileName,
                                style: TextStyle(
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  color: AppColors.cardText,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (profileId != 'quebrado.db') ...[
                              Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
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
                                          : const Color(0xFF1F6F5F),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_rounded, size: 18, color: Colors.grey),
                                onPressed: () => _showRenameBookDialog(context, appState, profileId, profileName, profileColor),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
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
            
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showCreateBookDialog(context, appState),
              icon: Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: Text(
                "Crear nueva contabilidad",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
