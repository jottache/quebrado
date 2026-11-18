import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/theme/suite_apps.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

enum SuperAppModule {
  finances,
  market,
  assistant,
}

class SuperAppHubBottomSheet extends StatelessWidget {
  const SuperAppHubBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final activeModule = appState.activeSuperAppModule;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.sheet),
          topRight: Radius.circular(OrtizRadius.sheet),
        ),
      ),
      padding: const EdgeInsets.only(
        left: OrtizSpace.xl,
        right: OrtizSpace.xl,
        top: OrtizSpace.lg,
        bottom: OrtizSpace.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: OrtizSpace.lg),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Super App Hub",
                      style: TextStyle(
                        fontSize: OrtizFontSize.title,
                        fontWeight: FontWeight.w900,
                        color: OrtizPalette.fg,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: OrtizSpace.xxs),
                    Text(
                      "Selecciona el módulo que deseas utilizar",
                      style: TextStyle(
                        fontSize: OrtizFontSize.bodySm,
                        color: OrtizPalette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const OrtizPill(
                label: "Supabase",
                icon: Icons.cloud_done_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: OrtizSpace.xl),

          // Módulos: filas sin tarjeta; el activo, sobre `surfaceHigh`.
          _buildModuleRow(
            context,
            title: "Finanzas & Presupuesto",
            subtitle: "Cuentas, balances, bolsas de ahorro y proyecciones",
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.primary,
            isActive: activeModule == SuperAppModule.finances,
            onTap: () {
              appState.setActiveSuperAppModule(SuperAppModule.finances);
              appState.setTabIndex(0);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: OrtizSpace.xs),

          _buildModuleRow(
            context,
            title: "Mercado & Compras",
            subtitle: "Sesiones de mercado en vivo, listas y comparador",
            icon: Icons.shopping_cart_rounded,
            color: SuiteAppColors.finanzas,
            isActive: activeModule == SuperAppModule.market,
            onTap: () {
              appState.setActiveSuperAppModule(SuperAppModule.market);
              appState.setTabIndex(3);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: OrtizSpace.xs),

          _buildModuleRow(
            context,
            title: "Asistente Personal IA",
            subtitle: "Chatbot conectado a Gemini para consultar tus datos",
            icon: Icons.auto_awesome_rounded,
            color: SuiteAppColors.recordatorios,
            isActive: activeModule == SuperAppModule.assistant,
            badgeText: "Próximamente",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("El módulo de Asistente IA se habilitará en la siguiente fase."),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: OrtizSpace.sm),
          const Divider(),
          const SizedBox(height: OrtizSpace.sm),

          // Slot para el próximo módulo que el usuario tiene en mente
          const OrtizListRow(
            leading: Icon(Icons.add_rounded),
            title: "Próximo Módulo",
            subtitle: "Listo para conectar tu siguiente idea",
          ),
        ],
      ),
    );
  }

  Widget _buildModuleRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isActive,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    final Widget trailing;
    if (badgeText != null) {
      trailing = OrtizPill(label: badgeText, color: color);
    } else if (isActive) {
      trailing = Icon(Icons.check_rounded, color: color, size: OrtizIconSize.md);
    } else {
      trailing = const Icon(
        Icons.chevron_right_rounded,
        color: OrtizPalette.muted,
        size: OrtizIconSize.md,
      );
    }
    return OrtizListRow(
      leading: Icon(icon, color: color, size: OrtizIconSize.lg),
      title: title,
      subtitle: subtitle,
      selected: isActive,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
