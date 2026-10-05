import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /auth/restablecer`: cambia la contraseña con el token del enlace de
/// recuperación. No abre sesión: el usuario inicia sesión con la nueva.
Future<Response> onRequest(RequestContext context) async {
  exigirMetodo(context, HttpMethod.post);
  final json = await leerJson(context);
  await context.read<ServicioAuth>().restablecer(
    token: campoTexto(json, 'token'),
    nueva: campoTexto(json, 'password_nueva'),
  );
  return Response.json(
    body: {'mensaje': 'Tu contraseña se actualizó. Ya puedes iniciar sesión.'},
  );
}
