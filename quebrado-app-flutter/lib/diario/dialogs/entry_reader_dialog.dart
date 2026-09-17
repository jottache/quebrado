import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diario_entry.dart';
import '../models/diario_contact.dart';
import '../models/diario_template.dart';
import '../models/diario_category.dart';
import '../viewmodels/diario_state.dart';
import '../theme/diario_colors.dart';
import '../widgets/diario_image_helper.dart';
import '../screens/entry_editor_dialog.dart';

/// Abre el visor de nota en modo lectura:
/// - En desktop: un Dialog centrado elegante.
/// - En mobile: un ModalBottomSheet al 90% del alto de la pantalla.
Future<void> openEntryReader(BuildContext context, DiarioEntry entry) async {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= 768;

  if (isDesktop) {
    await showDialog(
      context: context,
      builder: (context) => EntryReaderDialog(entry: entry, isBottomSheet: false),
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.90,
        child: EntryReaderDialog(entry: entry, isBottomSheet: true),
      ),
    );
  }
}

class EntryReaderDialog extends StatelessWidget {
  final DiarioEntry entry;
  final bool isBottomSheet;

  const EntryReaderDialog({
    super.key,
    required this.entry,
    this.isBottomSheet = false,
  });

  String _formatDateTime(DateTime dt) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final day = dt.day;
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day de $month, $year • $hour:$minute $period';
  }

  void _openEditor(BuildContext context, DiarioState state) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => EntryEditorDialog(
        contactId: entry.contactId,
        categoryId: entry.categoryId,
        entry: entry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DiarioState>(context);
    // Intentar obtener la versión más reciente del entry si el estado cambió
    final currentEntry = state.entries.firstWhere(
      (e) => e.id == entry.id,
      orElse: () => entry,
    );

    final isPersonal = currentEntry.isPersonal || currentEntry.contactId == 'personal';
    final contact = isPersonal ? null : state.getContactById(currentEntry.contactId);
    final category = state.getCategoryById(currentEntry.categoryId);
    final template = currentEntry.templateId != null
        ? state.getTemplateById(currentEntry.templateId!)
        : null;

    final contentWidget = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle for bottom sheet
          if (isBottomSheet) ...[
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Top Navigation & Actions Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
            child: Row(
              children: [
                // Contact / Personal Badge
                if (isPersonal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F6F5F).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF1F6F5F)),
                        SizedBox(width: 6),
                        Text(
                          'Personal',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF1F6F5F),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (contact != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: DiarioColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          contact.initials,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: DiarioColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          contact.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: DiarioColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(width: 8),

                // Category or Template Badge
                if (template != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: template.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(template.iconData, size: 13, color: template.color),
                        const SizedBox(width: 4),
                        Text(
                          template.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: template.color,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (category != null && category.name != 'Notas Personales')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DiarioColors.surfaceHover,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: DiarioColors.textSecondary,
                      ),
                    ),
                  ),

                if (currentEntry.isPinned) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded, size: 12, color: DiarioColors.primary),
                        SizedBox(width: 3),
                        Text(
                          'Fijada',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: DiarioColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: DiarioColors.textSecondary),
                  tooltip: 'Editar esta nota',
                  onPressed: () => _openEditor(context, state),
                ),

                // Close Button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: DiarioColors.textMuted),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: DiarioColors.cardBorder),

          // Scrollable Reading Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timestamp
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: DiarioColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateTime(currentEntry.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: DiarioColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Title (if present)
                  if (currentEntry.hasTitle) ...[
                    Text(
                      currentEntry.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: DiarioColors.textPrimary,
                        letterSpacing: -0.4,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Photo attachment (if present)
                  if (currentEntry.hasPhoto) ...[
                    GestureDetector(
                      onTap: () {
                        DiarioImageHelper.openFullScreenImage(
                          context,
                          currentEntry.photoUrl!,
                          title: currentEntry.hasTitle ? currentEntry.title : 'Imagen adjunta',
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 380),
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: DiarioColors.cardBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: [
                            DiarioImageHelper.buildImageWidget(
                              currentEntry.photoUrl!,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Structured Template Fields (if present)
                  if (currentEntry.contentData != null && currentEntry.contentData!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DiarioColors.surfaceHover,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DiarioColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 16, color: DiarioColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'Datos Estructurados',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: DiarioColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...currentEntry.contentData!.entries.map((entryField) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 130,
                                    child: Text(
                                      '${entryField.key}:',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: DiarioColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${entryField.value}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: DiarioColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  // Main Content Text (Reading Mode)
                  if (currentEntry.contentText != null && currentEntry.contentText!.trim().isNotEmpty) ...[
                    SelectableText(
                      currentEntry.contentText!,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.65,
                        color: DiarioColors.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ] else if (!currentEntry.hasTitle && !currentEntry.hasPhoto && (currentEntry.contentData == null || currentEntry.contentData!.isEmpty)) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Nota sin contenido de texto adicional.',
                          style: TextStyle(color: DiarioColors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isBottomSheet) {
      return contentWidget;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: contentWidget,
      ),
    );
  }
}
