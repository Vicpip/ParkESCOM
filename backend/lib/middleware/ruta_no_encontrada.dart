import 'dart:io';

import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';

/// Responde las rutas que no existen con el formato uniforme de error:
/// 404 `RUTA_NO_ENCONTRADA`.
///
/// Cuando ninguna ruta coincide, el `Router` de Dart Frog devuelve siempre el
/// mismo objeto centinela, [Router.routeNotFound] (un 404 de texto plano
/// "Route not found"). Este middleware lo reconoce por identidad y lo
/// sustituye; un 404 que una ruta responda a propósito (por ejemplo
/// `ARCHIVO_NO_ENCONTRADO`) es otro objeto y pasa intacto.
///
/// Va por dentro del middleware de CORS, que copia la respuesta y con eso
/// perdería la identidad del centinela.
Middleware rutaNoEncontrada() =>
    (handler) => (context) async {
      final respuesta = await handler(context);
      if (!identical(respuesta, Router.routeNotFound)) return respuesta;
      return const ErrorApi(
        HttpStatus.notFound,
        'RUTA_NO_ENCONTRADA',
        'La ruta solicitada no existe.',
      ).aRespuesta();
    };
