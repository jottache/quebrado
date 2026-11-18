import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/widgets/suite_command_palette.dart';

import '../helpers/pump_app.dart';

void main() {
  late List<String> ran;
  late List<String> asked;

  List<PaletteEntry> entries() => [
        PaletteEntry(title: 'Ortiz', section: PaletteSection.apps, icon: Icons.face, onSelected: () => ran.add('ortiz')),
        PaletteEntry(title: 'Finanzas', section: PaletteSection.apps, icon: Icons.wallet, onSelected: () => ran.add('finanzas')),
        PaletteEntry(
          title: 'Registrar gasto',
          section: PaletteSection.actions,
          icon: Icons.arrow_downward,
          appLabel: 'Finanzas',
          keywords: 'pago compra egreso',
          onSelected: () => ran.add('gasto'),
        ),
        PaletteEntry(
          title: 'Marcar hábitos de hoy',
          section: PaletteSection.actions,
          icon: Icons.checklist,
          appLabel: 'Hábitos',
          onSelected: () => ran.add('habitos'),
        ),
        PaletteEntry(
          title: 'Nueva conversación',
          section: PaletteSection.ortiz,
          icon: Icons.add,
          onSelected: () => ran.add('nueva'),
        ),
      ];

  setUp(() {
    ran = [];
    asked = [];
  });

  test('filtra sin distinguir tildes ni mayúsculas, con palabras clave', () {
    expect(filterPaletteEntries(entries(), 'HABITOS').map((e) => e.title), ['Marcar hábitos de hoy']);
    expect(filterPaletteEntries(entries(), 'compra').map((e) => e.title), ['Registrar gasto']);
    expect(filterPaletteEntries(entries(), 'conversacion').map((e) => e.title), ['Nueva conversación']);
  });

  test('primero las que empiezan por la búsqueda, dentro de cada sección', () {
    // «finanzas» aparece en el título de la app y en la app de «Registrar gasto».
    expect(filterPaletteEntries(entries(), 'finanzas').map((e) => e.title), ['Finanzas', 'Registrar gasto']);
  });

  Future<void> open(WidgetTester tester, WindowClass window) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showSuiteCommandPalette(context, entries: entries(), onAskOrtiz: asked.add),
          child: const Text('abrir'),
        ),
      ),
      window: window,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  for (final window in [WindowClass.compact, WindowClass.expanded]) {
    group('en ${window.name}', () {
      testWidgets('muestra las secciones y el pie solo en escritorio', (tester) async {
        await open(tester, window);
        expect(find.text('APPS'), findsOneWidget);
        expect(find.text('ACCIONES RÁPIDAS'), findsOneWidget);
        expect(find.text('ORTIZ'), findsOneWidget);
        expect(find.text('Moverte'), window == WindowClass.expanded ? findsOneWidget : findsNothing);
      });

      testWidgets('«habitos» + Enter ejecuta «Marcar hábitos de hoy» tras cerrar', (tester) async {
        await open(tester, window);
        await tester.enterText(find.byType(TextField), 'habitos');
        await tester.pump();
        expect(find.text('APPS'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(ran, ['habitos']);
      });

      testWidgets('↓ + Enter ejecuta la segunda fila', (tester) async {
        await open(tester, window);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(ran, ['finanzas']);
      });

      testWidgets('↑ desde la primera fila da la vuelta a la última', (tester) async {
        await open(tester, window);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(ran, ['nueva']);
      });

      testWidgets('sin resultados ofrece preguntarle a Ortiz', (tester) async {
        await open(tester, window);
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pump();
        expect(find.text('Nada coincide con «zzz».'), findsOneWidget);
        await tester.tap(find.text('Pregúntale a Ortiz: «zzz»'));
        await tester.pumpAndSettle();
        expect(asked, ['zzz']);
        expect(ran, isEmpty);
      });

      testWidgets('Esc cierra sin ejecutar', (tester) async {
        await open(tester, window);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(ran, isEmpty);
      });

      testWidgets('Ctrl+K cierra la paleta abierta', (tester) async {
        await open(tester, window);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
      });
    });
  }
}
