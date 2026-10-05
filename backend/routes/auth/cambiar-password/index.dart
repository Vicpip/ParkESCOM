import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /auth/cambiar-password`: pide la contraseña actual y la nueva.
///
/// Revoca todas las sesiones del usuario y responde con un par de tokens
/// nuevo para el dispositivo que hizo el cambio.
Future<Response> onRequest(RequestContext context) =>
    protegida(context, _manejar);

Future<Response> _manejar(RequestContext context) async {
  exigirMetodo(context, HttpMethod.post);
  final json = await leerJson(context);
  final sesion = await context.read<ServicioAuth>().cambiarPassword(
    id: context.read<UsuarioAutenticado>().id,
    actual: campoTexto(json, 'password_actual'),
    nueva: campoTexto(json, 'password_nueva'),
  );
  return Response.json(body: sesion.toJson());
}
