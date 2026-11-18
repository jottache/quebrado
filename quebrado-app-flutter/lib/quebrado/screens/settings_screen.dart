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
import '../services/supabase_config.dart';
import '../services/supabase_service.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
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
            'assets/images/quebrado/logo_quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: OrtizPalette.muted),
            tooltip: "Cerrar",
            onPressed: () {
              Navigator.of(context, rootNavigator: true).maybePop();
            },
          ),
        ],
      ),
      body: ClaymorphicBackground(
        child: ListView(
          padding: EdgeInsets.all(OrtizSpace.lg),
          children: [
            // Libros de Contabilidad Section
            _buildSectionHeader("Contabilidad"),
            // Grupo sin tarjeta: filas directas sobre el fondo.
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                title: Text(
                  "Libros de Contabilidad",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: OrtizPalette.fg,
                  ),
                ),
                subtitle: Text(
                  "Libro activo: ${appState.activeProfileName}",
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    color: OrtizPalette.muted,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: OrtizPalette.muted,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          title: const Text(
                            "Libros de Contabilidad",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                              fontSize: OrtizFontSize.titleSm,
                            ),
                          ),
                        ),
                        body: const BookSelectorBottomSheet(),
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildSectionFooter(
              "Cambia de contabilidad, crea nuevos libros aislados para tus negocios o renómbralos.",
            ),
            SizedBox(height: OrtizSpace.xxl),

            // Supabase Cloud Section
            _buildSectionHeader("Nube y Sincronización"),
            // Grupo sin tarjeta: filas directas sobre el fondo.
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: Icon(
                  SupabaseConfig.isConfigured ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                  color: SupabaseConfig.isConfigured ? AppColors.income : OrtizPalette.warn,
                  size: OrtizIconSize.lg,
                ),
                title: Text(
                  "Supabase Cloud",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: OrtizPalette.fg,
                  ),
                ),
                subtitle: Text(
                  SupabaseConfig.isConfigured
                      ? "Conectado a tu base de datos en la nube"
                      : "Configurar URL y Anon Key para sincronización",
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    color: OrtizPalette.muted,
                  ),
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: OrtizSpace.sm, vertical: OrtizSpace.xs),
                  decoration: BoxDecoration(
                    color: (SupabaseConfig.isConfigured ? AppColors.income : OrtizPalette.warn).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                  child: Text(
                    SupabaseConfig.isConfigured ? "Activo" : "Pendiente",
                    style: TextStyle(
                      fontSize: OrtizFontSize.caption,
                      fontWeight: FontWeight.bold,
                      color: SupabaseConfig.isConfigured ? AppColors.income : OrtizPalette.warn,
                    ),
                  ),
                ),
                onTap: () {
                  _showSupabaseInfoDialog(context);
                },
              ),
            ),
            _buildSectionFooter(
              "Permite sincronizar tus datos en tiempo real entre la Web (PWA en iPhone), Android y macOS.",
            ),
            SizedBox(height: OrtizSpace.xxl),

            // Copias de Seguridad Section
            _buildSectionHeader("Copias de Seguridad"),
            // Grupo sin tarjeta: filas directas sobre el fondo.
            Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      "Gestionar Copias de Seguridad",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    subtitle: Text(
                      "Crea copias manuales, restaura datos previos y ve el historial.",
                      style: TextStyle(
                        fontSize: OrtizFontSize.caption,
                        color: OrtizPalette.muted,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BackupManagementScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: OrtizPalette.line),
                  ListTile(
                    title: Text(
                      "PIN de Seguridad",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    subtitle: Text(
                      "Cambia el código PIN de 4 dígitos requerido para restaurar datos.",
                      style: TextStyle(
                        fontSize: OrtizFontSize.caption,
                        color: OrtizPalette.muted,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
                    ),
                    onTap: () => _showChangePinBottomSheet(context, appState),
                  ),
                ],
              ),
            ),
            _buildSectionFooter(
              "Administra tus respaldos locales de seguridad y configura el PIN de confirmación.",
            ),
            SizedBox(height: OrtizSpace.xxl),

            // Personalizacion Section
            _buildSectionHeader("Personalización"),
            // Grupo sin tarjeta: filas directas sobre el fondo.
            Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      "Cuentas y Bancos",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AccountManagementScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: OrtizPalette.line),
                  ListTile(
                    title: Text(
                      "Categorías de Transacción",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CategoryManagementScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: OrtizPalette.line),
                  ListTile(
                    title: Text(
                      "Contactos Pago Móvil",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
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
            SizedBox(height: OrtizSpace.xxl),

            // Seguridad y Confirmación Section
            _buildSectionHeader("Seguridad y Confirmación"),
            // Grupo sin tarjeta: filas directas sobre el fondo.
            Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      "Confirmación Biométrica",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    subtitle: Text(
                      "Solicita tu huella o rostro al registrar transacciones.",
                      style: TextStyle(fontSize: OrtizFontSize.caption),
                    ),
                    value: appState.useBiometrics,
                    onChanged: (bool value) async {
                      await appState.setUseBiometrics(value);
                    },
                  ),
                  Divider(height: 1, color: OrtizPalette.line),
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: const Text(
                      "Confirmación con PIN",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    subtitle: const Text(
                      "Solicita tu código PIN de 4 dígitos al registrar transacciones (ideal para Web y Desktop).",
                      style: TextStyle(fontSize: OrtizFontSize.caption),
                    ),
                    value: appState.usePinSecurity,
                    onChanged: (bool value) async {
                      if (value) {
                        final pin = await appState.getSecurityPin();
                        if (pin == '1234') {
                          if (context.mounted) {
                            _showChangePinBottomSheet(context, appState);
                          }
                        }
                      }
                      await appState.setUsePinSecurity(value);
                    },
                  ),
                ],
              ),
            ),
            _buildSectionFooter(
              "Configura capas extra de protección para evitar toques accidentales al registrar tus movimientos.",
            ),
            SizedBox(height: OrtizSpace.xxl),

            // Guías y Ayuda Section
            _buildSectionHeader("Guías y Ayuda"),
            // Grupo sin tarjeta: filas directas sobre el fondo.
            Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      "Ver Guía del Tablero",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
                    ),
                    onTap: () {
                      appState.triggerDashboardTutorial();
                      Navigator.pop(context);
                    },
                  ),
                  Divider(height: 1, color: OrtizPalette.line),
                  ListTile(
                    title: Text(
                      "Ver Guía de Bolsillos",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
                    ),
                    onTap: () {
                      appState.triggerPocketsTutorial();
                      Navigator.pop(context);
                    },
                  ),
                  Divider(height: 1, color: OrtizPalette.line),
                  ListTile(
                    title: Text(
                      "Ver Guía de Pagos Recurrentes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
                    ),
                    onTap: () {
                      appState.triggerRecurrentsTutorial();
                      Navigator.pop(context);
                    },
                  ),
                  Divider(height: 1, color: OrtizPalette.line),
                  ListTile(
                    title: Text(
                      "Ver Guía de Proyección",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: OrtizPalette.fg,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: OrtizPalette.muted,
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
            SizedBox(height: OrtizSpace.xxl),

            // Tasas de Cambio Section
            _buildSectionHeader("Tasas de Cambio"),
            // Grupo sin tarjeta: filas directas sobre el fondo.
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                title: Text(
                  appState.isFetchingHistory
                      ? "Sincronizando historiales..."
                      : "Actualizar Historiales",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: appState.isFetchingHistory
                        ? OrtizPalette.muted
                        : OrtizPalette.fg,
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
            SizedBox(height: OrtizSpace.xxl),

            // Mantenimiento Section
            _buildSectionHeader("Mantenimiento"),
            // Grupo sin tarjeta: filas directas sobre el fondo.
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                title: Text(
                  "Reiniciar Datos",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: OrtizPalette.fg,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: OrtizPalette.muted,
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
      padding: EdgeInsets.only(left: OrtizSpace.sm, bottom: OrtizSpace.sm),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: OrtizFontSize.caption,
          fontWeight: FontWeight.bold,
          color: OrtizPalette.muted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSectionFooter(String text) {
    return Padding(
      padding: EdgeInsets.only(left: OrtizSpace.sm, top: OrtizSpace.xs, right: OrtizSpace.sm),
      child: Text(
        text,
        style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
      ),
    );
  }

  void _showResetOptionsBottomSheet(BuildContext context, AppState appState) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "Reiniciar Aplicación",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.cardText,
                fontSize: OrtizFontSize.titleSm,
              ),
            ),
          ),
          body: ClaymorphicBackground(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.xxl),
              children: [
                const Text(
                  "Selecciona una opción para reiniciar tu app desde cero. Esta acción es irreversible.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.cardSubtitleText,
                  ),
                ),
                const SizedBox(height: OrtizSpace.xxl),

                // Option 1: Partial reset
                GestureDetector(
                  onTap: () {
                    _showResetConfirmationDialog(
                      context,
                      appState,
                      isAbsolute: false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(OrtizSpace.lg),
                    decoration: BoxDecoration(
                      color: OrtizPalette.warn.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
                      border: Border.all(color: OrtizPalette.warn.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(OrtizSpace.sm),
                          decoration: BoxDecoration(
                            color: OrtizPalette.warn.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cleaning_services_rounded,
                            color: OrtizPalette.warn,
                            size: OrtizIconSize.md,
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Limpieza Parcial (Conservar Registros)",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.bodySm,
                                  fontWeight: FontWeight.bold,
                                  color: OrtizPalette.warn,
                                ),
                              ),
                              SizedBox(height: OrtizSpace.xs),
                              Text(
                                "Conserva tus bolsillos, cuentas y categorías (con saldos en cero), borrando transacciones e ingresos/gastos recurrentes.",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
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
                const SizedBox(height: OrtizSpace.md),

                // Option 2: Absolute Reset
                GestureDetector(
                  onTap: () {
                    _showResetConfirmationDialog(
                      context,
                      appState,
                      isAbsolute: true,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(OrtizSpace.lg),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
                      border: Border.all(
                        color: AppColors.expense.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(OrtizSpace.sm),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_forever_rounded,
                            color: AppColors.expense,
                            size: OrtizIconSize.md,
                          ),
                        ),
                        const SizedBox(width: OrtizSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Limpieza Total (Borrar Todo)",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.bodySm,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.expense,
                                ),
                              ),
                              SizedBox(height: OrtizSpace.xs),
                              Text(
                                "Elimina absolutamente todos los datos: transacciones, cuentas, bolsillos, categorías y vuelve al estado inicial.",
                                style: TextStyle(
                                  fontSize: OrtizFontSize.caption,
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
              ],
            ),
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
    _isConfirmEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(OrtizRadius.dialog),
              ),
              title: Text(
                isAbsolute ? "Confirmar Borrado Total" : "Confirmar Limpieza Parcial",
                style: TextStyle(
                  color: isAbsolute ? AppColors.expense : OrtizPalette.warn,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAbsolute
                        ? "Esta acción eliminará de forma irreversible toda tu información (cuentas, movimientos, bolsillos, etc.) y reiniciará la app."
                        : "Esta acción vaciará el historial de transacciones, pero conservará tus bolsillos, cuentas y categorías.",
                    style: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      color: AppColors.cardText,
                    ),
                  ),
                  SizedBox(height: OrtizSpace.lg),
                  Text(
                    "Escribe 'ELIMINAR' para confirmar:",
                    style: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardSubtitleText,
                    ),
                  ),
                  SizedBox(height: OrtizSpace.sm),
                  TextField(
                    controller: _confirmController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "ELIMINAR",
                      hintStyle: TextStyle(color: OrtizPalette.muted),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: OrtizSpace.md,
                        vertical: OrtizSpace.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      ),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        _isConfirmEnabled = val.trim() == "ELIMINAR";
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(color: AppColors.cardSubtitleText),
                  ),
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
                        : OrtizPalette.muted,
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

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "PIN de Seguridad",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.cardText,
                fontSize: OrtizFontSize.titleSm,
              ),
            ),
          ),
          body: PinSetupBottomSheet(
            mode: currentPin.isEmpty ? PinSetupMode.create : PinSetupMode.update,
            currentPin: currentPin,
          ),
        ),
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

  void _showSupabaseInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final isConfigured = SupabaseConfig.isConfigured;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.dialog)),
          title: Row(
            children: [
              Icon(
                isConfigured ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                color: isConfigured ? AppColors.income : OrtizPalette.warn,
              ),
              SizedBox(width: OrtizSpace.sm),
              Text(
                "Supabase Cloud",
                style: TextStyle(fontSize: OrtizFontSize.title, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConfigured
                    ? "Tu aplicación está configurada para sincronizarse directamente con Supabase en la nube."
                    : "Para habilitar la sincronización en la nube, coloca tu URL y Anon Key en lib/services/supabase_config.dart.",
                style: TextStyle(fontSize: OrtizFontSize.bodySm, height: 1.4),
              ),
              SizedBox(height: OrtizSpace.lg),
              Container(
                padding: EdgeInsets.all(OrtizSpace.md),
                decoration: BoxDecoration(
                  color: OrtizPalette.surfaceHigh,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "URL:",
                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
                    ),
                    Text(
                      SupabaseConfig.supabaseUrl,
                      style: TextStyle(fontSize: OrtizFontSize.caption, fontFamily: OrtizType.fontMono, color: OrtizPalette.fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: OrtizSpace.sm),
                    Text(
                      "Estado:",
                      style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
                    ),
                    Text(
                      isConfigured ? "Conectado / Listo" : "Pendiente de credenciales",
                      style: TextStyle(
                        fontSize: OrtizFontSize.caption,
                        fontWeight: FontWeight.bold,
                        color: isConfigured ? AppColors.income : OrtizPalette.warn,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
