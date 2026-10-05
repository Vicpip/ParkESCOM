import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /auth/login`: correo y contraseña a cambio de tokens.
Future<Response> onRequest(RequestContext context) async {
  exigirMetodo(context, HttpMethod.post);
  final json = await leerJson(context);
  final sesion = await context.read<ServicioAuth>().iniciarSesion(
    correo: campoTexto(json, 'correo'),
    password: campoTexto(json, 'password'),
  );
  return Response.json(body: sesion.toJson());
}
