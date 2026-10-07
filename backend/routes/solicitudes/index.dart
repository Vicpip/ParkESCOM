import 'dart:io';

import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:backend/solicitudes/servicio_solicitudes.dart';
import 'package:dart_frog/dart_frog.dart';

/// `GET /solicitudes`: las del usuario, de la más reciente a la más antigua;
/// `?estado=` deja solo las de ese estado.
///
/// `POST /solicitudes`: crea una solicitud de `alta`, `cambio` o `baja` y
/// responde 201 con ella.
Future<Response> onRequest(RequestContext context) =>
    protegida(context, _manejar);

Future<Response> _manejar(RequestContext context) async {
  final servicio = context.read<ServicioSolicitudes>();
  final usuarioId = context.read<UsuarioAutenticado>().id;
  switch (context.request.method) {
    case HttpMethod.get:
      final solicitudes = await servicio.listar(
        usuarioId,
        estado: context.request.uri.queryParameters['estado'],
      );
      return Response.json(
        body: {
          'solicitudes': [for (final s in solicitudes) s.toJson()],
        },
      );
    case HttpMethod.post:
      final solicitud = await servicio.crear(
        usuarioId,
        await leerJson(context),
      );
      return Response.json(
        statusCode: HttpStatus.created,
        body: {'solicitud': solicitud.toJson()},
      );
    case _:
      throw const ErrorApi(
        HttpStatus.methodNotAllowed,
        'METODO_NO_PERMITIDO',
        'Método no permitido.',
      );
  }
}
