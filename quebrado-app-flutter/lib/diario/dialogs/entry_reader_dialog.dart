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
import '../widgets/mention_text_field.dart';
import '../../rich_editor/plain_text.dart';
import '../../rich_editor/rich_document_viewer.dart';
import '../../notas/notas.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

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
    final allMentionIds = <String>{};
    if (currentEntry.contentText != null && currentEntry.contentText!.isNotEmpty) {
      allMentionIds.addAll(state.extractMentionedContactIds(currentEntry.contentText!));
      for (final id in currentEntry.mentionedContactIds) {
        final c = state.getContactById(id);
        if (c != null && state.isContactMentionedInText(c, currentEntry.contentText!)) {
          allMentionIds.add(id);
        }
      }
    } else {
      allMentionIds.addAll(currentEntry.mentionedContactIds);
    }
    final mentionedContacts = allMentionIds
        .map((id) => state.getContactById(id))
        .whereType<DiarioContact>()
        .toList();

    final contentWidget = Container(
      decoration: BoxDecoration(
        color: OrtizPalette.surface,
        borderRadius: isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet))
            : BorderRadius.circular(OrtizRadius.sheet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle for bottom sheet
          if (isBottomSheet) ...[
            const SizedBox(height: OrtizSpace.md),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: OrtizPalette.line,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
              ),
            ),
            const SizedBox(height: OrtizSpace.xs),
          ],

          // Top Navigation & Actions Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(OrtizSpace.xl, OrtizSpace.md, OrtizSpace.md, OrtizSpace.sm),
            child: Row(
              children: [
                // Contact / Personal Badge
                if (isPersonal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_pin_rounded, size: OrtizIconSize.sm, color: DiarioColors.primary),
                        SizedBox(width: OrtizSpace.xs),
                        Text(
                          'Personal',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: OrtizFontSize.bodySm,
                            color: DiarioColors.primary,
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
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.w900,
                            color: DiarioColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: OrtizSpace.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          contact.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: OrtizFontSize.bodySm,
                            color: DiarioColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(width: OrtizSpace.sm),

                // Category or Template Badge
                if (template != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                    decoration: BoxDecoration(
                      color: template.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(template.iconData, size: OrtizIconSize.xs, color: template.color),
                        const SizedBox(width: OrtizSpace.xs),
                        Text(
                          template.name,
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
                            fontWeight: FontWeight.w700,
                            color: template.color,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (category != null && category.name != 'Notas Personales')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                    decoration: BoxDecoration(
                      color: DiarioColors.surfaceHover,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      border: Border.all(color: OrtizPalette.line),
                    ),
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: OrtizFontSize.caption,
                        fontWeight: FontWeight.w600,
                        color: DiarioColors.textSecondary,
                      ),
                    ),
                  ),

                if (currentEntry.isPinned) ...[
                  const SizedBox(width: OrtizSpace.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                    decoration: BoxDecoration(
                      color: DiarioColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded, size: OrtizIconSize.xs, color: DiarioColors.primary),
                        SizedBox(width: OrtizSpace.xxs),
                        Text(
                          'Fijada',
                          style: TextStyle(
                            fontSize: OrtizFontSize.caption,
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
                  icon: const Icon(Icons.edit_outlined, size: OrtizIconSize.md, color: DiarioColors.textSecondary),
                  tooltip: 'Editar esta nota',
                  onPressed: () => _openEditor(context, state),
                ),

                // Close Button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: OrtizIconSize.lg, color: DiarioColors.textMuted),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: DiarioColors.cardBorder),

          // Scrollable Reading Content
          Expanded(
            child: Builder(builder: (context) {
              final top = <Widget>[
                  // Timestamp
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: OrtizIconSize.xs, color: DiarioColors.textMuted),
                      const SizedBox(width: OrtizSpace.xs),
                      Text(
                        _formatDateTime(currentEntry.createdAt),
                        style: const TextStyle(
                          fontSize: OrtizFontSize.bodySm,
                          color: DiarioColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: OrtizSpace.md),

                  // Title (if present)
                  if (currentEntry.hasTitle) ...[
                    Text(
                      currentEntry.title,
                      style: const TextStyle(
                        fontSize: OrtizFontSize.display,
                        fontWeight: FontWeight.w900,
                        color: DiarioColors.textPrimary,
                        letterSpacing: -0.4,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: OrtizSpace.lg),
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
                        margin: const EdgeInsets.only(bottom: OrtizSpace.xl),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(OrtizRadius.block),
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
                                padding: const EdgeInsets.all(OrtizSpace.xs),
                                decoration: BoxDecoration(
                                  color: OrtizPalette.bg.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.fullscreen_rounded, color: OrtizPalette.fg, size: OrtizIconSize.md),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Structured Template Fields (if present)
                  if (currentEntry.contentData != null && currentEntry.contentData!.isNotEmpty) ...[
                    // Sin tarjeta (spec 05): grupo separado por espacio.
                    Padding(
                      padding: const EdgeInsets.only(bottom: OrtizSpace.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune_rounded, size: OrtizIconSize.sm, color: DiarioColors.primary),
                              SizedBox(width: OrtizSpace.xs),
                              Text(
                                'Datos Estructurados',
                                style: TextStyle(
                                  fontSize: OrtizFontSize.bodySm,
                                  fontWeight: FontWeight.w800,
                                  color: DiarioColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: OrtizSpace.md),
                          ...currentEntry.contentData!.entries.map((entryField) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 130,
                                    child: Text(
                                      '${entryField.key}:',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: OrtizFontSize.bodySm,
                                        color: DiarioColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${entryField.value}',
                                      style: const TextStyle(
                                        fontSize: OrtizFontSize.bodySm,
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

                  // Mentioned Contacts Bar
                  if (mentionedContacts.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: OrtizSpace.lg),
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                      decoration: BoxDecoration(
                        color: DiarioColors.primaryLight,
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                        border: Border.all(color: DiarioColors.primaryBorder),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.alternate_email_rounded, size: OrtizIconSize.xs, color: DiarioColors.primary),
                              SizedBox(width: OrtizSpace.xs),
                              Text(
                                'Mencionados:',
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  fontWeight: FontWeight.w800,
                                  color: DiarioColors.primary,
                                ),
                              ),
                            ],
                          ),
                          ...mentionedContacts.map((c) => ActionChip(
                                avatar: CircleAvatar(
                                  backgroundColor: DiarioColors.primary,
                                  child: Text(
                                    c.initials,
                                    style: const TextStyle(fontSize: OrtizFontSize.micro, color: OrtizPalette.onAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                label: Text(
                                  c.name,
                                  style: const TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.w700, color: DiarioColors.primary),
                                ),
                                backgroundColor: OrtizPalette.surface,
                                side: const BorderSide(color: DiarioColors.primaryBorder),
                                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: 0),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  state.selectContact(c.id);
                                },
                              )),
                        ],
                      ),
                    ),
                  ],

              ];

              // Documento enriquecido (entradas escritas con el editor nuevo): el visor
              // es el scroll y los datos de la entrada van como encabezado.
              if (currentEntry.hasRichDocument) {
                return RichDocumentViewer(
                  document: currentEntry.richDocument!,
                  accentColor: DiarioColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl),
                  header: Padding(
                    padding: const EdgeInsets.fromLTRB(OrtizSpace.xxl, OrtizSpace.xl, OrtizSpace.xxl, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: top),
                  ),
                  footer: const SizedBox(height: OrtizSpace.xxxl),
                  onTodoToggled: (document) => state.updateEntry(
                    currentEntry.copyWith(
                      richDocument: document.toJson(),
                      contentText: documentToPlainText(document),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(OrtizSpace.xxl, OrtizSpace.xl, OrtizSpace.xxl, OrtizSpace.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...top,
                  // Main Content Text (Reading Mode con menciones interactivas)
                  if (currentEntry.contentText != null && currentEntry.contentText!.trim().isNotEmpty) ...[
                    Text.rich(
                      TextSpan(
                        children: MentionTextSpanHelper.buildSpans(
                          text: currentEntry.contentText!,
                          contacts: state.contacts,
                          notes: Provider.of<NotasState>(context, listen: false).notes,
                          baseStyle: const TextStyle(
                            fontSize: OrtizFontSize.titleSm,
                            height: 1.65,
                            color: DiarioColors.textPrimary,
                            letterSpacing: 0.1,
                          ),
                          onContactTap: (clickedContact) {
                            Navigator.of(context).pop();
                            state.selectContact(clickedContact.id);
                          },
                          onNoteTap: (clickedNote) {
                            NoteReaderDialog.show(context, note: clickedNote);
                          },
                        ),
                      ),
                    ),
                  ] else if (!currentEntry.hasTitle && !currentEntry.hasPhoto && (currentEntry.contentData == null || currentEntry.contentData!.isEmpty)) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(OrtizSpace.xxxl),
                        child: Text(
                          'Nota sin contenido de texto adicional.',
                          style: TextStyle(color: DiarioColors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                  ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );

    if (isBottomSheet) {
      return contentWidget;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.sheet)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl, vertical: OrtizSpace.xxxl),
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
