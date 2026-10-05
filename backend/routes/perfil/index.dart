import 'dart:io';

import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:backend/perfil/servicio_perfil.dart';
import 'package:dart_frog/dart_frog.dart';

/// `GET /perfil`: datos del usuario autenticado.
///
/// `PATCH /perfil`: cambia `nombre`, `foto_titular_id` o `foto_credencial_id`
/// (solo los campos presentes) y responde con el usuario actualizado.
Future<Response> onRequest(RequestContext context) =>
    protegida(context, _manejar);

Future<Response> _manejar(RequestContext context) async {
  final id = context.read<UsuarioAutenticado>().id;
  final usuario = switch (context.request.method) {
    HttpMethod.get => await context.read<ServicioAuth>().obtenerUsuario(id),
    HttpMethod.patch => await context.read<ServicioPerfil>().actualizar(
      id,
      await leerJson(context),
    ),
    _ => throw const ErrorApi(
      HttpStatus.methodNotAllowed,
      'METODO_NO_PERMITIDO',
      'Método no permitido.',
    ),
  };
  return Response.json(body: {'usuario': usuario.toJson()});
}
