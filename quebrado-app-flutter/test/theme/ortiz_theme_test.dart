import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_theme.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

/// Contraste WCAG entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  final theme = OrtizTheme.dark;

  group('OrtizTheme.dark (CA-01)', () {
    test('es Material 3 y oscuro', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('el fondo del Scaffold es el token bg', () {
      expect(theme.scaffoldBackgroundColor, OrtizPalette.bg);
    });

    test('registra la extensión OrtizTokens con los tokens oscuros', () {
      expect(theme.extension<OrtizTokens>(), same(OrtizTokens.dark));
    });

    test('el ColorScheme sale de los tokens', () {
      final cs = theme.colorScheme;
      expect(cs.primary, OrtizPalette.accent);
      expect(cs.onPrimary, OrtizPalette.onAccent);
      expect(cs.surface, OrtizPalette.surface);
      expect(cs.onSurface, OrtizPalette.fg);
      expect(cs.onSurfaceVariant, OrtizPalette.muted);
      expect(cs.outline, OrtizPalette.line);
      expect(cs.outlineVariant, OrtizPalette.line);
      expect(cs.error, OrtizPalette.bad);
      expect(cs.surfaceContainerLowest, OrtizPalette.bg);
      expect(cs.surfaceContainerHighest, OrtizPalette.surfaceHigh);
    });

    test('bodyMedium usa Manrope en color fg y los títulos Bricolage', () {
      final body = theme.textTheme.bodyMedium!;
      expect(body.fontFamily, OrtizType.fontBody);
      expect(body.color, OrtizPalette.fg);
      expect(theme.textTheme.titleLarge!.fontFamily, OrtizType.fontDisplay);
      expect(theme.textTheme.bodySmall!.color, OrtizPalette.muted);
    });

    test('los campos escriben a 16 px y el foco es accent', () {
      final input = theme.inputDecorationTheme;
      expect(theme.textTheme.bodyLarge!.fontSize, 16);
      expect(input.hintStyle!.fontSize, 16);
      expect(input.labelStyle!.fontSize, 16);
      expect(input.fillColor, OrtizPalette.surface);
      expect(input.enabledBorder!.borderSide.color, OrtizPalette.faint);
      expect(input.focusedBorder!.borderSide.color, OrtizPalette.accent);
    });

    test('el borde del campo en reposo se ve sobre bg (≥ 2,9:1)', () {
      final borde = theme.inputDecorationTheme.enabledBorder!.borderSide.color;
      expect(contraste(borde, OrtizPalette.bg), greaterThanOrEqualTo(2.9));
    });

    test('el chip seleccionado lleva borde accent y el normal line', () {
      final side = theme.chipTheme.side;
      final seleccionado = WidgetStateProperty.resolveAs<BorderSide?>(
          side, {WidgetState.selected});
      final normal = WidgetStateProperty.resolveAs<BorderSide?>(side, {});
      expect(seleccionado!.color, OrtizPalette.accent);
      expect(normal!.color, OrtizPalette.line);
    });

    group('foco de teclado visible en los botones', () {
      final estilos = <String, ButtonStyle?>{
        'FilledButton': theme.filledButtonTheme.style,
        'ElevatedButton': theme.elevatedButtonTheme.style,
        'OutlinedButton': theme.outlinedButtonTheme.style,
        'TextButton': theme.textButtonTheme.style,
        'IconButton': theme.iconButtonTheme.style,
      };

      estilos.forEach((nombre, estilo) {
        test('$nombre con foco tiene borde de 2 px en fg', () {
          final side = estilo!.side!.resolve({WidgetState.focused});
          expect(side, isNotNull);
          expect(side!.color, OrtizPalette.fg);
          expect(side.width, 2);
        });
      });

      test('sin foco, solo OutlinedButton conserva su borde line', () {
        expect(theme.filledButtonTheme.style!.side!.resolve({}), isNull);
        expect(theme.elevatedButtonTheme.style!.side!.resolve({}), isNull);
        expect(theme.textButtonTheme.style!.side!.resolve({}), isNull);
        expect(theme.iconButtonTheme.style!.side!.resolve({}), isNull);
        expect(theme.outlinedButtonTheme.style!.side!.resolve({})!.color,
            OrtizPalette.line);
      });
    });

    test('las tarjetas no tienen elevación y van sobre surface', () {
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.color, OrtizPalette.surface);
    });

    test('AppBar, SnackBar y Divider toman los tokens', () {
      expect(theme.appBarTheme.backgroundColor, OrtizPalette.bg);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.appBarTheme.titleTextStyle!.fontFamily, OrtizType.fontDisplay);
      expect(theme.snackBarTheme.backgroundColor, OrtizPalette.fg);
      expect(theme.snackBarTheme.contentTextStyle!.color, OrtizPalette.bg);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.dividerTheme.color, OrtizPalette.line);
      expect(theme.dividerTheme.thickness, 1);
    });

    test('mantiene las transiciones Cupertino en todas las plataformas', () {
      final builders = theme.pageTransitionsTheme.builders;
      for (final p in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(builders[p], isA<CupertinoPageTransitionsBuilder>(), reason: '$p');
      }
    });
  });

  testWidgets('un MaterialApp con el tema expone los tokens oscuros', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: OrtizTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const TextField();
            },
          ),
        ),
      ),
    );

    // `OrtizTokens.of` cae a `dark` si falta la extensión: se comprueba
    // también que el tema la registra.
    expect(Theme.of(ctx).extension<OrtizTokens>(), same(OrtizTokens.dark));
    expect(OrtizTokens.of(ctx), OrtizTokens.dark);

    final scaffold = tester.widget<Material>(
      find.descendant(of: find.byType(Scaffold), matching: find.byType(Material)).first,
    );
    expect(scaffold.color, OrtizPalette.bg);

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.style.fontSize, 16);
    expect(editable.style.fontFamily, OrtizType.fontBody);
  });
}
