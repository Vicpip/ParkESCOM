import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /auth/refresh`: cambia el refresh token por un par nuevo (rotación).
Future<Response> onRequest(RequestContext context) async {
  exigirMetodo(context, HttpMethod.post);
  final json = await leerJson(context);
  final sesion = await context.read<ServicioAuth>().renovar(
    campoTexto(json, 'refresh_token'),
  );
  return Response.json(body: sesion.toJson());
}
