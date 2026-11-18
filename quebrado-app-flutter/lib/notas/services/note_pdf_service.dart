import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note_item.dart';
import '../models/note_category.dart';
import '../models/note_block.dart';

import '../theme/notas_colors.dart';
import '../theme/notas_pdf_palette.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
/// Servicio para la generación de documentos PDF de alta calidad,
/// exportación, descarga e intercambio de notas y acuerdos.
class NotePdfService {
  static final NotePdfService instance = NotePdfService._init();
  NotePdfService._init();

  /// Convierte una cadena hexadecimal a [PdfColor] de forma segura.
  static PdfColor parseHexColor(String? hex, {PdfColor fallback = PdfColors.indigo600}) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '');
      final val = int.parse('FF$clean', radix: 16);
      return PdfColor.fromInt(val);
    } catch (_) {
      return fallback;
    }
  }

  /// Limpia una cadena para que sea un nombre de archivo seguro.
  static String sanitizeFilename(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Carga la tipografía con soporte para caracteres especiales,
  /// recurriendo a fuentes del sistema en caso de desconexión.
  static Future<pw.ThemeData> _loadPdfTheme() async {
    pw.Font? regular;
    pw.Font? bold;
    pw.Font? italic;
    pw.Font? boldItalic;

    try {
      regular = await PdfGoogleFonts.robotoRegular();
      bold = await PdfGoogleFonts.robotoBold();
      italic = await PdfGoogleFonts.robotoItalic();
      boldItalic = await PdfGoogleFonts.robotoBoldItalic();
    } catch (_) {
      regular = pw.Font.helvetica();
      bold = pw.Font.helveticaBold();
      italic = pw.Font.helveticaOblique();
      boldItalic = pw.Font.helveticaBoldOblique();
    }

    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    );
  }

  /// Genera los bytes del documento PDF a partir de una [NoteItem].
  Future<Uint8List> generateNotePdf({
    required NoteItem note,
    NoteCategory? category,
  }) async {
    final pdf = pw.Document(
      title: note.title,
      author: 'OrtizApp',
      creator: 'OrtizApp Notas & Acuerdos',
    );

    final theme = await _loadPdfTheme();
    final primaryColor = parseHexColor(note.colorHex);
    final categoryColor = parseHexColor(category?.colorHex, fallback: primaryColor);

    final dateFormat = DateFormat('dd/MM/yyyy - HH:mm');
    final formattedCreated = dateFormat.format(note.createdAt);
    final formattedUpdated = dateFormat.format(note.updatedAt);

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: NotasPdfPalette.pageMargin,
          vertical: NotasPdfPalette.pageMargin,
        ),
        header: (pw.Context context) => _buildPdfHeader(
          note: note,
          category: category,
          primaryColor: primaryColor,
          categoryColor: categoryColor,
          createdDate: formattedCreated,
          updatedDate: formattedUpdated,
        ),
        footer: (pw.Context context) => _buildPdfFooter(context),
        build: (pw.Context context) => _buildPdfContent(note, primaryColor),
      ),
    );

    return pdf.save();
  }

  /// Construye la cabecera del documento PDF.
  pw.Widget _buildPdfHeader({
    required NoteItem note,
    required NoteCategory? category,
    required PdfColor primaryColor,
    required PdfColor categoryColor,
    required String createdDate,
    required String updatedDate,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: OrtizSpace.xl),
      padding: const pw.EdgeInsets.only(bottom: OrtizSpace.md),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Fila superior: Badge de Categoría + Tags
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (category != null)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                  decoration: pw.BoxDecoration(
                    color: categoryColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(OrtizRadius.chip)),
                  ),
                  child: pw.Text(
                    category.name.toUpperCase(),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: OrtizFontSize.micro,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (note.sharedTag != null && note.sharedTag!.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xxs),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(OrtizRadius.chip)),
                  ),
                  child: pw.Text(
                    '#${note.sharedTag}',
                    style: const pw.TextStyle(
                      color: PdfColors.grey700,
                      fontSize: OrtizFontSize.micro,
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: OrtizSpace.sm),

          // Título de la nota
          pw.Text(
            note.title.isNotEmpty ? note.title : 'Sin título',
            style: pw.TextStyle(
              fontSize: OrtizFontSize.display,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: OrtizSpace.sm),

          // Metadatos de fecha
          pw.Row(
            children: [
              pw.Text(
                'Creada: $createdDate',
                style: const pw.TextStyle(fontSize: OrtizFontSize.micro, color: PdfColors.grey600),
              ),
              pw.SizedBox(width: OrtizSpace.md),
              pw.Text(
                'Actualizada: $updatedDate',
                style: const pw.TextStyle(fontSize: OrtizFontSize.micro, color: PdfColors.grey600),
              ),
              if (note.isPinned) ...[
                pw.SizedBox(width: OrtizSpace.md),
                pw.Text(
                  '[Fijada]',
                  style: pw.TextStyle(
                    fontSize: OrtizFontSize.micro,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.amber800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Construye el pie de página con paginación y marca sutil.
  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: OrtizSpace.lg),
      padding: const pw.EdgeInsets.only(top: OrtizSpace.sm),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey200, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'OrtizApp | Notas & Acuerdos',
            style: const pw.TextStyle(fontSize: OrtizFontSize.micro, color: PdfColors.grey500),
          ),
          pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: OrtizFontSize.micro, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  /// Renderiza los bloques estructurados de la nota en widgets PDF.
  List<pw.Widget> _buildPdfContent(NoteItem note, PdfColor primaryColor) {
    final widgets = <pw.Widget>[];

    if (note.blocks.isEmpty) {
      final text = note.contentText ?? '';
      if (text.isNotEmpty) {
        widgets.add(
          pw.Text(
            text,
            style: const pw.TextStyle(fontSize: OrtizFontSize.caption, lineSpacing: 2, color: PdfColors.grey900),
          ),
        );
      } else {
        widgets.add(
          pw.Text(
            'Esta nota no contiene texto adicional.',
            style: pw.TextStyle(fontSize: OrtizFontSize.caption, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic),
          ),
        );
      }
      return widgets;
    }

    for (int i = 0; i < note.blocks.length; i++) {
      final block = note.blocks[i];
      widgets.add(_renderBlock(block, i, primaryColor));
    }

    return widgets;
  }

  /// Convierte un [NoteBlock] individual en un elemento visual PDF.
  pw.Widget _renderBlock(NoteBlock block, int index, PdfColor primaryColor) {
    switch (block.type) {
      case BlockType.heading1:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: OrtizSpace.lg, bottom: OrtizSpace.xs),
          child: pw.Text(
            block.content,
            style: pw.TextStyle(
              fontSize: OrtizFontSize.title,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
        );

      case BlockType.heading2:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: OrtizSpace.md, bottom: OrtizSpace.xs),
          child: pw.Text(
            block.content,
            style: pw.TextStyle(
              fontSize: OrtizFontSize.body,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
        );

      case BlockType.heading3:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: OrtizSpace.sm, bottom: OrtizSpace.xs),
          child: pw.Text(
            block.content,
            style: pw.TextStyle(
              fontSize: OrtizFontSize.bodySm,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey700,
            ),
          ),
        );

      case BlockType.paragraph:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: OrtizSpace.xs),
          child: pw.Text(
            block.content,
            style: const pw.TextStyle(
              fontSize: OrtizFontSize.caption,
              lineSpacing: 2,
              color: PdfColors.grey900,
            ),
          ),
        );

      case BlockType.todo:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: OrtizSpace.xxs),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 12,
                height: 12,
                margin: const pw.EdgeInsets.only(top: OrtizSpace.xxs, right: OrtizSpace.sm),
                decoration: pw.BoxDecoration(
                  color: block.isChecked ? primaryColor : PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(OrtizRadius.chip)),
                  border: pw.Border.all(
                    color: block.isChecked ? primaryColor : PdfColors.grey400,
                    width: 1.2,
                  ),
                ),
                child: block.isChecked
                    ? pw.Center(
                        child: pw.Text(
                          'X',
                          style: pw.TextStyle(
                            fontSize: OrtizFontSize.micro,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
              pw.Expanded(
                child: pw.Text(
                  block.content,
                  style: pw.TextStyle(
                    fontSize: OrtizFontSize.caption,
                    color: block.isChecked ? PdfColors.grey500 : PdfColors.grey900,
                    decoration: block.isChecked ? pw.TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        );

      case BlockType.bulletList:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: OrtizSpace.xxs),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 4,
                height: 4,
                margin: const pw.EdgeInsets.only(top: OrtizSpace.xs, left: OrtizSpace.xs, right: OrtizSpace.sm),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey700,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  block.content,
                  style: const pw.TextStyle(fontSize: OrtizFontSize.caption, color: PdfColors.grey900),
                ),
              ),
            ],
          ),
        );

      case BlockType.numberedList:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: OrtizSpace.xxs),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 20,
                child: pw.Text(
                  '${index + 1}.',
                  style: pw.TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  block.content,
                  style: const pw.TextStyle(fontSize: OrtizFontSize.caption, color: PdfColors.grey900),
                ),
              ),
            ],
          ),
        );

      case BlockType.toggle:
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: OrtizSpace.xs),
          padding: const pw.EdgeInsets.all(OrtizSpace.sm),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(OrtizRadius.chip)),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('v ', style: pw.TextStyle(fontSize: OrtizFontSize.micro, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                  pw.Expanded(
                    child: pw.Text(
                      block.content.isNotEmpty ? block.content : 'Desplegable',
                      style: pw.TextStyle(fontSize: OrtizFontSize.caption, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                    ),
                  ),
                ],
              ),
              if (block.children.isNotEmpty) ...[
                pw.SizedBox(height: OrtizSpace.xs),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: OrtizSpace.md),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: block.children
                        .asMap()
                        .entries
                        .map((e) => _renderBlock(e.value, e.key, primaryColor))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        );

      case BlockType.callout:
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: OrtizSpace.xs),
          padding: const pw.EdgeInsets.all(OrtizSpace.sm),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(OrtizRadius.chip)),
            border: pw.Border.all(color: PdfColors.indigo200, width: 0.8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 8,
                height: 8,
                margin: const pw.EdgeInsets.only(top: OrtizSpace.xxs, right: OrtizSpace.sm),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  block.content,
                  style: const pw.TextStyle(fontSize: OrtizFontSize.caption, color: PdfColors.indigo900),
                ),
              ),
            ],
          ),
        );

      case BlockType.divider:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: OrtizSpace.sm),
          child: pw.Divider(color: PdfColors.grey300, thickness: 0.8),
        );
    }
  }

  /// Descarga directamente el PDF en la máquina del usuario (Web o Desktop/Móvil).
  Future<void> downloadNotePdf({
    required NoteItem note,
    NoteCategory? category,
    BuildContext? context,
  }) async {
    try {
      final safeName = sanitizeFilename(note.title.isNotEmpty ? note.title : 'nota');
      final fileName = '${safeName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      final bytes = await generateNotePdf(note: note, category: category);

      // Printing.sharePdf realiza la descarga directa en Web mediante el navegador,
      // y abre el visor/selector de guardado en móvil y escritorio.
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento PDF "$fileName" generado con éxito'),
            backgroundColor: OrtizPalette.ok,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generando/descargando PDF de nota: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: OrtizPalette.bad,
          ),
        );
      }
    }
  }

  /// Abre la vista previa de impresión nativa del sistema / navegador.
  Future<void> printOrPreviewPdf({
    required NoteItem note,
    NoteCategory? category,
  }) async {
    final safeName = sanitizeFilename(note.title.isNotEmpty ? note.title : 'nota');
    final fileName = '${safeName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    await Printing.layoutPdf(
      name: fileName,
      onLayout: (PdfPageFormat format) async {
        return generateNotePdf(note: note, category: category);
      },
    );
  }

  /// Comparte el archivo PDF usando la hoja nativa de compartir del sistema operativo.
  Future<void> sharePdfFile({
    required NoteItem note,
    NoteCategory? category,
    Rect? sharePositionOrigin,
    BuildContext? context,
  }) async {
    try {
      final safeName = sanitizeFilename(note.title.isNotEmpty ? note.title : 'nota');
      final fileName = '${safeName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      final bytes = await generateNotePdf(note: note, category: category);

      final xFile = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: fileName,
      );

      await Share.shareXFiles(
        [xFile],
        subject: note.title,
        text: 'Nota compartida: ${note.title}',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Error compartiendo archivo PDF: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir PDF: $e'),
            backgroundColor: OrtizPalette.bad,
          ),
        );
      }
    }
  }

  /// Muestra un modal elegante con opciones completas para compartir y descargar la nota.
  static Future<void> showShareModal({
    required BuildContext context,
    required NoteItem note,
    NoteCategory? category,
  }) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: OrtizPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.xxl),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de arrastre superior
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OrtizPalette.line,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                  ),
                ),
                const SizedBox(height: OrtizSpace.lg),

                // Encabezado de la nota
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: OrtizPalette.surfaceHigh,
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                      alignment: Alignment.center,
                      child: Text(note.emoji, style: const TextStyle(fontSize: OrtizFontSize.display)),
                    ),
                    const SizedBox(width: OrtizSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title.isNotEmpty ? note.title : 'Sin título',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: OrtizFontSize.titleSm,
                              fontWeight: FontWeight.bold,
                              color: OrtizPalette.fg,
                            ),
                          ),
                          const SizedBox(height: OrtizSpace.xxs),
                          Text(
                            category?.name ?? 'General',
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              color: category?.color ?? NotasColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OrtizSpace.xl),
                const Divider(height: 1),
                const SizedBox(height: OrtizSpace.md),

                // Opción 1: Descargar PDF
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(OrtizSpace.sm),
                    decoration: BoxDecoration(
                      color: NotasColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: NotasColors.primary, size: OrtizIconSize.lg),
                  ),
                  title: const Text('Descargar como PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.body)),
                  subtitle: const Text('Genera un archivo PDF limpio y listo para guardar o imprimir', style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await NotePdfService.instance.downloadNotePdf(
                      note: note,
                      category: category,
                      context: context,
                    );
                  },
                ),

                // Opción 2: Imprimir / Vista Previa
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(OrtizSpace.sm),
                    decoration: BoxDecoration(
                      color: NotasColors.datosGreenLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: const Icon(Icons.print_rounded, color: NotasColors.datosGreen, size: OrtizIconSize.lg),
                  ),
                  title: const Text('Imprimir / Vista Previa', style: TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.body)),
                  subtitle: const Text('Abre el visor de impresión nativo del navegador o dispositivo', style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await NotePdfService.instance.printOrPreviewPdf(
                      note: note,
                      category: category,
                    );
                  },
                ),

                // Opción 3: Compartir Archivo PDF
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(OrtizSpace.sm),
                    decoration: BoxDecoration(
                      color: NotasColors.acuerdosPinkLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: const Icon(Icons.share_rounded, color: NotasColors.acuerdosPink, size: OrtizIconSize.lg),
                  ),
                  title: const Text('Compartir documento PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.body)),
                  subtitle: const Text('Envía el PDF por WhatsApp, Telegram, correo u otras apps', style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await NotePdfService.instance.sharePdfFile(
                      note: note,
                      category: category,
                      sharePositionOrigin: sharePositionOrigin,
                      context: context,
                    );
                  },
                ),

                // Opción 4: Compartir como Texto / Markdown
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(OrtizSpace.sm),
                    decoration: BoxDecoration(
                      color: NotasColors.ideasAmberLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    child: const Icon(Icons.text_snippet_rounded, color: NotasColors.ideasAmber, size: OrtizIconSize.lg),
                  ),
                  title: const Text('Compartir como Texto', style: TextStyle(fontWeight: FontWeight.w600, fontSize: OrtizFontSize.body)),
                  subtitle: const Text('Comparte el contenido en texto plano / Markdown', style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await Share.share(
                      note.toMarkdown(),
                      subject: note.title,
                      sharePositionOrigin: sharePositionOrigin,
                    );
                  },
                ),
                const SizedBox(height: OrtizSpace.sm),
              ],
            ),
          ),
        );
      },
    );
  }
}
