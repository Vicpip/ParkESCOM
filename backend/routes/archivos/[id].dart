import 'dart:io';

import 'package:backend/archivos/servicio_archivos.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:dart_frog/dart_frog.dart';

/// `GET /archivos/{id}`: devuelve la foto si el usuario puede verla.
///
/// `nosniff` evita que el navegador interprete el contenido como otra cosa
/// que la imagen declarada, y `private` que un proxy compartido la guarde.
Future<Response> onRequest(RequestContext context, String id) => protegida(
  context,
  (context) async {
    exigirMetodo(context, HttpMethod.get);
    final archivo = await context.read<ServicioArchivos>().descargar(
      id: id,
      solicitante: context.read<UsuarioAutenticado>(),
    );
    return Response.bytes(
      body: archivo.bytes,
      headers: {
        HttpHeaders.contentTypeHeader: archivo.mime,
        HttpHeaders.cacheControlHeader: 'private, max-age=3600',
        'X-Content-Type-Options': 'nosniff',
      },
    );
  },
);
