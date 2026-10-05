import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';

/// Exige un JWT de acceso válido en `Authorization: Bearer <token>`.
///
/// Si falta, no es válido o ya venció responde 401 `NO_AUTENTICADO`. Si es
/// válido, deja un [UsuarioAutenticado] en el contexto para la ruta
/// (`context.read<UsuarioAutenticado>()`).
///
/// El token no se consulta contra la base: una cuenta dada de baja conserva
/// el acceso hasta que su token vence (15 min como máximo).
Middleware autenticacion() =>
    (handler) => (context) {
      final cabecera = context.request.headers['authorization'] ?? '';
      final partes = cabecera.split(' ');
      if (partes.length != 2 || partes.first.toLowerCase() != 'bearer') {
        return const ErrorApi.noAutenticado().aRespuesta();
      }
      final usuario = context.read<ServicioTokens>().verificarAcceso(
        partes.last,
      );
      if (usuario == null) return const ErrorApi.noAutenticado().aRespuesta();
      return handler(context.provide<UsuarioAutenticado>(() => usuario));
    };

/// Deja pasar solo a los usuarios cuyo rol esté en [roles]; a los demás les
/// responde 403 `SIN_PERMISO`. Va siempre después de [autenticacion].
Middleware requerirRol(Set<Rol> roles) =>
    (handler) => (context) {
      final usuario = context.read<UsuarioAutenticado>();
      if (!roles.contains(usuario.rol)) {
        return const ErrorApi.sinPermiso().aRespuesta();
      }
      return handler(context);
    };

/// Atajo para una ruta que exige sesión y, si se indican, ciertos [roles]:
///
///     Future<Response> onRequest(RequestContext context) =>
///         protegida(context, _manejar, roles: {Rol.admin});
Future<Response> protegida(
  RequestContext context,
  Handler manejar, {
  Set<Rol>? roles,
}) async {
  var handler = manejar;
  if (roles != null) handler = handler.use(requerirRol(roles));
  return handler.use(autenticacion())(context);
}
