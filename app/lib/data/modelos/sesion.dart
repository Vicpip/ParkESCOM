import 'usuario.dart';

/// Par de tokens de una sesión. Nunca se imprime ni se registra.
class Tokens {
  const Tokens({required this.acceso, required this.refresh});

  /// Lee `access_token` y `refresh_token` de una respuesta de `/auth`.
  factory Tokens.deJson(Map<String, dynamic> json) => Tokens(
    acceso: json['access_token'] as String,
    refresh: json['refresh_token'] as String,
  );

  /// JWT de acceso (15 min).
  final String acceso;

  /// Refresh token opaco; cada uso lo cambia por uno nuevo.
  final String refresh;

  @override
  String toString() => 'Tokens(***)';
}

/// Respuesta de registro, inicio de sesión y renovación.
class SesionIniciada {
  const SesionIniciada({required this.tokens, required this.usuario});

  factory SesionIniciada.deJson(Map<String, dynamic> json) => SesionIniciada(
    tokens: Tokens.deJson(json),
    usuario: Usuario.deJson(json['usuario'] as Map<String, dynamic>),
  );

  final Tokens tokens;
  final Usuario usuario;
}
