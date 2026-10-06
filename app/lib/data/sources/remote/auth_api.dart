import 'package:dio/dio.dart';

import '../../modelos/sesion.dart';
import '../../modelos/usuario.dart';
import 'llamada_api.dart';

/// Rutas `/auth` de la API.
class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  Future<SesionIniciada> registrar({
    required String nombre,
    required String correo,
    required String boletaOEmpleado,
    required String password,
  }) => llamarApi(() async {
    final respuesta = await _dio.post<dynamic>(
      '/auth/registro',
      data: {
        'nombre': nombre,
        'correo': correo,
        'boleta_o_empleado': boletaOEmpleado,
        'password': password,
      },
    );
    return SesionIniciada.deJson(cuerpoJson(respuesta));
  });

  Future<SesionIniciada> iniciarSesion({
    required String correo,
    required String password,
  }) => llamarApi(() async {
    final respuesta = await _dio.post<dynamic>(
      '/auth/login',
      data: {'correo': correo, 'password': password},
    );
    return SesionIniciada.deJson(cuerpoJson(respuesta));
  });

  /// Usuario de la sesión actual (`GET /auth/me`).
  Future<Usuario> yo() => llamarApi(() async {
    final respuesta = await _dio.get<dynamic>('/auth/me');
    return Usuario.deJson(
      cuerpoJson(respuesta)['usuario'] as Map<String, dynamic>,
    );
  });

  Future<void> cerrarSesion(String refreshToken) => llamarApi(() async {
    await _dio.post<dynamic>(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  });

  Future<void> olvidePassword(String correo) => llamarApi(() async {
    await _dio.post<dynamic>('/auth/olvide-password', data: {'correo': correo});
  });
}
