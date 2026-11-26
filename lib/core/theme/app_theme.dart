import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Identidad visual compartida: servicio público, señalización y legibilidad.
class AppTheme {
  static const Color primario = Color(0xFF174B78);
  static const Color azulOscuro = Color(0xFF102F4B);
  static const Color acento = Color(0xFFFFC247);
  static const Color fondo = Color(0xFFF3F6F8);
  static const Color tinta = Color(0xFF172B3B);
  static const Color textoSecundario = Color(0xFF516778);
  static const Color borde = Color(0xFFDCE5EB);
  static const Color superficieAzul = Color(0xFFE8F1F7);

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(
      seedColor: primario,
      brightness: Brightness.light,
      primary: primario,
      onPrimary: Colors.white,
      secondary: const Color(0xFF785600),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFE8A9),
      onSecondaryContainer: const Color(0xFF4A3400),
      surface: Colors.white,
      onSurface: tinta,
      error: const Color(0xFFB3261E),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: esquema);
    final texto = base.textTheme.apply(bodyColor: tinta, displayColor: tinta);
    final formaBoton = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final bordeCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: borde),
    );
    return base.copyWith(
      scaffoldBackgroundColor: fondo,
      textTheme: texto.copyWith(
        headlineMedium: texto.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.15),
        titleLarge: texto.titleLarge?.copyWith(
            fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: texto.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: texto.bodyMedium?.copyWith(height: 1.4),
        bodySmall: texto.bodySmall?.copyWith(color: textoSecundario, height: 1.4),
        labelLarge: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: azulOscuro,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borde),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: bordeCampo,
        enabledBorder: bordeCampo,
        focusedBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: primario, width: 2),
        ),
        errorBorder: bordeCampo.copyWith(
          borderSide: BorderSide(color: esquema.error),
        ),
        focusedErrorBorder: bordeCampo.copyWith(
          borderSide: BorderSide(color: esquema.error, width: 2),
        ),
        prefixIconColor: textoSecundario,
        labelStyle: const TextStyle(color: textoSecundario),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: formaBoton,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: formaBoton,
          side: const BorderSide(color: Color(0xFFAAC1D1)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: formaBoton,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: acento,
        foregroundColor: azulOscuro,
        elevation: 2,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      dividerTheme: const DividerThemeData(color: borde, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: azulOscuro,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
