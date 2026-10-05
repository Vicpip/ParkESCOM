import 'dart:io';

import 'package:backend/config/entorno.dart';
import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

/// Convierte los errores en respuestas con el formato uniforme.
///
/// Un [ErrorApi] se responde con su propio código. Cualquier otra excepción
/// responde 500 `ERROR_INTERNO` y se anota en consola con [registrar]
/// (stderr por defecto).
///
/// La bitácora solo lleva método, ruta, tipo de excepción, SQLSTATE y la
/// traza: nunca el cuerpo, las cabeceras ni el mensaje de la excepción, que
/// podrían traer contraseñas o tokens.
Middleware errores({void Function(String linea)? registrar}) {
  final anotar = registrar ?? _aStderr;
  return (handler) => (context) async {
    try {
      return await handler(context);
    } on ErrorApi catch (error) {
      return error.aRespuesta();
    } on Object catch (error, traza) {
      final peticion = context.request;
      final detalle = switch (error) {
        // Mensajes propios, sin datos de la petición.
        ErrorDeConfiguracion(:final mensaje) => ': $mensaje',
        ServerException(:final code) => ' (SQLSTATE $code)',
        _ => '',
      };
      anotar(
        '[error] ${peticion.method.value} ${peticion.uri.path} → '
        '${error.runtimeType}$detalle\n$traza',
      );
      return const ErrorApi(
        HttpStatus.internalServerError,
        'ERROR_INTERNO',
        'Ocurrió un error inesperado. Intenta de nuevo más tarde.',
      ).aRespuesta();
    }
  };
}

void _aStderr(String linea) => stderr.writeln(linea);
