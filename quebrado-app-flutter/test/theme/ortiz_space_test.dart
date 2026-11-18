import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_theme.dart';

/// Radio uniforme de una forma `RoundedRectangleBorder`.
double radioDe(ShapeBorder? shape) {
  expect(shape, isA<RoundedRectangleBorder>());
  final radius = (shape! as RoundedRectangleBorder).borderRadius as BorderRadius;
  expect(radius.topLeft, radius.bottomRight, reason: 'el radio debe ser uniforme');
  return radius.topLeft.x;
}

void main() {
  group('OrtizSpace', () {
    test('sigue la escala 2 · 4 · 8 · 12 · 16 · 20 · 24 · 32', () {
      expect(OrtizSpace.xxs, 2);
      expect(OrtizSpace.xs, 4);
      expect(OrtizSpace.sm, 8);
      expect(OrtizSpace.md, 12);
      expect(OrtizSpace.lg, 16);
      expect(OrtizSpace.xl, 20);
      expect(OrtizSpace.xxl, 24);
      expect(OrtizSpace.xxxl, 32);
    });

    test('la lista de la escala contiene los mismos valores en orden creciente', () {
      expect(OrtizSpace.scale, [2, 4, 8, 12, 16, 20, 24, 32]);
    });
  });

  group('OrtizIconSize', () {
    test('sigue la escala 12 · 16 · 20 · 24 · 32 · 48 en orden creciente', () {
      expect(OrtizIconSize.scale, [12, 16, 20, 24, 32, 48]);
      expect(OrtizIconSize.md, 20);
    });
  });

  group('OrtizRadius', () {
    test('tiene los radios acordados por tipo de elemento', () {
      expect(OrtizRadius.chip, 8);
      expect(OrtizRadius.field, 12);
      expect(OrtizRadius.menu, 12);
      expect(OrtizRadius.block, 16);
      expect(OrtizRadius.dialog, 20);
      expect(OrtizRadius.sheet, 22);
      expect(OrtizRadius.pill, 999);
      expect(OrtizRadius.pillShape, isA<StadiumBorder>());
    });
  });

  group('OrtizTheme usa los radios de OrtizRadius', () {
    final theme = OrtizTheme.dark;

    test('chips y tooltips usan el radio de chip', () {
      expect(radioDe(theme.chipTheme.shape), OrtizRadius.chip);
      final tooltip = theme.tooltipTheme.decoration! as BoxDecoration;
      expect(tooltip.borderRadius, BorderRadius.circular(OrtizRadius.chip));
    });

    test('campos y snackbars usan el radio de campo', () {
      final border = theme.inputDecorationTheme.border! as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(OrtizRadius.field));
      expect(radioDe(theme.snackBarTheme.shape), OrtizRadius.field);
    });

    test('los menús emergentes usan el radio de menú', () {
      expect(radioDe(theme.popupMenuTheme.shape), OrtizRadius.menu);
    });

    test('las Card usan el radio de bloque', () {
      expect(radioDe(theme.cardTheme.shape), OrtizRadius.block);
    });

    test('los diálogos usan el radio de diálogo', () {
      expect(radioDe(theme.dialogTheme.shape), OrtizRadius.dialog);
    });

    test('las hojas inferiores redondean solo arriba con el radio de hoja', () {
      final shape = theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
      final radius = shape.borderRadius as BorderRadius;
      expect(radius.topLeft.x, OrtizRadius.sheet);
      expect(radius.topRight.x, OrtizRadius.sheet);
      expect(radius.bottomLeft, Radius.zero);
    });

    test('los botones y el FAB tienen forma de píldora', () {
      final shapes = <OutlinedBorder?>[
        theme.elevatedButtonTheme.style!.shape!.resolve({}),
        theme.filledButtonTheme.style!.shape!.resolve({}),
        theme.outlinedButtonTheme.style!.shape!.resolve({}),
        theme.textButtonTheme.style!.shape!.resolve({}),
      ];
      for (final s in shapes) {
        expect(s, OrtizRadius.pillShape);
      }
      expect(theme.floatingActionButtonTheme.shape, OrtizRadius.pillShape);
    });
  });
}
