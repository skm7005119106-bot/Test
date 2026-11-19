import 'package:material_ui/material_ui.dart';

/// Kayra's neon-night palette, taken from the backdrop of her photos.
class KayraColors {
  static const bg = Color(0xFF0D0716);
  static const surface = Color(0xFF1A1026);
  static const surface2 = Color(0xFF2A1A3D);
  static const fg = Color(0xFFF6ECFF);
  static const muted = Color(0xFFA994C6);
  static const pink = Color(0xFFFF4FA3);
  static const violet = Color(0xFF8B5CFF);
  static const flame = Color(0xFFFFB347);
  static const line = Color(0xFF3A2752);
  static const online = Color(0xFF48E08A);
  static const danger = Color(0xFFFF6B81);

  static const glow = LinearGradient(
    colors: [pink, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

const displayFont = 'Sora';

TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color color = KayraColors.fg}) =>
    TextStyle(fontFamily: displayFont, fontSize: size, fontWeight: weight, color: color, height: 1.15);

ThemeData kayraTheme() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: KayraColors.line),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: KayraColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: KayraColors.pink, brightness: Brightness.dark).copyWith(
      primary: KayraColors.pink,
      onPrimary: Colors.white,
      secondary: KayraColors.violet,
      surface: KayraColors.surface,
      onSurface: KayraColors.fg,
      error: KayraColors.danger,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: KayraColors.fg, displayColor: KayraColors.fg),
    appBarTheme: AppBarTheme(
      backgroundColor: KayraColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: KayraColors.fg,
      titleTextStyle: display(20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KayraColors.surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: KayraColors.pink, width: 1.5)),
      labelStyle: const TextStyle(color: KayraColors.muted),
      hintStyle: const TextStyle(color: KayraColors.muted),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: KayraColors.surface2,
      contentTextStyle: TextStyle(color: KayraColors.fg, fontFamily: 'Inter'),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: KayraColors.surface),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: KayraColors.surface),
    dividerTheme: const DividerThemeData(color: KayraColors.line),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KayraColors.pink : null),
    ),
  );
}
