import 'package:flutter/material.dart';

import 'colores.dart';
import 'medidas.dart';

const _familia = 'Inter';

TextStyle _estilo(double tamano, FontWeight peso, double altoLinea) =>
    TextStyle(
      fontFamily: _familia,
      fontSize: tamano,
      fontWeight: peso,
      height: altoLinea / tamano,
      letterSpacing: 0,
    );

/// Escala tipográfica de DESIGN.md. El cuerpo (`bodyLarge` y `bodyMedium`)
/// nunca baja de 16 px.
final _textos = TextTheme(
  displayLarge: _estilo(40, FontWeight.w800, 48),
  displayMedium: _estilo(32, FontWeight.w700, 40),
  displaySmall: _estilo(26, FontWeight.w700, 34),
  headlineLarge: _estilo(32, FontWeight.w700, 40),
  headlineMedium: _estilo(26, FontWeight.w700, 34),
  headlineSmall: _estilo(24, FontWeight.w700, 32),
  titleLarge: _estilo(20, FontWeight.w600, 28),
  titleMedium: _estilo(18, FontWeight.w600, 26),
  titleSmall: _estilo(16, FontWeight.w600, 24),
  bodyLarge: _estilo(16, FontWeight.w400, 24),
  bodyMedium: _estilo(16, FontWeight.w400, 24),
  bodySmall: _estilo(14, FontWeight.w400, 20),
  labelLarge: _estilo(14, FontWeight.w600, 20),
  labelMedium: _estilo(12, FontWeight.w600, 16),
  labelSmall: _estilo(12, FontWeight.w600, 16),
).apply(bodyColor: ColoresApp.texto, displayColor: ColoresApp.texto);

final _forma = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(Medidas.radio),
);

const _tamanoBoton = Size(Medidas.altoBoton, Medidas.altoBoton);
const _paddingBoton = EdgeInsets.symmetric(horizontal: Medidas.paddingBoton);

OutlineInputBorder _bordeCampo(Color color, double grosor) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(Medidas.radio),
      borderSide: BorderSide(color: color, width: grosor),
    );

