import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/widgets/responsive_breakpoints.dart';
import 'package:quebrado_app_flutter/widgets/responsive_suite_scaffold.dart';
import 'package:quebrado_app_flutter/widgets/desktop_command_center_view.dart';
import 'package:quebrado_app_flutter/screens/app_launcher_screen.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';

Widget _buildTestApp({
  required Size screenSize,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>(create: (_) => AppState()),
      ChangeNotifierProvider<DiarioState>(create: (_) => DiarioState()),
      ChangeNotifierProvider<HabitosState>(create: (_) => HabitosState()),
      ChangeNotifierProvider<RemindersState>(create: (_) => RemindersState()),
      ChangeNotifierProvider<AgenteState>(create: (_) => AgenteState()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: child,
      ),
    ),
  );
}

void main() {
  group('ResponsiveBreakpoints Tests', () {
    testWidgets('Detects compact mobile width correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          screenSize: const Size(400, 800),
          child: Builder(
            builder: (context) {
              expect(ResponsiveBreakpoints.isCompact(context), isTrue);
              expect(ResponsiveBreakpoints.isDesktop(context), isFalse);
              expect(ResponsiveBreakpoints.isExpanded(context), isFalse);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Detects desktop and expanded widths correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          screenSize: const Size(1400, 900),
          child: Builder(
            builder: (context) {
              expect(ResponsiveBreakpoints.isCompact(context), isFalse);
              expect(ResponsiveBreakpoints.isDesktop(context), isTrue);
              expect(ResponsiveBreakpoints.isExpanded(context), isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('ResponsiveSuiteScaffold Widget Tests', () {
    testWidgets('Renders mobileBody on small screens (< 840px)', (tester) async {
      tester.view.physicalSize = const Size(450, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(
          screenSize: const Size(450, 900),
          child: const ResponsiveSuiteScaffold(
            mobileBody: Scaffold(body: Text('Mobile Launcher View')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mobile Launcher View'), findsOneWidget);
      expect(find.text('Command Center'), findsNothing);
    });

    testWidgets('Renders Desktop Sidebar and Command Center on wide screens (>= 840px)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(
          screenSize: const Size(1280, 800),
          child: const ResponsiveSuiteScaffold(),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar elements
      expect(find.text('SUITE DESKTOP'), findsOneWidget);
      expect(find.text('Command Center'), findsOneWidget);
      expect(find.text('Quebrado'), findsOneWidget);
      expect(find.text('Recordatorios'), findsWidgets);
      expect(find.text('Hábitos'), findsWidgets);
      expect(find.text('Diario'), findsWidgets);
      expect(find.text('Agente Ortiz'), findsOneWidget);

      // TopBar quick action buttons
      expect(find.text('Nuevo Gasto'), findsOneWidget);
      expect(find.text('Recordatorio'), findsOneWidget);

      // Desktop Command Center dashboard content
      expect(find.byType(DesktopCommandCenterView), findsOneWidget);
      expect(find.text('BALANCE TOTAL CONSOLIDADO'), findsOneWidget);
    });
  });
}
