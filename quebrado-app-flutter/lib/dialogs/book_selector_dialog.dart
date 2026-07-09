import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../widgets/claymorphic_card.dart';

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Nueva Contabilidad",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.cardText),
        ),
        content: TextField(
          controller: _textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Ej. Mi Negocio, Finanzas Compartidas",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          style: const TextStyle(color: AppColors.cardText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context); // Close input dialog
                
                // Show loader while switching
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
                
                await appState.createProfile(name);
                
                if (mounted) {
                  Navigator.pop(context); // Remove loader
                  Navigator.pop(context); // Close bottom sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Libro '$name' creado y seleccionado."),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Crear", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenameBookDialog(BuildContext context, AppState appState, String profileId, String currentName) {
    _textController.text = currentName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Renombrar Contabilidad",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.cardText),
        ),
        content: TextField(
          controller: _textController,
          autofocus: true,
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          style: const TextStyle(color: AppColors.cardText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _textController.text.trim();
              if (newName.isNotEmpty) {
                await appState.renameProfile(profileId, newName);
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBook(BuildContext context, AppState appState, String profileId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "¿Eliminar Contabilidad?",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense),
        ),
        content: Text(
          "¿Estás seguro de que deseas eliminar el libro '$name'? Se borrarán de forma PERMANENTE todas sus cuentas, transacciones y configuraciones registradas. Esta acción no se puede deshacer.",
          style: const TextStyle(color: AppColors.cardText, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirm dialog
              
              // Show loader
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
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
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
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
            const SizedBox(height: 8),
            const Text(
              "Cada libro funciona de forma aislada. Puedes tener un libro para tus finanzas personales y otro independiente para los gastos de tu negocio.",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cardSubtitleText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            
            // List of books
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: appState.profiles.length,
                itemBuilder: (context, index) {
                  final profile = appState.profiles[index];
                  final profileId = profile['id']!;
                  final profileName = profile['name']!;
                  final isActive = appState.activeDbName == profileId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: isActive
                          ? null
                          : () async {
                              // Switch active database
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              );
                              
                              await appState.switchProfile(profileId);
                              
                              if (mounted) {
                                Navigator.pop(context); // Remove loader
                                Navigator.pop(context); // Close bottom sheet
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Cargada contabilidad: $profileName"),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
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
                            const SizedBox(width: 12),
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
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.grey),
                                onPressed: () => _showRenameBookDialog(context, appState, profileId, profileName),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
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
            
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showCreateBookDialog(context, appState),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: const Text(
                "Crear nueva contabilidad",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