/// Tema único de la app (Android y web).
ThemeData construirTema() {
  // fromSeed altera el tono del primario: los valores exactos se fijan con
  // copyWith.
  final esquema = ColorScheme.fromSeed(seedColor: ColoresApp.primario).copyWith(
    primary: ColoresApp.primario,
    onPrimary: ColoresApp.sobreColor,
    primaryContainer: ColoresApp.contenedorPrimario,
    onPrimaryContainer: ColoresApp.primarioOscuro,
    secondary: ColoresApp.primarioOscuro,
    onSecondary: ColoresApp.sobreColor,
    secondaryContainer: ColoresApp.contenedorPrimario,
    onSecondaryContainer: ColoresApp.primarioOscuro,
    surface: ColoresApp.fondo,
    onSurface: ColoresApp.texto,
    onSurfaceVariant: ColoresApp.textoSecundario,
    surfaceContainerLowest: ColoresApp.fondo,
    surfaceContainerLow: ColoresApp.superficie,
    surfaceContainer: ColoresApp.superficie,
    surfaceContainerHigh: ColoresApp.superficie,
    surfaceContainerHighest: ColoresApp.superficie,
    surfaceTint: ColoresApp.fondo,
    outline: ColoresApp.borde,
    outlineVariant: ColoresApp.bordeSuave,
    error: ColoresApp.rechazo,
    onError: ColoresApp.sobreColor,
    errorContainer: ColoresApp.contenedorRechazo,
    onErrorContainer: ColoresApp.sobreContenedorRechazo,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: _familia,
    textTheme: _textos,
    scaffoldBackgroundColor: ColoresApp.fondo,
    extensions: const [ColoresEstado.base],
    appBarTheme: AppBarTheme(
      backgroundColor: ColoresApp.fondo,
      foregroundColor: ColoresApp.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: _textos.titleLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(_tamanoBoton),
        padding: const WidgetStatePropertyAll(_paddingBoton),
        shape: WidgetStatePropertyAll(_forma),
        textStyle: WidgetStatePropertyAll(_textos.labelLarge),
        foregroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.disabled)
              ? ColoresApp.textoSecundario
              : ColoresApp.sobreColor,
        ),
        backgroundColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) {
            return ColoresApp.bordeSuave;
          }
          if (estados.contains(WidgetState.pressed)) {
            return ColoresApp.primarioOscuro;
          }
          return ColoresApp.primario;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: _tamanoBoton,
        padding: _paddingBoton,
        shape: _forma,
        textStyle: _textos.labelLarge,
        foregroundColor: ColoresApp.primario,
        backgroundColor: ColoresApp.fondo,
        side: const BorderSide(
          color: ColoresApp.primario,
          width: Medidas.bordeFino,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: _tamanoBoton,
        shape: _forma,
        textStyle: _textos.labelLarge,
        foregroundColor: ColoresApp.primario,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresApp.fondo,
      constraints: const BoxConstraints(minHeight: Medidas.altoCampo),
      contentPadding: const EdgeInsets.all(Medidas.espacioMd),
      hintStyle: _textos.bodyLarge?.copyWith(color: ColoresApp.textoSecundario),
      helperStyle: _textos.bodySmall?.copyWith(
        color: ColoresApp.textoSecundario,
      ),
      helperMaxLines: 3,
      errorMaxLines: 3,
      prefixIconColor: ColoresApp.textoSecundario,
      suffixIconColor: ColoresApp.textoSecundario,
      border: _bordeCampo(ColoresApp.bordeSuave, Medidas.bordeFino),
      enabledBorder: _bordeCampo(ColoresApp.bordeSuave, Medidas.bordeFino),
      disabledBorder: _bordeCampo(ColoresApp.bordeSuave, Medidas.bordeFino),
      focusedBorder: _bordeCampo(ColoresApp.primario, Medidas.bordeFoco),
      errorBorder: _bordeCampo(ColoresApp.rechazo, Medidas.bordeFino),
      focusedErrorBorder: _bordeCampo(ColoresApp.rechazo, Medidas.bordeFoco),
    ),
    cardTheme: CardThemeData(
      color: ColoresApp.fondo,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Medidas.radio),
        side: const BorderSide(
          color: ColoresApp.bordeSuave,
          width: Medidas.bordeFino,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ColoresApp.fondo,
      shape: _forma,
      titleTextStyle: _textos.titleLarge,
      contentTextStyle: _textos.bodyLarge,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoresApp.fondo,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Medidas.radioGrande),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: Medidas.altoBarraNavegacion,
      backgroundColor: ColoresApp.fondo,
      indicatorColor: ColoresApp.contenedorPrimario,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected)
              ? ColoresApp.primario
              : ColoresApp.textoSecundario,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => _textos.labelMedium?.copyWith(
          color: estados.contains(WidgetState.selected)
              ? ColoresApp.primarioOscuro
              : ColoresApp.textoSecundario,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: ColoresApp.fondo,
      indicatorColor: ColoresApp.contenedorPrimario,
      selectedIconTheme: const IconThemeData(color: ColoresApp.primario),
      unselectedIconTheme: const IconThemeData(
        color: ColoresApp.textoSecundario,
      ),
      selectedLabelTextStyle: _textos.labelMedium?.copyWith(
        color: ColoresApp.primarioOscuro,
      ),
      unselectedLabelTextStyle: _textos.labelMedium?.copyWith(
        color: ColoresApp.textoSecundario,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Medidas.radioChico),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: ColoresApp.bordeSuave,
      thickness: Medidas.bordeFino,
      space: Medidas.bordeFino,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: _forma,
      contentTextStyle: _textos.bodyLarge?.copyWith(
        color: ColoresApp.sobreColor,
      ),
    ),
  );
}

/// Estilo del botón destructivo. Siempre va detrás de un diálogo de
/// confirmación.
ButtonStyle estiloBotonDestructivo() => const ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(ColoresApp.rechazo),
  foregroundColor: WidgetStatePropertyAll(ColoresApp.sobreColor),
);
