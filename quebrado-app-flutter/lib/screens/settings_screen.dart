import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../widgets/claymorphic_background.dart';
import 'category_management_screen.dart';
import '../theme/colors.dart';
import 'account_management_screen.dart';
import 'mobile_payment_recipient_screen.dart';
import '../dialogs/book_selector_dialog.dart';
import 'backup_management_screen.dart';
import '../dialogs/pin_setup_bottom_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _confirmController = TextEditingController();
  bool _isConfirmEnabled = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: EdgeInsets.only(right: 0),
          child: Image.asset(
            'assets/images/quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: ClaymorphicBackground(
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            // Libros de Contabilidad Section
            _buildSectionHeader("Contabilidad"),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.cardBorderColor,
                  width: AppColors.cardBorderWidth,
                ),
              ),
              child: ListTile(
                title: Text(
                  "Libros de Contabilidad",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                subtitle: Text(
                  "Libro activo: ${appState.activeProfileName}",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black54,
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => BookSelectorBottomSheet(),
                  );
                },
              ),
            ),
            _buildSectionFooter(
              "Cambia de contabilidad, crea nuevos libros aislados para tus negocios o renómbralos.",
            ),
            SizedBox(height: 24),

            // Copias de Seguridad Section
            _buildSectionHeader("Copias de Seguridad"),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.cardBorderColor,
                  width: AppColors.cardBorderWidth,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      "Gestionar Copias de Seguridad",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      "Crea copias manuales, restaura datos previos y ve el historial.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BackupManagementScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                  ListTile(
                    title: Text(
                      "PIN de Seguridad",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      "Cambia el código PIN de 4 dígitos requerido para restaurar datos.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () => _showChangePinBottomSheet(context, appState),
                  ),
                ],
              ),
            ),
            _buildSectionFooter(
              "Administra tus respaldos locales de seguridad y configura el PIN de confirmación.",
            ),
            SizedBox(height: 24),

            // Personalizacion Section
            _buildSectionHeader("Personalización"),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.cardBorderColor,
                  width: AppColors.cardBorderWidth,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      "Cuentas y Bancos",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AccountManagementScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                  ListTile(
                    title: Text(
                      "Categorías de Transacción",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CategoryManagementScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                  ListTile(
                    title: Text(
                      "Contactos Pago Móvil",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MobilePaymentRecipientScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
             _buildSectionFooter(
              "Administra tus cuentas financieras y edita las categorías y colores disponibles para tus transacciones.",
            ),
            SizedBox(height: 24),

            // Seguridad y Confirmación Section
            _buildSectionHeader("Seguridad y Confirmación"),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.cardBorderColor,
                  width: AppColors.cardBorderWidth,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      "Confirmación Biométrica",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      "Solicita tu huella o rostro al registrar transacciones.",
                      style: TextStyle(fontSize: 11),
                    ),
                    value: appState.useBiometrics,
                    onChanged: (bool value) async {
                      await appState.setUseBiometrics(value);
                    },
                  ),
                  Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      "Botón Deslizable",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      "Reemplaza los botones de registrar por un control deslizable.",
                      style: TextStyle(fontSize: 11),
                    ),
                    value: appState.useSlideToConfirm,
                    onChanged: (bool value) async {
                      await appState.setUseSlideToConfirm(value);
                    },
                  ),
                ],
              ),
            ),
            _buildSectionFooter(
              "Configura capas extra de protección para evitar toques accidentales al registrar tus movimientos.",
            ),
            SizedBox(height: 24),

            // Guías y Ayuda Section
            _buildSectionHeader("Guías y Ayuda"),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.cardBorderColor,
                  width: AppColors.cardBorderWidth,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      "Ver Guía del Tablero",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      appState.triggerDashboardTutorial();
                      Navigator.pop(context);
                    },
                  ),
                  Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                  ListTile(
                    title: Text(
                      "Ver Guía de Bolsillos",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      appState.triggerPocketsTutorial();
                      Navigator.pop(context);
                    },
                  ),
                  Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                  ListTile(
                    title: Text(
                      "Ver Guía de Pagos Recurrentes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      appState.triggerRecurrentsTutorial();
                      Navigator.pop(context);
                    },
                  ),
                  Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                  ListTile(
                    title: Text(
                      "Ver Guía de Proyección",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      appState.triggerTimelineTutorial();
                      Navigator.pop(context);
                    },
                  ),

                ],
              ),
            ),
            _buildSectionFooter(
              "Inicia las guías interactivas para aprender a usar las funciones clave o restablécelas para verlas de nuevo.",
            ),
            SizedBox(height: 24),

            // Tasas de Cambio Section
            _buildSectionHeader("Tasas de Cambio"),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.cardBorderColor,
                  width: AppColors.cardBorderWidth,
                ),
              ),
              child: ListTile(
                title: Text(
                  appState.isFetchingHistory
                      ? "Sincronizando historiales..."
                      : "Actualizar Historiales",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: appState.isFetchingHistory
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
                onTap: appState.isFetchingHistory
                    ? null
                    : () async {
                        await appState.fetchFullRateHistory();
                        await appState.refreshRates();
                        if (context.mounted) {
                          final error = appState.rateFetchError;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error != null
                                    ? "Error al sincronizar: $error"
                                    : "Historiales de tasas sincronizados con éxito.",
                              ),
                              backgroundColor: error != null
                                  ? AppColors.expense
                                  : null,
                            ),
                          );
                        }
                      },
              ),
            ),
            _buildSectionFooter(
              "Sincroniza y descarga el historial completo de tasas de cambio oficiales del BCV y Euro en el dispositivo.",
            ),
            SizedBox(height: 24),

            // Mantenimiento Section
            _buildSectionHeader("Mantenimiento"),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.cardBorderColor,
                  width: AppColors.cardBorderWidth,
                ),
              ),
              child: ListTile(
                title: Text(
                  "Reiniciar Datos",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black54,
                ),
                onTap: () => _showResetOptionsBottomSheet(context, appState),
              ),
            ),
            _buildSectionFooter(
              "Borra toda la información registrada en la aplicación para comenzar a utilizarla desde cero. Esta acción no se puede deshacer.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSectionFooter(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 8.0, top: 6.0, right: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
    );
  }

  void _showResetOptionsBottomSheet(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              Text(
                "Reiniciar Aplicación",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardText,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Selecciona una opción para reiniciar tu app desde cero. Esta acción es irreversible.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.cardSubtitleText,
                ),
              ),
              SizedBox(height: 24),

              // Option 1: Partial reset (keep metadata, clear records)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close options sheet
                  _showResetConfirmationDialog(
                    context,
                    appState,
                    isAbsolute: false,
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cleaning_services_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Limpieza Parcial (Conservar Registros)",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Conserva tus bolsillos, cuentas y categorías (con saldos en cero), borrando transacciones e ingresos/gastos recurrentes.",
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.cardSubtitleText,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Option 2: Absolute Reset
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close options sheet
                  _showResetConfirmationDialog(
                    context,
                    appState,
                    isAbsolute: true,
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.expense.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_forever_rounded,
                          color: AppColors.expense,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Borrado Absoluto (Restablecer Todo)",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.expense,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Elimina absolutamente todos tus datos, configuraciones, categorías personalizadas, cuentas y bolsillos.",
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.cardSubtitleText,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetConfirmationDialog(
    BuildContext context,
    AppState appState, {
    required bool isAbsolute,
  }) {
    _confirmController.clear();
    setState(() => _isConfirmEnabled = false);
    final confirmWord = isAbsolute ? "ELIMINAR" : "REINICIAR";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                isAbsolute
                    ? "¿Confirmar Borrado Absoluto?"
                    : "¿Confirmar Limpieza Parcial?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAbsolute
                        ? "Esta acción es irreversible y eliminará TODO: bolsillos, cuentas, categorías e historial. Escribe '$confirmWord' para continuar."
                        : "Esta acción es irreversible y borrará tus transacciones y programaciones recurrentes, pero mantendrá tus bolsillos, cuentas y categorías (con saldos en cero). Escribe '$confirmWord' para continuar.",
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: "Escribe $confirmWord para confirmar",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        _isConfirmEnabled =
                            val.trim().toUpperCase() == confirmWord;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancelar"),
                ),
                TextButton(
                  onPressed: _isConfirmEnabled
                      ? () async {
                          if (isAbsolute) {
                            await appState.clearAllData();
                          } else {
                            await appState.clearPartialData();
                          }
                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            Navigator.pop(context); // Go back to main
                          }
                        }
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: _isConfirmEnabled
                        ? AppColors.expense
                        : Colors.grey,
                  ),
                  child: Text("Confirmar y Borrar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChangePinBottomSheet(BuildContext context, AppState appState) async {
    final metadata = await appState.loadBackupMetadata();
    final currentPin = metadata['security_pin'] as String? ?? "";

    if (!context.mounted) return;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PinSetupBottomSheet(
        mode: currentPin.isEmpty ? PinSetupMode.create : PinSetupMode.update,
        currentPin: currentPin,
      ),
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PIN configurado con éxito"),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }
}
