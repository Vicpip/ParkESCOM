import 'package:flutter/material.dart';

/// Colores de `docs/design/00-sistema/DESIGN.md` y de `CLAUDE.md`. Solo en
/// `core/theme` se escribe un color a mano.
abstract final class ColoresApp {
  /// Azul ESCOM.
  static const primario = Color(0xFF006699);

  /// Encabezados y estados presionados.
  static const primarioOscuro = Color(0xFF004D73);

  /// Fondo de tarjetas destacadas y chips.
  static const contenedorPrimario = Color(0xFFE3F1F8);

  /// Fondo de las pantallas.
  static const fondo = Color(0xFFFFFFFF);

  /// Fondo de las secciones.
  static const superficie = Color(0xFFF5F7F9);

  /// Texto principal.
  static const texto = Color(0xFF1A1C1E);

  /// Texto secundario y etiquetas.
  static const textoSecundario = Color(0xFF5F6B73);

  /// Bordes con énfasis.
  static const borde = Color(0xFF707880);

  /// Bordes de 1 px de tarjetas y campos.
  static const bordeSuave = Color(0xFFDCE2E6);

  /// Texto sobre el primario y sobre los colores de estado.
  static const sobreColor = Color(0xFFFFFFFF);

  /// Éxito, aprobado, acceso permitido.
  static const exito = Color(0xFF1B873F);
  static const contenedorExito = Color(0xFFE8F5E9);
  static const sobreContenedorExito = Color(0xFF0F5124);

  /// Error, rechazado, acceso denegado.
  static const rechazo = Color(0xFFC62828);
  static const contenedorRechazo = Color(0xFFFFEBEE);
  static const sobreContenedorRechazo = Color(0xFF7F1313);

  /// Advertencia, pendiente.
  static const advertencia = Color(0xFFB26A00);
  static const contenedorAdvertencia = Color(0xFFFFF3E0);
  static const sobreContenedorAdvertencia = Color(0xFF6D3F00);

  /// Fondo de los estados neutros (por ejemplo "Revocada").
  static const contenedorNeutro = Color(0xFFE0E0E0);
}

/// Colores de estado que Material no trae: éxito y advertencia. Solo se usan
/// para estados y siempre acompañados de ícono y texto.
@immutable
class ColoresEstado extends ThemeExtension<ColoresEstado> {
  const ColoresEstado({
    required this.exito,
    required this.contenedorExito,
    required this.sobreContenedorExito,
    required this.advertencia,
    required this.contenedorAdvertencia,
    required this.sobreContenedorAdvertencia,
    required this.contenedorNeutro,
  });

  /// Valores del sistema de diseño.
  static const base = ColoresEstado(
    exito: ColoresApp.exito,
    contenedorExito: ColoresApp.contenedorExito,
    sobreContenedorExito: ColoresApp.sobreContenedorExito,
    advertencia: ColoresApp.advertencia,
    contenedorAdvertencia: ColoresApp.contenedorAdvertencia,
    sobreContenedorAdvertencia: ColoresApp.sobreContenedorAdvertencia,
    contenedorNeutro: ColoresApp.contenedorNeutro,
  );

  final Color exito;
  final Color contenedorExito;
  final Color sobreContenedorExito;
  final Color advertencia;
  final Color contenedorAdvertencia;
  final Color sobreContenedorAdvertencia;
  final Color contenedorNeutro;

  /// Colores de estado del tema activo.
  static ColoresEstado de(BuildContext context) =>
      Theme.of(context).extension<ColoresEstado>() ?? base;

  @override
  ColoresEstado copyWith({
    Color? exito,
    Color? contenedorExito,
    Color? sobreContenedorExito,
    Color? advertencia,
    Color? contenedorAdvertencia,
    Color? sobreContenedorAdvertencia,
    Color? contenedorNeutro,
  }) => ColoresEstado(
    exito: exito ?? this.exito,
    contenedorExito: contenedorExito ?? this.contenedorExito,
    sobreContenedorExito: sobreContenedorExito ?? this.sobreContenedorExito,
    advertencia: advertencia ?? this.advertencia,
    contenedorAdvertencia: contenedorAdvertencia ?? this.contenedorAdvertencia,
    sobreContenedorAdvertencia:
        sobreContenedorAdvertencia ?? this.sobreContenedorAdvertencia,
    contenedorNeutro: contenedorNeutro ?? this.contenedorNeutro,
  );

  @override
  ColoresEstado lerp(ColoresEstado? other, double t) {
    if (other == null) return this;
    Color mezclar(Color a, Color b) => Color.lerp(a, b, t)!;
    return ColoresEstado(
      exito: mezclar(exito, other.exito),
      contenedorExito: mezclar(contenedorExito, other.contenedorExito),
      sobreContenedorExito: mezclar(
        sobreContenedorExito,
        other.sobreContenedorExito,
      ),
      advertencia: mezclar(advertencia, other.advertencia),
      contenedorAdvertencia: mezclar(
        contenedorAdvertencia,
        other.contenedorAdvertencia,
      ),
      sobreContenedorAdvertencia: mezclar(
        sobreContenedorAdvertencia,
        other.sobreContenedorAdvertencia,
      ),
      contenedorNeutro: mezclar(contenedorNeutro, other.contenedorNeutro),
    );
  }
}
