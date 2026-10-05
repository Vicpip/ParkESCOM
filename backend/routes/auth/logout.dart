import 'dart:io';

import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /auth/logout`: revoca la sesión del refresh token recibido.
Future<Response> onRequest(RequestContext context) async {
  exigirMetodo(context, HttpMethod.post);
  final json = await leerJson(context);
  await context.read<ServicioAuth>().cerrarSesion(
    campoTexto(json, 'refresh_token'),
  );
  return Response(statusCode: HttpStatus.noContent);
}
