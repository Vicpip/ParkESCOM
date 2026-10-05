import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// CORS: solo [origenPermitido] (el de `APP_WEB_URL`) puede llamar a la API
/// desde un navegador.
///
/// Las peticiones sin cabecera `Origin` (la app móvil, curl) pasan sin
/// cambios. A un origen distinto no se le agregan las cabeceras, así que el
/// navegador bloquea la respuesta, y su preflight se rechaza con 403.
Middleware cors(String origenPermitido) {
  final cabeceras = {
    HttpHeaders.accessControlAllowOriginHeader: origenPermitido,
    HttpHeaders.accessControlAllowMethodsHeader:
        'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    HttpHeaders.accessControlAllowHeadersHeader: 'Authorization, Content-Type',
    HttpHeaders.accessControlMaxAgeHeader: '600',
    HttpHeaders.varyHeader: 'Origin',
  };
  return (handler) => (context) async {
    final peticion = context.request;
    final permitido = peticion.headers['origin'] == origenPermitido;
    final esPreflight =
        peticion.method == HttpMethod.options &&
        peticion.headers.containsKey('access-control-request-method');
    if (esPreflight) {
      return permitido
          ? Response(statusCode: HttpStatus.noContent, headers: cabeceras)
          : Response(statusCode: HttpStatus.forbidden);
    }
    final respuesta = await handler(context);
    if (!permitido) return respuesta;
    return respuesta.copyWith(headers: {...respuesta.headers, ...cabeceras});
  };
}
