import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import '../services/notification_manager.dart';
import '../widgets/claymorphic_background.dart';
import 'dashboard_screen.dart';
import 'pockets_screen.dart';
import 'transactions_history_screen.dart';
import 'rates_history_screen.dart';
import 'market_screen.dart';

import '../dialogs/add_action_selection_sheet.dart';
import '../dialogs/pending_confirmations_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = [
    DashboardScreen(),
    PocketsScreen(),
    TransactionsHistoryScreen(),
    MarketScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Request notifications permission
      await NotificationManager.shared.requestAuthorization();

      // Ensure data is loaded
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.loadData();

      // 2. Fallback sync rate histories if database is empty (first time entering app)
      if (appState.rateHistory.isEmpty || appState.euroRateHistory.isEmpty) {
        await appState.fetchFullRateHistory();
        await appState.refreshRates();
      } else {
        // Just refresh the latest rates
        await appState.refreshRates();
      }

      // 4. Show local reminders for any pending entries due today
      for (var payment in appState.pendingPaymentsToday) {
        await NotificationManager.shared.showImmediateReminder(payment.payment);
      }

      // 5. Show confirmations dialog
      if (context.mounted && appState.pendingPaymentsToday.isNotEmpty) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PendingConfirmationsBottomSheet(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final selectedIndex = appState.currentTabIndex;

    return ShowCaseWidget(
      enableAutoScroll: true,
      scrollDuration: Duration(milliseconds: 350),
      builder: (context) {
        return Scaffold(
          body: ClaymorphicBackground(
            child: IndexedStack(
              index: selectedIndex,
              children: _screens,
            ),
          ),
          extendBody: true,
          floatingActionButton: Showcase(
            key: appState.fabKey,
            title: "Acciones Rápidas",
            description: "Desde aquí puedes registrar rápidamente ingresos, gastos, cambios de divisas y revisar pagos pendientes.",
            child: FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AddActionSelectionBottomSheet(),
                );
              },
              backgroundColor: AppColors.primary,
              elevation: 6.0,
              shape: CircleBorder(),
              child: Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: CustomPaint(
            foregroundPainter: _NotchedBorderPainter(
              color: Colors.grey[300]!,
              strokeWidth: 1.0,
            ),
            child: BottomAppBar(
              color: Colors.white,
              elevation: 12,
              notchMargin: 8.0,
              clipBehavior: Clip.antiAlias,
              shape: AutomaticNotchedShape(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                CircleBorder(),
              ),
              padding: EdgeInsets.zero,
              height: 76,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(context, appState, 0, Icons.grid_view_rounded, "Dashboard"),
                  _buildNavItem(context, appState, 1, Icons.inventory_2_rounded, "Bolsillos"),
                  SizedBox(width: 48), // Spacer for the floating action button notch
                  _buildNavItem(context, appState, 2, Icons.receipt_long_rounded, "Historial"),
                  _buildNavItem(context, appState, 3, Icons.shopping_cart_outlined, "Mercado"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(BuildContext context, AppState appState, int index, IconData icon, String label) {
    final isSelected = appState.currentTabIndex == index;
    return InkWell(
      onTap: () {
        appState.setTabIndex(index);
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 180),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey[500],
                size: 24,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotchedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _NotchedBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const shape = AutomaticNotchedShape(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      CircleBorder(),
    );

    // Bounding box of the FAB in Scaffolds (centered horizontally, center on top edge)
    final double fabRadius = 28.0;
    final fabCenter = Offset(size.width / 2, 0);
    final guestRect = Rect.fromCircle(center: fabCenter, radius: fabRadius).inflate(8.0); // inflated by notchMargin (8.0)

    final path = shape.getOuterPath(Offset.zero & size, guestRect);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
