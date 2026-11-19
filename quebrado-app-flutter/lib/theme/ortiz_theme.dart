// `ThemeData` oscuro de la suite OrtizApp (spec 01, paso 3).
//
// Se construye solo con los tokens: colores de `OrtizPalette`/`OrtizTokens`,
// tipografía de `OrtizType`. Ningún color literal ni `ColorScheme.fromSeed`
// (cambiaría los valores de la paleta). `main.dart` solo usa
// `OrtizTheme.dark`.
import 'package:flutter/material.dart';

import 'ortiz_space.dart';
import 'ortiz_tokens.dart';
import 'ortiz_type.dart';

/// Tema de Material 3 de la suite. Solo oscuro por ahora (decisión C9).
/// Los radios salen de `OrtizRadius` (`ortiz_space.dart`).
abstract final class OrtizTheme {
  // Ancho del borde de un campo con foco.
  static const double _focusWidth = 2;

  // Opacidad del resaltado de texto seleccionado.
  static const double _selectionAlpha = 0.35;

  /// Tema oscuro. Se construye una sola vez: `MaterialApp` se reconstruye a
  /// menudo (escucha a `AppState`).
  static final ThemeData dark = _buildDark();

  /// `ColorScheme` oscuro tomado de los tokens.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: OrtizPalette.accent,
    onPrimary: OrtizPalette.onAccent,
    primaryContainer: OrtizPalette.surfaceHigh,
    onPrimaryContainer: OrtizPalette.accent,
    secondary: OrtizPalette.accent,
    onSecondary: OrtizPalette.onAccent,
    secondaryContainer: OrtizPalette.surfaceHigh,
    onSecondaryContainer: OrtizPalette.fg,
    tertiary: OrtizPalette.ok,
    onTertiary: OrtizPalette.onAccent,
    tertiaryContainer: OrtizPalette.surfaceHigh,
    onTertiaryContainer: OrtizPalette.ok,
    error: OrtizPalette.bad,
    onError: OrtizPalette.onAccent,
    errorContainer: OrtizPalette.surfaceHigh,
    onErrorContainer: OrtizPalette.bad,
    surface: OrtizPalette.surface,
    onSurface: OrtizPalette.fg,
    onSurfaceVariant: OrtizPalette.muted,
    surfaceDim: OrtizPalette.bg,
    surfaceBright: OrtizPalette.surfaceHigh,
    surfaceContainerLowest: OrtizPalette.bg,
    surfaceContainerLow: OrtizPalette.surface,
    surfaceContainer: OrtizPalette.surface,
    surfaceContainerHigh: OrtizPalette.surfaceHigh,
    surfaceContainerHighest: OrtizPalette.surfaceHigh,
    outline: OrtizPalette.line,
    outlineVariant: OrtizPalette.line,
    shadow: OrtizPalette.bg,
    scrim: OrtizPalette.bg,
    inverseSurface: OrtizPalette.fg,
    onInverseSurface: OrtizPalette.bg,
    inversePrimary: OrtizPalette.onAccent,
    surfaceTint: OrtizPalette.surface,
  );

  /// Escala de `OrtizType` con color: todo en `fg`, salvo `bodySmall`
  /// (texto secundario: ayudas, contadores, pies) en `muted`.
  static final TextTheme darkTextTheme = OrtizType.textTheme
      .apply(bodyColor: OrtizPalette.fg, displayColor: OrtizPalette.fg)
      .copyWith(
        bodySmall: OrtizType.textTheme.bodySmall!.copyWith(
          color: OrtizPalette.muted,
        ),
      );

  static ThemeData _buildDark() {
    const t = OrtizTokens.dark;
    final text = darkTextTheme;
    final label = text.labelLarge!;
    final fieldText = OrtizType.textTheme.bodyLarge!; // 16 px (evita zoom móvil)

    const pill = OrtizRadius.pillShape;
    RoundedRectangleBorder rounded(double r, {BorderSide side = BorderSide.none}) =>
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: side,
        );
    OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(OrtizRadius.field),
          borderSide: BorderSide(color: color, width: width),
        );
    WidgetStateProperty<Color> stateColor({
      required Color selected,
      required Color idle,
    }) => WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return t.faint;
      if (states.contains(WidgetState.selected)) return selected;
      return idle;
    });
    // Foco de teclado visible (web/escritorio): borde de 2 px en `fg`. Fuera
    // del foco, el borde propio del botón (`idle`) o ninguno.
    final focusRing = BorderSide(color: t.fg, width: _focusWidth);
    WidgetStateProperty<BorderSide?> focusSide([BorderSide? idle]) =>
        WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? focusRing : idle,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.surface,
      fontFamily: OrtizType.fontBody,
      textTheme: text,
      extensions: const <ThemeExtension<dynamic>>[OrtizTokens.dark],
      iconTheme: IconThemeData(color: t.fg),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.fg,
        ).copyWith(side: focusSide()),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: t.bg,
        foregroundColor: t.fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: t.fg),
        actionsIconTheme: IconThemeData(color: t.fg),
        titleTextStyle: OrtizType.title.copyWith(color: t.fg),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: rounded(OrtizRadius.block, side: BorderSide(color: t.line)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded(OrtizRadius.dialog),
        titleTextStyle: OrtizType.title.copyWith(color: t.fg),
        contentTextStyle: OrtizType.body.copyWith(color: t.fg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: t.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(OrtizRadius.sheet),
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: t.surface,
        hintStyle: fieldText.copyWith(color: t.muted),
        labelStyle: fieldText.copyWith(color: t.muted),
        floatingLabelStyle: fieldText.copyWith(color: t.accent),
        helperStyle: text.bodySmall,
        errorStyle: OrtizType.bodySm.copyWith(color: t.bad),
        prefixIconColor: t.muted,
        suffixIconColor: t.muted,
        border: fieldBorder(t.line),
        // Borde de campo en reposo: `faint` (≈ 2,9:1 sobre bg) para que se
        // vea el campo; `line` (≈ 1,4:1) no llegaba a 3:1 de no-texto.
        enabledBorder: fieldBorder(t.faint),
        disabledBorder: fieldBorder(t.line),
        focusedBorder: fieldBorder(t.accent, _focusWidth),
        errorBorder: fieldBorder(t.bad),
        focusedErrorBorder: fieldBorder(t.bad, _focusWidth),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.accent,
        selectionColor: t.accent.withValues(alpha: _selectionAlpha),
        selectionHandleColor: t.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.fg,
        contentTextStyle: OrtizType.body.copyWith(color: t.bg),
        actionTextColor: t.onAccent,
        closeIconColor: t.bg,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: rounded(OrtizRadius.field),
      ),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.surfaceHigh,
        disabledColor: t.surface,
        checkmarkColor: t.accent,
        deleteIconColor: t.muted,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge,
        // Seleccionado: borde `accent` para distinguirlo del chip en reposo.
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected) ? t.accent : t.line,
          ),
        ),
        shape: rounded(OrtizRadius.chip),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.muted,
        textColor: t.fg,
        selectedColor: t.accent,
        selectedTileColor: t.surfaceHigh,
        subtitleTextStyle: OrtizType.body.copyWith(color: t.muted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: stateColor(selected: t.onAccent, idle: t.muted),
        trackColor: stateColor(selected: t.accent, idle: t.surfaceHigh),
        trackOutlineColor: stateColor(selected: t.accent, idle: t.line),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: stateColor(selected: t.accent, idle: Colors.transparent),
        checkColor: WidgetStatePropertyAll(t.onAccent),
        side: BorderSide(color: t.muted),
      ),
      radioTheme: RadioThemeData(
        fillColor: stateColor(selected: t.accent, idle: t.muted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.surfaceHigh,
        circularTrackColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.surfaceHigh,
          disabledForegroundColor: t.faint,
          elevation: 0,
          textStyle: label,
          shape: pill,
        ).copyWith(side: focusSide()),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.surfaceHigh,
          disabledForegroundColor: t.faint,
          textStyle: label,
          shape: pill,
        ).copyWith(side: focusSide()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.fg,
          disabledForegroundColor: t.faint,
          textStyle: label,
          shape: pill,
        ).copyWith(side: focusSide(BorderSide(color: t.line))),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          disabledForegroundColor: t.faint,
          textStyle: label,
          shape: pill,
        ).copyWith(side: focusSide()),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: pill,
        extendedTextStyle: label,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.fg,
        unselectedLabelColor: t.muted,
        indicatorColor: t.accent,
        dividerColor: t.line,
        labelStyle: label,
        unselectedLabelStyle: label,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.bg,
        indicatorColor: t.surfaceHigh,
        selectedIconTheme: IconThemeData(color: t.accent),
        unselectedIconTheme: IconThemeData(color: t.muted),
        selectedLabelTextStyle: text.labelMedium!.copyWith(color: t.fg),
        unselectedLabelTextStyle: text.labelMedium!.copyWith(color: t.muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.surfaceHigh,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? t.accent : t.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected) ? t.fg : t.muted,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.surface,
        selectedItemColor: t.accent,
        unselectedItemColor: t.muted,
        elevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.surfaceHigh,
          borderRadius: BorderRadius.circular(OrtizRadius.chip),
          border: Border.all(color: t.line),
        ),
        textStyle: OrtizType.bodySm.copyWith(color: t.fg),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: OrtizType.body.copyWith(color: t.fg),
        shape: rounded(OrtizRadius.menu, side: BorderSide(color: t.line)),
      ),
      // Cupertino en todas las plataformas (docs/design-system.md).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
