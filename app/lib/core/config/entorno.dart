/// Valores que se fijan al compilar con `--dart-define`.
abstract final class Entorno {
  /// URL base de la API (`--dart-define=API_BASE_URL=...`).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8090',
  );

  static const _dominios = String.fromEnvironment(
    'ALLOWED_EMAIL_DOMAINS',
    defaultValue: 'ipn.mx,alumno.ipn.mx',
  );

  /// Dominios de correo con los que la app valida en vivo el registro. Debe
  /// coincidir con `ALLOWED_EMAIL_DOMAINS` de la API, que es la que decide.
  static final List<String> dominiosPermitidos = _dominios
      .split(',')
      .map((dominio) => dominio.trim().toLowerCase())
      .where((dominio) => dominio.isNotEmpty)
      .toList(growable: false);
}
