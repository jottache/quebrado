import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/theme/colors.dart';
import 'package:quebrado_app_flutter/widgets/responsive_breakpoints.dart';

import 'pump_app.dart';

class _Contador extends ChangeNotifier {
  int valor = 0;
  void sumar() {
    valor++;
    notifyListeners();
  }
}

/// Widget de sonda: muestra la clase de ventana según los breakpoints reales de la app.
class _Sonda extends StatelessWidget {
  const _Sonda();

  @override
  Widget build(BuildContext context) {
    final clase = ResponsiveBreakpoints.isExpanded(context)
        ? 'expanded'
        : ResponsiveBreakpoints.isDesktop(context)
            ? 'desktop'
            : ResponsiveBreakpoints.isMedium(context)
                ? 'medium'
                : 'compact';
    final contador = context.watch<_Contador>();
    return Column(children: [
      Text('clase:$clase'),
      Text('valor:${contador.valor}'),
      TextButton(onPressed: contador.sumar, child: const Text('sumar')),
    ]);
  }
}

void main() {
  for (final window in WindowClass.values) {
    testWidgets('en ventana ${window.name} los breakpoints de la app dan ${window.name}', (tester) async {
      await pumpApp(
        tester,
        const _Sonda(),
        providers: [ChangeNotifierProvider<_Contador>(create: (_) => _Contador())],
        window: window,
      );

      expect(find.text('clase:${window.name}'), findsOneWidget);
    });
  }

  testWidgets('los providers inyectados reaccionan a notifyListeners', (tester) async {
    final contador = _Contador();
    await pumpApp(
      tester,
      const _Sonda(),
      providers: [ChangeNotifierProvider<_Contador>.value(value: contador)],
    );

    await tester.tap(find.text('sumar'));
    await tester.pump();

    expect(contador.valor, 1);
    expect(find.text('valor:1'), findsOneWidget);
  });

  testWidgets('usa el fondo de la app en el Scaffold', (tester) async {
    await pumpApp(tester, const Text('hola'));

    final context = tester.element(find.text('hola'));
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.background);
  });
}
