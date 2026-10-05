import 'dart:convert';
import 'dart:math';

import 'package:backend/auth/usuario.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Vigencia del JWT de acceso.
const vigenciaAcceso = Duration(minutes: 15);

/// Emite y verifica los JWT de acceso (HS256, claims `sub` y `rol`).
class ServicioTokens {
  /// Crea el servicio con el [secreto] de `JWT_ACCESS_SECRET`.
  ServicioTokens(String secreto) : _llave = SecretKey(secreto);

  final SecretKey _llave;

  /// Firma un token de acceso para el usuario, con la [vigencia] indicada.
  String emitirAcceso({
    required String usuarioId,
    required Rol rol,
    Duration vigencia = vigenciaAcceso,
  }) => JWT({'rol': rol.name}, subject: usuarioId).sign(
    _llave,
    expiresIn: vigencia,
  );

  /// Devuelve la identidad del [token], o `null` si la firma no coincide, ya
  /// venció, no es HS256 o le faltan los claims `sub` y `rol`.
  UsuarioAutenticado? verificarAcceso(String token) {
    final JWT jwt;
    try {
      jwt = JWT.verify(token, _llave);
    } on JWTException {
      return null;
    }
    final payload = jwt.payload;
    final id = jwt.subject;
    if (jwt.header?['alg'] != 'HS256' || id == null || payload is! Map) {
      return null;
    }
    // Sin `exp` el token no caducaría nunca: no lo emitió esta API.
    if (payload['exp'] is! num) return null;
    final rol = Rol.deNombre(payload['rol']);
    if (rol == null) return null;
    return UsuarioAutenticado(id: id, rol: rol);
  }
}

final _aleatorio = Random.secure();

/// Genera un refresh token opaco: 32 bytes aleatorios en base64url.
String generarRefreshToken() => base64Url
    .encode(List<int>.generate(32, (_) => _aleatorio.nextInt(256)))
    .replaceAll('=', '');

/// SHA-256 en hexadecimal del refresh token; es lo único que se guarda en
/// `sesiones`.
String hashRefreshToken(String token) =>
    sha256.convert(utf8.encode(token)).toString();
