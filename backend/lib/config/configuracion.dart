import 'package:backend/config/entorno.dart';

/// Configuración de la API que no es la conexión a la base.
class Configuracion {
  /// Crea la configuración con valores explícitos (pruebas).
  ///
  /// Lanza [ErrorDeConfiguracion] si [jwtAccessSecret] es demasiado corto.
  Configuracion({
    required this.jwtAccessSecret,
    required this.origenWeb,
    required this.dominiosPermitidos,
    this.costoBcrypt = 12,
  }) {
    if (jwtAccessSecret.length < _longitudMinimaSecreto) {
      throw const ErrorDeConfiguracion(
        'JWT_ACCESS_SECRET debe tener al menos $_longitudMinimaSecreto '
        'caracteres aleatorios.',
      );
    }
  }

  /// Lee la configuración de las variables de entorno (o del `.env`).
  ///
  /// Lanza [ErrorDeConfiguracion] si falta alguna o no es válida.
  factory Configuracion.desdeEntorno() {
    final dominios = parsearDominios(exigirEntorno('ALLOWED_EMAIL_DOMAINS'));
    if (dominios.isEmpty) {
      throw const ErrorDeConfiguracion(
        'ALLOWED_EMAIL_DOMAINS no tiene ningún dominio. '
        'Ejemplo: ipn.mx,alumno.ipn.mx',
      );
    }
    return Configuracion(
      jwtAccessSecret: exigirEntorno('JWT_ACCESS_SECRET'),
      origenWeb: origenDe(exigirEntorno('APP_WEB_URL')),
      dominiosPermitidos: dominios,
    );
  }

  static const _longitudMinimaSecreto = 32;

  /// Secreto HS256 con el que se firman los JWT de acceso.
  final String jwtAccessSecret;

  /// Único origen al que CORS le permite llamar a la API (el panel web).
  final String origenWeb;

  /// Dominios de correo con los que se puede registrar una cuenta.
  final Set<String> dominiosPermitidos;

  /// Costo (log2 de rondas) de bcrypt para las contraseñas nuevas.
  final int costoBcrypt;
}

/// Convierte `ipn.mx, alumno.ipn.mx` en el conjunto de dominios en minúsculas.
Set<String> parsearDominios(String lista) => lista
    .split(',')
    .map((dominio) => dominio.trim().toLowerCase())
    .where((dominio) => dominio.isNotEmpty)
    .toSet();

/// Reduce una URL a su origen (`https://host[:puerto]`), que es lo que el
/// navegador manda en la cabecera `Origin`.
///
/// Lanza [ErrorDeConfiguracion] si [url] no es una URL http(s) absoluta.
String origenDe(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority || !uri.scheme.startsWith('http')) {
    throw const ErrorDeConfiguracion(
      'APP_WEB_URL debe ser una URL completa, por ejemplo '
      'https://parkescom.example.com',
    );
  }
  return uri.origin;
}
