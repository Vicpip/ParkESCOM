import 'package:dio/dio.dart';

import '../../data/modelos/sesion.dart';
import '../../data/sources/local/almacen_tokens.dart';

/// Rutas que no llevan token de acceso y cuyo 401 no dispara una renovación.
const _rutasSinToken = {
  '/auth/registro',
  '/auth/login',
  '/auth/refresh',
  '/auth/logout',
  '/auth/olvide-password',
  '/auth/restablecer',
};

const _marcaReintento = 'reintentada';

/// Pone el token de acceso en cada petición y, ante un 401, renueva la
/// sesión con el refresh token y repite la petición.
///
/// Aunque lleguen varios 401 a la vez se hace **una sola** renovación: el
/// refresh token es de un solo uso y una segunda renovación con el mismo
/// token cerraría la sesión. Si la API rechaza el refresh token, borra los
/// tokens y avisa con [alExpirar]. Una falla de red al renovar no cierra la
/// sesión.
///
/// No registra nada: ni cuerpos, ni cabeceras, ni tokens.
class InterceptorSesion extends Interceptor {
  InterceptorSesion({
    required this.almacen,
    required Dio dioSinSesion,
    required this.alExpirar,
  }) : _dio = dioSinSesion;

  final AlmacenTokens almacen;

  /// Cliente sin este interceptor: renueva y repite peticiones sin volver a
  /// entrar aquí.
  final Dio _dio;

  /// Se llama cuando la API rechaza el refresh token.
  final void Function() alExpirar;

  Future<Tokens?>? _renovacionEnCurso;

  static String _cabecera(Tokens tokens) => 'Bearer ${tokens.acceso}';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_rutasSinToken.contains(options.path)) {
      final tokens = await almacen.leer();
      if (tokens != null) {
        options.headers['Authorization'] = _cabecera(tokens);
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opciones = err.requestOptions;
    final renovable =
        err.response?.statusCode == 401 &&
        !_rutasSinToken.contains(opciones.path) &&
        opciones.extra[_marcaReintento] != true;
    if (!renovable) return handler.next(err);

    try {
      var tokens = await almacen.leer();
      // Si el token guardado ya es otro, una petición anterior renovó la
      // sesión mientras esta estaba en camino: basta con repetirla.
      if (tokens != null &&
          _cabecera(tokens) == opciones.headers['Authorization']) {
        tokens = await (_renovacionEnCurso ??= _renovar(
          tokens.refresh,
        ).whenComplete(() => _renovacionEnCurso = null));
      }
      if (tokens == null) return handler.next(err);

      opciones.headers['Authorization'] = _cabecera(tokens);
      opciones.extra[_marcaReintento] = true;
      final datos = opciones.data;
      // Un formulario multipart ya enviado no se puede volver a leer.
      if (datos is FormData) opciones.data = datos.clone();
      handler.resolve(await _dio.fetch<dynamic>(opciones));
    } on DioException catch (error) {
      handler.next(error);
    } on Object {
      // La renovación respondió algo ilegible: se entrega el 401 original.
      handler.next(err);
    }
  }

  /// Cambia el refresh token por un par nuevo. Devuelve `null` si la API lo
  /// rechazó (la sesión terminó) y relanza cualquier otra falla.
  Future<Tokens?> _renovar(String refreshToken) async {
    try {
      final respuesta = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final tokens = Tokens.deJson(respuesta.data as Map<String, dynamic>);
      await almacen.guardar(tokens);
      return tokens;
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      await almacen.borrar();
      alExpirar();
      return null;
    }
  }
}
