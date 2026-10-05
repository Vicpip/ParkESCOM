import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /auth/olvide-password`: pide el correo con el enlace de recuperación.
///
/// Responde siempre lo mismo, exista o no la cuenta.
Future<Response> onRequest(RequestContext context) async {
  exigirMetodo(context, HttpMethod.post);
  final json = await leerJson(context);
  await context.read<ServicioAuth>().olvidePassword(campoTexto(json, 'correo'));
  return Response.json(
    body: {
      'mensaje':
          'Si el correo está registrado, te enviamos un enlace para '
          'restablecer tu contraseña.',
    },
  );
}
