import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/claymorphic_background.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import '../dialogs/pin_verification_dialog.dart';
import '../dialogs/pin_setup_bottom_sheet.dart';
import '../services/backup_service.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class BackupManagementScreen extends StatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  List<Map<String, dynamic>> _backups = [];
  List<Map<String, dynamic>> _restoreHistory = [];
  String _securityPin = "1234";
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Copias Disponibles, 1: Historial

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final list = await appState.getBackupsList();
      if (!mounted) return;
      final metadata = await appState.loadBackupMetadata();
      if (!mounted) return;
      final history = List<Map<String, dynamic>>.from(
        metadata['restore_history'] as List? ?? [],
      );
      final pin = metadata['security_pin'] as String? ?? "1234";

      setState(() {
        _backups = list;
        _restoreHistory = history.reversed.toList(); // Newest first
        _securityPin = pin;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatSize(double bytes) {
    if (bytes < 1024) return "${bytes.toStringAsFixed(0)} B";
    final kb = bytes / 1024;
    if (kb < 1024) return "${kb.toStringAsFixed(1)} KB";
    final mb = kb / 1024;
    return "${mb.toStringAsFixed(2)} MB";
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$day/$month/${dt.year} $hour:$min";
  }

  Future<void> _createManualBackup() async {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      await appState.createManualBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Copia de seguridad creada correctamente"),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al crear copia: $e"),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
    if (mounted) {
      await _refreshData();
    }
  }

  Future<void> _importBackupFromFile() async {
    final appState = Provider.of<AppState>(context, listen: false);
    BuildContext? progressDialogContext;

    try {
      final result = await appState.importBackupFromFile(
        onUploadStart: () {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dContext) {
              progressDialogContext = dContext;
              return PopScope(
                canPop: false,
                child: Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
                  backgroundColor: OrtizPalette.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xxl, vertical: OrtizSpace.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(OrtizSpace.lg),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_rounded,
                            color: AppColors.primary,
                            size: OrtizIconSize.xl,
                          ),
                        ),
                        const SizedBox(height: OrtizSpace.lg),
                        const Text(
                          "Importando Copia de Seguridad",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        Text(
                          "Subiendo y sincronizando tus libros contables...",
                          style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted, height: 1.3),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: OrtizSpace.xxl),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            backgroundColor: OrtizPalette.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: OrtizSpace.md),
                        Text(
                          "Por favor no cierres esta ventana",
                          style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      // Close progress dialog if open
      if (progressDialogContext != null && Navigator.of(progressDialogContext!).canPop()) {
        Navigator.of(progressDialogContext!).pop();
      }

      if (!mounted) return;
      await _refreshData();
      if (!mounted) return;

      if (result.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Importación cancelada."),
          ),
        );
        return;
      }

      if (result.success) {
        await showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(OrtizSpace.sm),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.income,
                    size: OrtizIconSize.lg,
                  ),
                ),
                const SizedBox(width: OrtizSpace.md),
                const Expanded(
                  child: Text(
                    "¡Importación Exitosa!",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.fileName != null
                        ? "Se restauraron los datos correctamente desde '${result.fileName}'."
                        : "Se restauraron los datos correctamente desde la copia de seguridad.",
                    style: const TextStyle(fontSize: OrtizFontSize.bodySm, height: 1.3, color: OrtizPalette.fg),
                  ),
                  const SizedBox(height: OrtizSpace.lg),
                  Container(
                    padding: const EdgeInsets.all(OrtizSpace.md),
                    decoration: BoxDecoration(
                      color: OrtizPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      border: Border.all(color: OrtizPalette.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow(
                          Icons.person_pin_rounded,
                          "Perfil Activo:",
                          result.activeProfileName,
                          isBold: true,
                        ),
                        if (result.profilesCount > 1) ...[
                          const SizedBox(height: OrtizSpace.sm),
                          _buildSummaryRow(
                            Icons.switch_account_rounded,
                            "Perfiles en copia:",
                            "${result.profilesCount}",
                          ),
                        ],
                        const SizedBox(height: OrtizSpace.sm),
                        _buildSummaryRow(
                          Icons.receipt_long_rounded,
                          "Transacciones:",
                          "${result.transactionsCount}",
                          isBold: true,
                          valueColor: AppColors.primary,
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        _buildSummaryRow(
                          Icons.account_balance_wallet_rounded,
                          "Cuentas:",
                          "${result.accountsCount}",
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        _buildSummaryRow(
                          Icons.savings_rounded,
                          "Bolsillos:",
                          "${result.pocketsCount}",
                        ),
                        const SizedBox(height: OrtizSpace.sm),
                        _buildSummaryRow(
                          Icons.category_rounded,
                          "Categorías:",
                          "${result.categoriesCount}",
                        ),
                        if (result.recurringCount > 0) ...[
                          const SizedBox(height: OrtizSpace.sm),
                          _buildSummaryRow(
                            Icons.repeat_rounded,
                            "Pagos recurrentes:",
                            "${result.recurringCount}",
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text("Cerrar"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: OrtizPalette.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                ),
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.dashboard_rounded, size: OrtizIconSize.md),
                label: const Text("Ir al Dashboard"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? "Error al importar los datos."),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } catch (e) {
      if (progressDialogContext != null && Navigator.of(progressDialogContext!).canPop()) {
        Navigator.of(progressDialogContext!).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al importar: $e"),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportBackup(String folderName, BuildContext btnContext) async {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      final box = btnContext.findRenderObject() as RenderBox?;
      final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await appState.exportBackupFolder(folderName, sharePositionOrigin: rect);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al exportar copia de seguridad: $e"),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
    _refreshData();
  }

  Future<void> _confirmDelete(String folderName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Eliminar Copia de Seguridad",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm),
        ),
        content: Text(
          "¿Estás seguro de que deseas eliminar permanentemente esta copia de seguridad? Esta acción no se puede deshacer.",
          style: TextStyle(fontSize: OrtizFontSize.bodySm, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: Text("Eliminar"),
          ),
        ],
      ),
    );

    if (ok == true) {
      final appState = Provider.of<AppState>(context, listen: false);
      setState(() => _isLoading = true);
      await appState.deleteBackup(folderName);
      if (mounted) {
        await _refreshData();
      }
    }
  }

  Future<void> _confirmRestore(String folderName) async {
    // 1. Confirm action
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Restaurar Datos",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm),
        ),
        content: Text(
          "Se reemplazarán todas tus cuentas, transacciones y bolsillos actuales con los datos de esta copia de seguridad.\n\n¿Estás seguro de que deseas proceder?",
          style: TextStyle(fontSize: OrtizFontSize.bodySm, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: Text("Proceder"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. PIN Verification or Setup
    if (!mounted) return;
    
    if (_securityPin.isEmpty) {
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PinSetupBottomSheet(mode: PinSetupMode.create),
      );
      if (created != true) return;
      
      // Reload metadata to update the local _securityPin variable
      final appState = Provider.of<AppState>(context, listen: false);
      final metadata = await appState.loadBackupMetadata();
      _securityPin = metadata['security_pin'] as String? ?? "";
    } else {
      final pinOk = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PinVerificationDialog(
          correctPin: _securityPin,
          title: "Confirmar Restauración",
          subtitle:
              "Introduce tu PIN de 4 dígitos para autorizar el reemplazo de datos",
        ),
      );
      if (pinOk != true) return;
    }

    // 3. Perform restore
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() => _isLoading = true);

    final success = await appState.restoreBackup(folderName);

    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              "¡Restauración Exitosa!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.titleSm),
            ),
            content: Text(
              "Tus libros y transacciones han sido restaurados correctamente al estado de la copia de seguridad seleccionada.",
              style: TextStyle(fontSize: OrtizFontSize.bodySm, height: 1.3),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cerrar"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: OrtizPalette.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.dashboard_rounded, size: OrtizIconSize.md),
                label: const Text("Ir al Dashboard"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Error al restaurar los datos."),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
    if (mounted) {
      await _refreshData();
    }
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: OrtizIconSize.sm, color: OrtizPalette.muted),
        const SizedBox(width: OrtizSpace.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            color: OrtizPalette.muted,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: OrtizFontSize.bodySm,
            color: valueColor ?? (isBold ? OrtizPalette.fg : OrtizPalette.fg),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Copias de Seguridad",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.title),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
        ),
      body: ClaymorphicBackground(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.all(OrtizSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Segmented Tab Bar
                    Container(
                      padding: EdgeInsets.all(OrtizSpace.xs),
                      decoration: BoxDecoration(
                        color: AppColors.nestedTabTrackBg,
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                      child: Row(
                        children: [
                          _TabSegment(
                            title: "Copias Disponibles",
                            isSelected: _selectedTab == 0,
                            onTap: () => setState(() => _selectedTab = 0),
                          ),
                          _TabSegment(
                            title: "Historial",
                            isSelected: _selectedTab == 1,
                            onTap: () => setState(() => _selectedTab = 1),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: OrtizSpace.xl),

                    if (_selectedTab == 0) ...[
                      // Create backup card
                      OrtizSection(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Resguardar Datos al Instante",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.body,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      SizedBox(height: OrtizSpace.xxs),
                                      Text(
                                        "Crea una copia de seguridad manual local con todos tus libros activos.",
                                        style: TextStyle(
                                          fontSize: OrtizFontSize.caption,
                                          color: OrtizPalette.muted,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: OrtizSpace.lg),
                            ElevatedButton(
                              onPressed: _createManualBackup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: OrtizPalette.onAccent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(OrtizRadius.field)),
                                padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                              ),
                              child: Text(
                                "Crear Copia de Seguridad Manual",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(height: OrtizSpace.sm),
                            OutlinedButton(
                              onPressed: _importBackupFromFile,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(OrtizRadius.field)),
                                side: BorderSide(color: AppColors.primary),
                                padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                              ),
                              child: Text(
                                "Importar desde Archivo (.json)",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                      ),

                      // Backup list
                      OrtizSection(
                        title: "COPIAS DISPONIBLES",
                        divided: true,
                        children: [
                          if (_backups.isEmpty)
                            OrtizEmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: "No hay copias de seguridad disponibles.",
                              message: "Se crean automáticamente todos los días.",
                            )
                          else
                            ..._backups.map((bk) => _buildBackupRow(bk)),
                        ],
                      ),
                    ] else ...[
                      // Restore history
                      OrtizSection(
                        title: "HISTORIAL DE RESTAURACIONES",
                        children: [
                          if (_restoreHistory.isEmpty)
                            OrtizEmptyState(
                              icon: Icons.history_rounded,
                              title:
                                  "Aún no se han realizado restauraciones en este dispositivo.",
                            )
                          else
                            ..._restoreHistory.map(
                              (hist) => _buildHistoryRow(hist),
                            ),
                        ],
                      ),
                    ],
                    SizedBox(height: OrtizSpace.xxxl),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildBackupRow(Map<String, dynamic> bk) {
    final name = bk['name'] as String;
    final isAuto = bk['is_auto'] as bool;
    final size = (bk['size_bytes'] as num?)?.toDouble() ?? 0.0;
    final dt = bk['created_at'] as DateTime;
    final path = bk['path'] as String? ?? '';

    // Fila sin tarjeta dentro de una `OrtizSection` dividida. No es
    // `OrtizListRow` porque esta fusiona la semántica y las tres acciones
    // deben seguir siendo botones independientes.
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showBackupPreview(context, name, path),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(OrtizSpace.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAuto ? Icons.auto_mode_rounded : Icons.person_rounded,
                  color: AppColors.primary,
                  size: OrtizIconSize.md,
                ),
              ),
              SizedBox(width: OrtizSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAuto ? "Copia Automática" : "Copia Manual",
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardText,
                      ),
                    ),
                    SizedBox(height: OrtizSpace.xxs),
                    Text(
                      "${_formatDateTime(dt)} • ${_formatSize(size)}",
                      style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                    ),
                  ],
                ),
              ),
               Builder(
                builder: (btnContext) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.share_rounded),
                      color: AppColors.primary,
                      tooltip: "Compartir / Enviar",
                      iconSize: 20,
                      onPressed: () => _exportBackup(name, btnContext),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_backup_restore_rounded),
                      color: AppColors.primary,
                      tooltip: "Restaurar",
                      iconSize: 22,
                      onPressed: () => _confirmRestore(name),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded),
                      color: AppColors.expense,
                      tooltip: "Eliminar",
                      iconSize: 22,
                      onPressed: () => _confirmDelete(name),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> hist) {
    final bkName = hist['backup_name'] as String? ?? "Desconocido";
    final dateStr = hist['restored_at'] as String? ?? "";
    final success = hist['success'] as bool? ?? false;
    final error = hist['error'] as String?;

    DateTime? dt;
    if (dateStr.isNotEmpty) {
      dt = DateTime.tryParse(dateStr);
    }

    final displayDate = dt != null ? _formatDateTime(dt) : dateStr;
    final isAuto = bkName.startsWith('auto_backup_');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: OrtizPalette.line, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isAuto ? "Copia Automática" : "Copia Manual",
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                decoration: BoxDecoration(
                  color: success
                      ? AppColors.income.withValues(alpha: 0.12)
                      : AppColors.expense.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
                child: Text(
                  success ? "EXITOSA" : "FALLIDA",
                  style: TextStyle(
                    fontSize: OrtizFontSize.micro,
                    fontWeight: FontWeight.bold,
                    color: success ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: OrtizSpace.xxs),
          Text(
            "Origen: $bkName\nFecha: $displayDate",
            style: TextStyle(
              fontSize: OrtizFontSize.micro,
              color: OrtizPalette.muted,
              height: 1.3,
            ),
          ),
          if (error != null) ...[
            SizedBox(height: OrtizSpace.xs),
            Text(
              "Error: $error",
              style: TextStyle(
                fontSize: OrtizFontSize.micro,
                color: AppColors.expense,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showBackupPreview(BuildContext context, String folderName, String folderPath) {
    final appState = Provider.of<AppState>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
              ),
              child: FutureBuilder<Map<String, dynamic>>(
                future: appState.getBackupPreview(folderPath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Text("Error al cargar la vista previa."),
                    );
                  }

                  final data = snapshot.data!;
                  final profilesList = data['profiles'] as List? ?? [];
                  final totalTx = (data['total_transactions'] as num?)?.toInt() ?? 0;
                  final totalPockets = (data['total_pockets'] as num?)?.toInt() ?? 0;
                  final totalMarket = (data['total_market_items'] as num?)?.toInt() ?? 0;

                  return Column(
                    children: [
                      SizedBox(height: OrtizSpace.md),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: OrtizPalette.muted,
                          borderRadius: BorderRadius.circular(OrtizRadius.chip),
                        ),
                      ),
                      SizedBox(height: OrtizSpace.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Vista Previa de Respaldo",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.title,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: OrtizSpace.xxs),
                                  Text(
                                    folderName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: OrtizPalette.muted),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Divider(),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.sm),
                          children: [
                            Row(
                              children: [
                                _buildPreviewStatCard(
                                  Icons.receipt_long_rounded,
                                  "$totalTx",
                                  "Transacciones",
                                  AppColors.primary,
                                ),
                                SizedBox(width: OrtizSpace.md),
                                _buildPreviewStatCard(
                                  Icons.savings_rounded,
                                  "$totalPockets",
                                  "Bolsillos",
                                  AppColors.primary,
                                ),
                                SizedBox(width: OrtizSpace.md),
                                _buildPreviewStatCard(
                                  Icons.shopping_cart_rounded,
                                  "$totalMarket",
                                  "Compras",
                                  AppColors.primary,
                                ),
                              ],
                            ),
                            SizedBox(height: OrtizSpace.xxl),
                            Text(
                              "LIBROS Y CUENTAS",
                              style: TextStyle(
                                fontSize: OrtizFontSize.caption,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardSubtitleText,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: OrtizSpace.sm),
                            if (profilesList.isEmpty)
                              OrtizEmptyState(
                                icon: Icons.menu_book_outlined,
                                title: "No se encontraron perfiles guardados.",
                              )
                            else
                              ...profilesList.map((p) {
                                final name = p['name'] as String;
                                final accounts = p['accounts'] as List;

                                return OrtizSection(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.book_outlined, size: OrtizIconSize.md, color: AppColors.primary),
                                            SizedBox(width: OrtizSpace.sm),
                                            Text(
                                              "Libro: $name",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: OrtizFontSize.body,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Divider(height: 20),
                                        if (accounts.isEmpty)
                                          Text(
                                            "Sin cuentas registradas en este libro.",
                                            style: TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                                          )
                                        else
                                          ...accounts.map((acc) {
                                            final accName = acc['name'] as String;
                                            final balance = (acc['balance'] as num?)?.toDouble() ?? 0.0;
                                            final currency = acc['currency'] as String;

                                            String currencySymbol = "\$";
                                            if (currency.toLowerCase().contains("bs")) {
                                              currencySymbol = "Bs";
                                            } else if (currency.toLowerCase().contains("eur")) {
                                              currencySymbol = "€";
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xs),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(accName, style: TextStyle(fontSize: OrtizFontSize.bodySm)),
                                                  OrtizAmount(
                                                    value: balance,
                                                    currencySymbol: currencySymbol,
                                                    format: (v) =>
                                                        "$currencySymbol ${v.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: OrtizFontSize.bodySm,
                                                      color: OrtizPalette.fg,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                      ],
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(OrtizSpace.xl),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Close preview
                              _confirmRestore(folderName);
                            },
                            icon: Icon(Icons.settings_backup_restore_rounded),
                            label: Text("Restaurar esta Copia"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: OrtizPalette.onAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewStatCard(IconData icon, String val, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: OrtizSpace.md, horizontal: OrtizSpace.sm),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(OrtizSpace.xs),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: OrtizIconSize.md),
            ),
            SizedBox(height: OrtizSpace.sm),
            Text(
              val,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: OrtizFontSize.titleSm, color: AppColors.cardText),
            ),
            SizedBox(height: OrtizSpace.xxs),
            Text(
              label,
              style: TextStyle(fontSize: OrtizFontSize.micro, color: AppColors.cardSubtitleText, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabSegment({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainTabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.mainTabActiveText
                  : AppColors.mainTabInactiveText,
              fontSize: OrtizFontSize.bodySm,
            ),
          ),
        ),
      ),
    );
  }
}
