import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/claymorphic_card.dart';
import '../dialogs/pin_verification_dialog.dart';
import '../dialogs/pin_setup_bottom_sheet.dart';

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
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final list = await appState.getBackupsList();
      final metadata = await appState.loadBackupMetadata();
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
      setState(() => _isLoading = false);
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
          const SnackBar(
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
    _refreshData();
  }

  Future<void> _importBackupFromFile() async {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      final success = await appState.importBackupFromFile();
      if (mounted) {
        if (success) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                "¡Importación Exitosa!",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: const Text(
                "La copia de seguridad ha sido importada de manera exitosa desde el archivo JSON seleccionado.",
                style: TextStyle(fontSize: 13, height: 1.3),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Entendido"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Importación cancelada o fallida."),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al importar: $e"),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
    _refreshData();
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
        title: const Text(
          "Eliminar Copia de Seguridad",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          "¿Estás seguro de que deseas eliminar permanentemente esta copia de seguridad? Esta acción no se puede deshacer.",
          style: TextStyle(fontSize: 13, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (ok == true) {
      final appState = Provider.of<AppState>(context, listen: false);
      setState(() => _isLoading = true);
      await appState.deleteBackup(folderName);
      _refreshData();
    }
  }

  Future<void> _confirmRestore(String folderName) async {
    // 1. Confirm action
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Restaurar Datos",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          "Se reemplazarán todas tus cuentas, transacciones y bolsillos actuales con los datos de esta copia de seguridad.\n\n¿Estás seguro de que deseas proceder?",
          style: TextStyle(fontSize: 13, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text("Proceder"),
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
        builder: (context) => const PinSetupBottomSheet(mode: PinSetupMode.create),
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
            title: const Text(
              "¡Restauración Exitosa!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: const Text(
              "Tus libros y transacciones han sido restaurados correctamente al estado de la copia de seguridad seleccionada.",
              style: TextStyle(fontSize: 13, height: 1.3),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Entendido"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error al restaurar los datos."),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Copias de Seguridad",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ClaymorphicBackground(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Segmented Tab Bar
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.nestedTabTrackBg,
                        borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 20),

                    if (_selectedTab == 0) ...[
                      // Create backup card
                      ClaymorphicCard(
                        cornerRadius: 16,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Resguardar Datos al Instante",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.cardText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Crea una copia de seguridad manual local con todos tus libros activos.",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _createManualBackup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                "Crear Copia de Seguridad Manual",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _importBackupFromFile,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                "Importar desde Archivo (.json)",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title backup list
                      const Text(
                        "COPIAS DISPONIBLES",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cardSubtitleText,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_backups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text(
                            "No hay copias de seguridad disponibles.\nSe crean automáticamente todos los días.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              height: 1.4,
                            ),
                          ),
                        )
                      else
                        ..._backups.map((bk) => _buildBackupRow(bk)),
                    ] else ...[
                      // Restore history title
                      const Text(
                        "HISTORIAL DE RESTAURACIONES",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cardSubtitleText,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_restoreHistory.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            "Aún no se han realizado restauraciones en este dispositivo.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        )
                      else
                        ClaymorphicCard(
                          cornerRadius: 16,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: _restoreHistory
                                .map((hist) => _buildHistoryRow(hist))
                                .toList(),
                          ),
                        ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBackupRow(Map<String, dynamic> bk) {
    final name = bk['name'] as String;
    final isAuto = bk['is_auto'] as bool;
    final size = bk['size_bytes'] as double;
    final dt = bk['created_at'] as DateTime;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClaymorphicCard(
        cornerRadius: 16,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isAuto
                    ? Colors.blue.withOpacity(0.08)
                    : Colors.orange.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAuto ? Icons.auto_mode_rounded : Icons.person_rounded,
                color: isAuto ? Colors.blue : Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAuto ? "Copia Automática" : "Copia Manual",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${_formatDateTime(dt)} • ${_formatSize(size)}",
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
             Builder(
              builder: (btnContext) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded),
                    color: AppColors.primary,
                    tooltip: "Compartir / Enviar",
                    iconSize: 20,
                    onPressed: () => _exportBackup(name, btnContext),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_backup_restore_rounded),
                    color: AppColors.primary,
                    tooltip: "Restaurar",
                    iconSize: 22,
                    onPressed: () => _confirmRestore(name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
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
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: success
                      ? AppColors.income.withOpacity(0.12)
                      : AppColors.expense.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  success ? "EXITOSA" : "FALLIDA",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: success ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            "Origen: $bkName\nFecha: $displayDate",
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.grey[500],
              height: 1.3,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              "Error: $error",
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.expense,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainTabActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.mainTabActiveText
                  : AppColors.mainTabInactiveText,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
