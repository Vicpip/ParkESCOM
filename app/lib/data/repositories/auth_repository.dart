import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores/excepcion_api.dart';
import '../../core/red/cliente_api.dart';
import '../modelos/usuario.dart';
import '../sources/local/almacen_tokens.dart';
import '../sources/remote/auth_api.dart';

/// Sesión y cuenta: registro, inicio y cierre de sesión y recuperación de
/// contraseña. Todas las operaciones lanzan [ExcepcionApi] si fallan.
abstract interface class AuthRepository {
  /// Usuario de la sesión guardada en el dispositivo, o `null` si no hay
  /// sesión o ya no sirve. Lanza [ExcepcionApi] si no se pudo comprobar (por
  /// ejemplo, sin red); en ese caso la sesión se conserva.
  Future<Usuario?> restaurarSesion();

  /// Inicia sesión y guarda los tokens.
  Future<Usuario> iniciarSesion({
    required String correo,
    required String password,
  });

  /// Crea la cuenta (queda pendiente) y deja la sesión abierta.
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String boletaOEmpleado,
    required String password,
  });

  /// Cierra la sesión en la API y borra los tokens. Los tokens se borran
  /// aunque la API no responda.
  Future<void> cerrarSesion();

  /// Pide el correo con el enlace para restablecer la contraseña. La API
  /// responde igual exista o no la cuenta.
  Future<void> solicitarRecuperacion(String correo);
}

/// [AuthRepository] contra la API, con los tokens en el almacenamiento
/// seguro.
class AuthRepositoryApi implements AuthRepository {
  const AuthRepositoryApi(this._api, this._almacen);

  final AuthApi _api;
  final AlmacenTokens _almacen;

  @override
  Future<Usuario?> restaurarSesion() async {
    if (await _almacen.leer() == null) return null;
    try {
      return await _api.yo();
    } on ExcepcionApi catch (error) {
      // El interceptor ya intentó renovar: si aun así no hay sesión, se
      // descarta lo que quede guardado.
      if (!error.esDeSesion) rethrow;
      await _almacen.borrar();
      return null;
    }
  }

  @override
  Future<Usuario> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    final sesion = await _api.iniciarSesion(correo: correo, password: password);
    await _almacen.guardar(sesion.tokens);
    return sesion.usuario;
  }

  @override
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String boletaOEmpleado,
    required String password,
  }) async {
    final sesion = await _api.registrar(
      nombre: nombre,
      correo: correo,
      boletaOEmpleado: boletaOEmpleado,
      password: password,
    );
    await _almacen.guardar(sesion.tokens);
    return sesion.usuario;
  }

  @override
  Future<void> cerrarSesion() async {
    final tokens = await _almacen.leer();
    await _almacen.borrar();
    if (tokens == null) return;
    try {
      await _api.cerrarSesion(tokens.refresh);
    } on ExcepcionApi {
      // Sin red el refresh token queda vivo en la API hasta que venza, pero
      // el dispositivo ya no lo tiene.
    }
  }

  @override
  Future<void> solicitarRecuperacion(String correo) =>
      _api.olvidePassword(correo);
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryApi(
    AuthApi(ref.watch(clienteApiProvider)),
    ref.watch(almacenTokensProvider),
  ),
);
