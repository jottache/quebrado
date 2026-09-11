import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../widgets/claymorphic_card.dart';

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
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 16.0,
        bottom: 36.0,
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 18),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Super App Hub",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Selecciona el módulo que deseas utilizar",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      "Supabase",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Module Grid / List
          _buildModuleCard(
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
          SizedBox(height: 12),

          _buildModuleCard(
            context,
            title: "Mercado & Compras",
            subtitle: "Sesiones de mercado en vivo, listas y comparador",
            icon: Icons.shopping_cart_rounded,
            color: Color(0xFFE67E22),
            isActive: activeModule == SuperAppModule.market,
            onTap: () {
              appState.setActiveSuperAppModule(SuperAppModule.market);
              appState.setTabIndex(3);
              Navigator.pop(context);
            },
          ),
          SizedBox(height: 12),

          _buildModuleCard(
            context,
            title: "Asistente Personal IA",
            subtitle: "Chatbot conectado a Gemini para consultar tus datos",
            icon: Icons.auto_awesome_rounded,
            color: Color(0xFF8E44AD),
            isActive: activeModule == SuperAppModule.assistant,
            badgeText: "Próximamente",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("El módulo de Asistente IA se habilitará en la siguiente fase."),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          SizedBox(height: 12),

          // Slot para el próximo módulo que el usuario tiene en mente
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 1.5, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, color: Colors.grey[500], size: 24),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Próximo Módulo",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        "Listo para conectar tu siguiente idea",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isActive,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClaymorphicCard(
        cornerRadius: 20,
        backgroundColor: isActive ? color.withOpacity(0.06) : Colors.white,
        padding: EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (badgeText != null) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 14),
              )
            else
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 22),
          ],
        ),
      ),
    );
  }
}
