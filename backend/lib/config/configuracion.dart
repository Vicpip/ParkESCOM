import 'package:backend/config/entorno.dart';

/// Dónde corre la API; sale de la variable `ENTORNO`.
enum Entorno {
  /// Equipo del desarrollador: sin SMTP, el enlace de recuperación de
  /// contraseña se imprime en consola.
  desarrollo,

  /// VPS: los correos siempre salen por SMTP y nunca se imprime un enlace ni
  /// un token.
  produccion;

  /// Lee `ENTORNO`. Si no está definida se asume [produccion], que es el
  /// valor seguro: un despliegue al que se le olvide la variable no imprime
  /// enlaces de recuperación en su bitácora.
  ///
  /// Lanza [ErrorDeConfiguracion] si el valor no es ninguno de los dos.
  static Entorno deNombre(String? nombre) {
    if (nombre == null) return produccion;
    for (final entorno in values) {
      if (entorno.name == nombre.trim().toLowerCase()) return entorno;
    }
    throw const ErrorDeConfiguracion(
      'ENTORNO debe ser "desarrollo" o "produccion".',
    );
  }
}

/// Carpeta de las fotos cuando `UPLOADS_DIR` no está definida.
const uploadsDirPorDefecto = './uploads';

/// Configuración de la API que no es la conexión a la base.
class Configuracion {
  /// Crea la configuración con valores explícitos (pruebas).
  ///
  /// Lanza [ErrorDeConfiguracion] si [jwtAccessSecret] es demasiado corto o
  /// [urlWeb] no es una URL http(s) absoluta.
  Configuracion({
    required this.jwtAccessSecret,
    required String urlWeb,
    required this.dominiosPermitidos,
    this.entorno = Entorno.produccion,
    this.uploadsDir = uploadsDirPorDefecto,
    this.costoBcrypt = 12,
  }) : origenWeb = origenDe(urlWeb),
       urlWeb = urlWeb.replaceFirst(RegExp(r'/+$'), '') {
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
      urlWeb: exigirEntorno('APP_WEB_URL'),
      dominiosPermitidos: dominios,
      entorno: Entorno.deNombre(leerEntorno('ENTORNO')),
      uploadsDir: leerEntorno('UPLOADS_DIR') ?? uploadsDirPorDefecto,
    );
  }

  static const _longitudMinimaSecreto = 32;

  /// Secreto HS256 con el que se firman los JWT de acceso.
  final String jwtAccessSecret;

  /// Único origen al que CORS le permite llamar a la API (el panel web).
  final String origenWeb;

  /// `APP_WEB_URL` sin diagonal final: base de los enlaces de los correos.
  final String urlWeb;

  /// Entorno en el que corre la API.
  final Entorno entorno;

  /// Carpeta donde se guardan las fotos subidas.
  final String uploadsDir;

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
